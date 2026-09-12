#!/usr/bin/env python3
"""
Comprueba que cada schema.yaml concuerde con el Terraform que acompaña.

    python scripts/verificar_esquemas.py

El formulario de Resource Manager y las variables de Terraform son dos archivos
distintos que nadie obliga a estar de acuerdo. Cuando se separan, el despliegue
en un clic falla en manos del cliente y no en las de uno:

  · una variable en el formulario que Terraform ya no declara -> «Value for
    undeclared variable», y el error aparece después de llenar el formulario;
  · una variable obligatoria de Terraform que el formulario no pide -> Resource
    Manager la deja vacía y el apply se cae por un valor que falta;
  · un tipo que no coincide -> el más caro, porque el formulario se llena sin
    quejarse y el error solo sale al aplicar.

Esta comprobación existe porque el tercer caso ya ocurrió: `waf_capacidades` pasó
de lista a mapa en Terraform y el formulario publicado se quedó pidiendo una
lista, con una segunda variable que ya no existía.

Devuelve 0 si todo concuerda. Cualquier otra cosa es un despliegue roto.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Falta PyYAML:  pip install pyyaml")

AQUI = Path(__file__).resolve().parent.parent

# Tipos de Terraform que un formulario puede representar, y con qué.
# Lo que no está aquí no se puede pedir por formulario: se deja fuera y se usa
# el valor por defecto del módulo.
# Los tipos `oci:...` son selectores que el formulario resuelve contra el tenancy
# (una lista de shapes, de compartimentos, de dominios de disponibilidad). Todos
# entregan una cadena a Terraform, así que valen donde vale `string`.
EQUIVALENCIAS = {
    "string": {"string", "enum", "password", "text", "file"},
    "number": {"number", "integer"},
    "bool": {"boolean"},
    "list(string)": {"array"},
}
NO_REPRESENTABLES = ("map(", "object(", "set(", "tuple(")


def variables_de_terraform(carpeta: Path) -> dict[str, dict]:
    """Nombre -> {tipo, obligatoria} leyendo los .tf de la carpeta."""
    fuente = "\n".join(f.read_text(encoding="utf-8")
                       for f in sorted(carpeta.glob("*.tf")))
    encontradas: dict[str, dict] = {}
    for m in re.finditer(r'variable\s+"([^"]+)"\s*\{', fuente):
        nombre = m.group(1)
        # El cuerpo va desde la llave de apertura hasta su cierre, contando llaves.
        i, nivel = m.end() - 1, 0
        while i < len(fuente):
            if fuente[i] == "{":
                nivel += 1
            elif fuente[i] == "}":
                nivel -= 1
                if nivel == 0:
                    break
            i += 1
        cuerpo = fuente[m.end():i]
        tipo = re.search(r"^\s*type\s*=\s*(.+?)$", cuerpo, re.M)
        encontradas[nombre] = {
            "tipo": (tipo.group(1).strip() if tipo else "string"),
            "obligatoria": not re.search(r"^\s*default\s*=", cuerpo, re.M),
        }
    return encontradas


def compatible(tipo_tf: str, tipo_form: str) -> bool:
    if tipo_form.startswith("oci:"):
        return tipo_tf == "string"
    return tipo_form in EQUIVALENCIAS.get(tipo_tf, set())


def revisar(carpeta: Path) -> list[str]:
    esquema_ruta = carpeta / "schema.yaml"
    if not esquema_ruta.exists():
        return [f"{carpeta.name}: sin schema.yaml"]

    esquema = yaml.safe_load(esquema_ruta.read_text(encoding="utf-8")) or {}
    del_form: dict = esquema.get("variables") or {}
    del_tf = variables_de_terraform(carpeta)
    fallos = []

    # Resource Manager siempre inyecta estas; Terraform puede no declararlas.
    INYECTADAS = {"tenancy_ocid", "region", "compartment_ocid", "current_user_ocid"}

    for nombre, definicion in del_form.items():
        if nombre in INYECTADAS:
            continue
        if nombre not in del_tf:
            fallos.append(f"  el formulario pide '{nombre}', que Terraform ya no declara")
            continue
        tipo_form = str((definicion or {}).get("type", "string")).lower()
        tipo_tf = del_tf[nombre]["tipo"]
        if tipo_tf.startswith(NO_REPRESENTABLES):
            fallos.append(f"  '{nombre}' es {tipo_tf} en Terraform: un formulario no puede "
                          f"representarlo. Sacarlo del formulario y usar el valor por defecto")
        elif not compatible(tipo_tf, tipo_form):
            fallos.append(f"  '{nombre}': Terraform lo declara {tipo_tf} y el formulario "
                          f"lo pide como {tipo_form}")

    for nombre, definicion in del_tf.items():
        if definicion["obligatoria"] and nombre not in del_form and nombre not in INYECTADAS:
            fallos.append(f"  '{nombre}' es obligatoria en Terraform y el formulario no la pide")

    grupos = esquema.get("variableGroups") or []
    agrupadas = {v for g in grupos for v in (g.get("variables") or [])}
    for nombre in del_form:
        if nombre not in agrupadas:
            fallos.append(f"  '{nombre}' está definida pero no aparece en ningún grupo: "
                          f"el formulario no la muestra")
    for nombre in agrupadas:
        if nombre not in del_form:
            fallos.append(f"  un grupo menciona '{nombre}', que no está definida")

    return [f"{carpeta.relative_to(AQUI)}:"] + fallos if fallos else []


def main() -> int:
    carpetas = sorted(p.parent for p in AQUI.rglob("schema.yaml"))
    if not carpetas:
        print("No encontré ningún schema.yaml.")
        return 2

    problemas = []
    for carpeta in carpetas:
        fallos = revisar(carpeta)
        if fallos:
            problemas.extend(fallos)
        else:
            print(f"  ok   {carpeta.relative_to(AQUI)}")

    if problemas:
        print()
        for linea in problemas:
            print(linea)
        print(f"\n{len([p for p in problemas if p.startswith('  ')])} discrepancia(s). "
              f"El despliegue en un clic fallaría.")
        return 1

    print(f"\n{len(carpetas)} formulario(s) concuerdan con su Terraform.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
