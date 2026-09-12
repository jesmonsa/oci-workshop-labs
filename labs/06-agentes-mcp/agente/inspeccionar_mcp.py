#!/usr/bin/env python3
"""
Inspector de servidores MCP: muestra exactamente qué herramientas expone un
servidor, sin necesidad de un cliente de IA.

    python inspeccionar_mcp.py -- sql -mcp
    python inspeccionar_mcp.py --detalle -- sql -mcp
    python inspeccionar_mcp.py --llamar list-connections -- sql -mcp
    python inspeccionar_mcp.py --json -- uvx oracle.oci-cloud-mcp-server@latest

Para qué sirve, y por qué es la primera herramienta del módulo:

Un servidor MCP es, en la práctica, **una lista de cosas que un agente va a poder
hacer contra un sistema tuyo**. Antes de conectarlo a nada conviene leer esa lista
completa, igual que se lee un conjunto de permisos antes de concederlo. Este script
la imprime, marca qué herramientas pueden escribir, y no necesita ningún modelo:
habla el protocolo directamente.

Sirve para cualquier servidor MCP que se comunique por entrada y salida estándar,
no solo los de Oracle.

Solo lee: hace `initialize` y `tools/list`. Únicamente ejecuta una herramienta si
se lo pides con --llamar, y avisa antes si esa herramienta parece de escritura.
"""

from __future__ import annotations

import argparse
import json
import queue
import shutil
import subprocess
import sys
import threading

VERSION_PROTOCOLO = "2025-06-18"

# Verbos que sugieren que una herramienta modifica algo. Es una heurística sobre
# el nombre y la descripción: sirve para ordenar la lectura, no para autorizar
# nada. La decisión de qué se permite es de una persona, no de esta lista.
VERBOS_ESCRITURA = (
    "create", "delete", "update", "insert", "drop", "alter", "write", "modify",
    "remove", "terminate", "start", "stop", "restart", "launch", "apply",
    "execute", "run", "exec", "put", "post", "set", "add", "attach", "detach",
    "crear", "borrar", "eliminar", "modificar", "ejecutar", "escribir",
)


class ClienteMCP:
    """Cliente mínimo de MCP sobre entrada y salida estándar (JSON-RPC 2.0)."""

    def __init__(self, comando: list[str], espera: float = 30.0):
        self.comando = comando
        self.espera = espera
        self.proceso: subprocess.Popen | None = None
        self._cola: queue.Queue = queue.Queue()
        self._errores: list[str] = []
        self._siguiente_id = 0

    def __enter__(self):
        try:
            self.proceso = subprocess.Popen(
                self.comando,
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, encoding="utf-8", errors="replace", bufsize=1,
            )
        except FileNotFoundError:
            raise SystemExit(f"No se encontró el ejecutable: {self.comando[0]}\n"
                             f"¿Está instalado y en el PATH?")
        threading.Thread(target=self._leer_salida, daemon=True).start()
        threading.Thread(target=self._leer_errores, daemon=True).start()
        return self

    def __exit__(self, *_):
        if self.proceso and self.proceso.poll() is None:
            self.proceso.terminate()
            try:
                self.proceso.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proceso.kill()

    def _leer_salida(self):
        for linea in self.proceso.stdout:
            linea = linea.strip()
            if not linea:
                continue
            # Algunos servidores imprimen un saludo antes de hablar el protocolo.
            # Se ignora todo lo que no sea JSON en vez de dar el diálogo por roto.
            try:
                self._cola.put(json.loads(linea))
            except json.JSONDecodeError:
                continue

    def _leer_errores(self):
        for linea in self.proceso.stderr:
            self._errores.append(linea.rstrip())

    def _enviar(self, mensaje: dict) -> None:
        self.proceso.stdin.write(json.dumps(mensaje) + "\n")
        self.proceso.stdin.flush()

    def _recibir(self, id_esperado: int) -> dict:
        """Espera la respuesta a un id concreto, descartando notificaciones."""
        restante = self.espera
        while restante > 0:
            try:
                mensaje = self._cola.get(timeout=1.0)
            except queue.Empty:
                restante -= 1.0
                if self.proceso.poll() is not None:
                    raise SystemExit(self._diagnostico())
                continue
            if mensaje.get("id") == id_esperado:
                return mensaje
        raise SystemExit(
            f"El servidor no respondió en {self.espera:.0f} s.\n{self._diagnostico()}")

    def _diagnostico(self) -> str:
        partes = []
        if self.proceso and self.proceso.poll() is not None:
            partes.append(f"El servidor terminó con código {self.proceso.returncode}.")
        if self._errores:
            partes.append("Últimas líneas de error del servidor:")
            partes.extend(f"  {l}" for l in self._errores[-12:])
        else:
            partes.append("El servidor no escribió nada en la salida de error.")
        return "\n".join(partes)

    def peticion(self, metodo: str, parametros: dict | None = None) -> dict:
        self._siguiente_id += 1
        id_actual = self._siguiente_id
        self._enviar({"jsonrpc": "2.0", "id": id_actual, "method": metodo,
                      "params": parametros or {}})
        respuesta = self._recibir(id_actual)
        if "error" in respuesta:
            err = respuesta["error"]
            raise SystemExit(f"El servidor devolvió un error en «{metodo}»: "
                             f"{err.get('message')} (código {err.get('code')})")
        return respuesta.get("result", {})

    def notificar(self, metodo: str) -> None:
        self._enviar({"jsonrpc": "2.0", "method": metodo})

    def iniciar(self) -> dict:
        resultado = self.peticion("initialize", {
            "protocolVersion": VERSION_PROTOCOLO,
            "capabilities": {},
            "clientInfo": {"name": "inspector-mcp", "version": "1.0"},
        })
        self.notificar("notifications/initialized")
        return resultado

    def herramientas(self) -> list[dict]:
        todas, cursor = [], None
        while True:
            params = {"cursor": cursor} if cursor else {}
            resultado = self.peticion("tools/list", params)
            todas.extend(resultado.get("tools", []))
            cursor = resultado.get("nextCursor")
            if not cursor:
                return todas


def parece_escritura(herramienta: dict) -> bool:
    anotaciones = herramienta.get("annotations") or {}
    # Si el servidor lo declara, se cree lo que declara antes que a la heurística.
    if "readOnlyHint" in anotaciones:
        return not anotaciones["readOnlyHint"]
    texto = f"{herramienta.get('name', '')} {herramienta.get('description', '')}".lower()
    return any(v in texto for v in VERBOS_ESCRITURA)


def imprimir_catalogo(info: dict, herramientas: list[dict], detalle: bool) -> int:
    servidor = info.get("serverInfo", {})
    print()
    print("=" * 72)
    print(f" {servidor.get('name', 'servidor desconocido')} "
          f"{servidor.get('version', '')}")
    print(f" protocolo: {info.get('protocolVersion', '?')}")
    print("=" * 72)
    print()

    if not herramientas:
        print("  El servidor no expone ninguna herramienta.")
        return 0

    escritura = 0
    for h in sorted(herramientas, key=lambda x: x.get("name", "")):
        marca = "ESCRIBE" if parece_escritura(h) else "lectura"
        escritura += 1 if marca == "ESCRIBE" else 0
        print(f"  [{marca}]  {h.get('name')}")
        descripcion = (h.get("description") or "").strip().splitlines()
        if descripcion:
            print(f"            {descripcion[0][:78]}")
        if detalle:
            propiedades = (h.get("inputSchema") or {}).get("properties") or {}
            requeridos = set((h.get("inputSchema") or {}).get("required") or [])
            for nombre, esquema in propiedades.items():
                obligatorio = "obligatorio" if nombre in requeridos else "opcional"
                print(f"              · {nombre} ({esquema.get('type', '?')}, {obligatorio})")
        print()

    print("-" * 72)
    print(f"  {len(herramientas)} herramienta(s): "
          f"{len(herramientas) - escritura} de lectura, {escritura} que pueden escribir.")
    print()
    print("  «ESCRIBE» es una señal para que alguien lo mire, no un veredicto: sale")
    print("  de lo que el servidor declara o, si no declara nada, del nombre y la")
    print("  descripción. Quién puede usar cada herramienta lo decide una persona.")
    print("-" * 72)
    return escritura


def main() -> int:
    p = argparse.ArgumentParser(
        description="Muestra qué herramientas expone un servidor MCP.",
        epilog="El comando del servidor va después de --, por ejemplo:  "
               "%(prog)s -- sql -mcp")
    p.add_argument("--detalle", action="store_true",
                   help="muestra también los parámetros de cada herramienta")
    p.add_argument("--json", action="store_true",
                   help="imprime el catálogo en JSON, para compararlo entre corridas")
    p.add_argument("--llamar", metavar="HERRAMIENTA",
                   help="ejecuta una herramienta después de listar (pide confirmación "
                        "si parece de escritura)")
    p.add_argument("--argumentos", metavar="JSON", default="{}",
                   help="argumentos de --llamar, en JSON")
    p.add_argument("--espera", type=float, default=30.0,
                   help="segundos de espera por respuesta (por defecto 30)")
    p.add_argument("comando", nargs=argparse.REMAINDER,
                   help="-- seguido del comando que arranca el servidor")
    args = p.parse_args()

    comando = [a for a in args.comando if a != "--"]
    if not comando:
        p.error("falta el comando del servidor. Ejemplo:  %(prog)s -- sql -mcp"
                .replace("%(prog)s", p.prog))

    if not shutil.which(comando[0]):
        print(f"Aviso: «{comando[0]}» no aparece en el PATH. Se intenta igual.\n",
              file=sys.stderr)

    with ClienteMCP(comando, espera=args.espera) as cliente:
        info = cliente.iniciar()
        herramientas = cliente.herramientas()

        if args.json:
            print(json.dumps({"servidor": info.get("serverInfo", {}),
                              "protocolo": info.get("protocolVersion"),
                              "herramientas": herramientas},
                             ensure_ascii=False, indent=2))
        else:
            imprimir_catalogo(info, herramientas, args.detalle)

        if args.llamar:
            elegida = next((h for h in herramientas if h.get("name") == args.llamar), None)
            if not elegida:
                print(f"\nLa herramienta «{args.llamar}» no está en el catálogo.")
                print("Y esa es justamente la idea: lo que no está declarado, no se ejecuta.")
                return 1
            if parece_escritura(elegida):
                print(f"\n«{args.llamar}» parece capaz de modificar algo.")
                if input("Escribir 'si' para ejecutarla igual: ").strip().lower() != "si":
                    print("Cancelado.")
                    return 0
            resultado = cliente.peticion("tools/call", {
                "name": args.llamar,
                "arguments": json.loads(args.argumentos),
            })
            print(f"\nResultado de «{args.llamar}»:")
            for bloque in resultado.get("content", []):
                if bloque.get("type") == "text":
                    print(bloque.get("text", "")[:4000])
                else:
                    print(f"  [contenido de tipo {bloque.get('type')}]")
            if resultado.get("isError"):
                print("\nEl servidor marcó la respuesta como error.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
