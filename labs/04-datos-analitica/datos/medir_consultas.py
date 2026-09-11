#!/usr/bin/env python3
"""
Ejecuta las consultas de consultas.sql, las cronometra y arma resultados.json.

    python medir_consultas.py --usuario admin --password '...' --puerto 3306

Se conecta a localhost porque la base no tiene endpoint público: se llega por el
reenvío de puerto del bastión (ver manual, paso 3). Esa es también la razón por la
que este script no lleva credenciales dentro.

Qué mide: la misma consulta SQL, sin cambiar una letra, en el motor transaccional
y —si existe el clúster— en el acelerador analítico. Ese es el argumento: no hay
que reescribir la aplicación para tener analítica rápida.

Si el acelerador no está, lo dice y sigue. Nunca inventa el segundo número.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import statistics
import sys
import time
from pathlib import Path

AQUI = Path(__file__).parent

# Consultas que alimentan el tablero (el resto se cronometra pero no se dibuja).
PARA_TABLERO = {
    "volumen_diario", "tasa_rechazo_diaria", "motivos_rechazo",
    "clientes_en_riesgo", "atascados", "percentiles_por_canal",
}


def leer_consultas(ruta: Path) -> list[dict]:
    """Parte consultas.sql en bloques por las marcas @consulta."""
    texto = ruta.read_text(encoding="utf-8")
    bloques = []
    for trozo in re.split(r"^-- @consulta:", texto, flags=re.M)[1:]:
        lineas = trozo.splitlines()
        meta = {"nombre": lineas[0].strip(), "titulo": "", "decision": "", "peso": "media"}
        sql = []
        for linea in lineas[1:]:
            if m := re.match(r"-- @(\w+):\s*(.*)", linea.strip()):
                clave, valor = m.group(1), m.group(2)
                if clave in meta or clave in ("parametro_cliente",):
                    meta[clave] = valor
                continue
            if linea.strip().startswith("--") and not sql:
                continue
            sql.append(linea)
        consulta = "\n".join(sql).strip()
        consulta = consulta.split(";")[0].strip()
        if consulta:
            meta["sql"] = consulta
            bloques.append(meta)
    return bloques


def cronometrar(cursor, sql: str, repeticiones: int) -> tuple[float, list]:
    tiempos, filas = [], []
    for i in range(repeticiones):
        inicio = time.perf_counter()
        cursor.execute(sql)
        filas = cursor.fetchall()
        tiempos.append(time.perf_counter() - inicio)
    return statistics.median(tiempos), filas


def normalizar(filas: list, columnas: list[str]) -> list[dict]:
    salida = []
    for f in filas:
        fila = {}
        for col, valor in zip(columnas, f):
            if isinstance(valor, (dt.date, dt.datetime)):
                valor = valor.isoformat()[:10] if isinstance(valor, dt.date) else valor.isoformat()
            elif hasattr(valor, "quantize"):          # Decimal
                valor = float(valor)
            fila[col] = valor
        salida.append(fila)
    return salida


def main() -> int:
    p = argparse.ArgumentParser(description="Mide las consultas y arma resultados.json")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--puerto", type=int, default=3306)
    p.add_argument("--usuario", required=True)
    p.add_argument("--password", required=True)
    p.add_argument("--base", default="operacion")
    p.add_argument("--repeticiones", type=int, default=3,
                   help="se reporta la mediana; 3 basta para una demo")
    p.add_argument("--acelerador", choices=["auto", "si", "no"], default="auto")
    p.add_argument("--salida", default="resultados.json")
    args = p.parse_args()

    try:
        import mysql.connector
    except ImportError:
        print("Falta el conector: pip install -r requirements.txt", file=sys.stderr)
        return 1

    try:
        cnx = mysql.connector.connect(host=args.host, port=args.puerto, user=args.usuario,
                                      password=args.password, database=args.base)
    except Exception as err:
        print(f"No se pudo conectar: {err}\n"
              f"¿Está abierta la sesión de reenvío de puerto del bastión? "
              f"(manual, paso 3)", file=sys.stderr)
        return 2

    cur = cnx.cursor()
    cur.execute("SELECT COUNT(*) FROM documentos")
    filas_totales = cur.fetchone()[0]
    print(f"Conectado. {filas_totales:,} documentos en la tabla.\n")

    # ¿Hay acelerador? Se comprueba de verdad, no se asume.
    hay_acelerador = False
    if args.acelerador != "no":
        try:
            cur.execute("SET SESSION use_secondary_engine = FORCED")
            cur.execute("SELECT COUNT(*) FROM documentos")
            cur.fetchall()
            hay_acelerador = True
            print("Acelerador analítico: disponible y con la tabla cargada.\n")
        except Exception as err:
            print(f"Acelerador analítico: no disponible ({str(err)[:90]}).")
            print("Se miden solo los tiempos del motor transaccional.\n")
        finally:
            cur.execute("SET SESSION use_secondary_engine = OFF")

    datos = {"generado": dt.datetime.now().isoformat(timespec="minutes"),
             "fuente": f"MySQL{' HeatWave' if hay_acelerador else ''} — {args.base}",
             "filas_totales": filas_totales, "tiempos": []}

    for bloque in leer_consultas(AQUI / "consultas.sql"):
        nombre = bloque["nombre"]
        print(f"  {nombre:<24}", end="", flush=True)

        cur.execute("SET SESSION use_secondary_engine = OFF")
        try:
            t_innodb, filas = cronometrar(cur, bloque["sql"], args.repeticiones)
            columnas = [d[0] for d in cur.description]
        except Exception as err:
            print(f"ERROR: {str(err)[:70]}")
            continue

        t_acelerador = None
        if hay_acelerador:
            try:
                cur.execute("SET SESSION use_secondary_engine = FORCED")
                t_acelerador, _ = cronometrar(cur, bloque["sql"], args.repeticiones)
            except Exception:
                t_acelerador = None      # esta consulta no se pudo delegar
            finally:
                cur.execute("SET SESSION use_secondary_engine = OFF")

        comparacion = (f" -> {t_acelerador:6.2f}s  ({t_innodb/t_acelerador:.1f}x)"
                       if t_acelerador else "  (sin acelerador)")
        print(f"{t_innodb:7.2f}s{comparacion}")

        datos["tiempos"].append({
            "consulta": nombre, "titulo": bloque["titulo"], "peso": bloque["peso"],
            "innodb_s": round(t_innodb, 3),
            "acelerador_s": round(t_acelerador, 3) if t_acelerador else None,
            "filas": len(filas),
        })
        if nombre in PARA_TABLERO:
            datos[nombre] = normalizar(filas, columnas)

    cur.close()
    cnx.close()

    # KPIs derivados de las consultas ya ejecutadas: no se vuelve a consultar la base.
    vol = datos.get("volumen_diario", [])
    motivos = datos.get("motivos_rechazo", [])
    perc = datos.get("percentiles_por_canal", [])
    total_30d = sum(f["emitidos"] for f in vol) or 1
    datos["kpis"] = {
        "documentos_30d": total_30d,
        "tasa_rechazo_30d": round(100 * sum(f["rechazados"] for f in motivos) / total_30d, 2),
        "p95_peor_canal": perc[0]["p95_min"] if perc else 0,
        "canal_peor_p95": perc[0]["canal"] if perc else "—",
        "detenidos": sum(f["detenidos"] for f in datos.get("atascados", [])),
    }

    Path(args.salida).write_text(json.dumps(datos, ensure_ascii=False, indent=1),
                                 encoding="utf-8")
    print(f"\nResultados en {args.salida}")
    print(f"Siguiente: python tablero.py --entrada {args.salida} --salida tablero.html")
    if not hay_acelerador:
        print("\nNota: sin acelerador, el tablero lo dirá explícitamente y no mostrará "
              "ninguna comparación. Es lo correcto: no se presentan cifras que no se midieron.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
