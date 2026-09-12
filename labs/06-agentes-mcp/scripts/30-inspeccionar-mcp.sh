#!/usr/bin/env bash
# Muestra qué expone el servidor MCP de SQLcl, y cómo cambia según el nivel de
# restricción.
#
#   ./30-inspeccionar-mcp.sh
#
# Es la demostración central del módulo: el catálogo de herramientas es la lista
# de lo que un agente va a poder hacer. Se lee entera antes de conectar nada.
#
# El servidor arranca en nivel 4 —el más cerrado— salvo que se le indique otro
# con -R. Ese comportamiento por defecto es la decisión de diseño que vale la pena
# señalar: lo cerrado es lo normal, y abrir es una acción deliberada.

set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSPECTOR="${AQUI}/../agente/inspeccionar_mcp.py"
SALIDA="${AQUI}/../evidencias"
PY=$(command -v python3 || command -v python)

command -v sql >/dev/null || { echo "Falta SQLcl."; exit 1; }
[ -n "$PY" ] || { echo "Falta Python."; exit 1; }
mkdir -p "$SALIDA"

RUTA_SQL=$(command -v sql)

echo "======================================================================"
echo " Catálogo del servidor MCP de SQLcl — nivel por defecto (4)"
echo "======================================================================"
"$PY" "$INSPECTOR" --detalle -- "$RUTA_SQL" -mcp | tee "${SALIDA}/catalogo-nivel-4.txt"

echo
echo "======================================================================"
echo " El mismo servidor en nivel 1 — mucho más permisivo"
echo "======================================================================"
echo
echo "Nivel 1 solo bloquea los comandos del sistema operativo. Todo lo demás,"
echo "incluidos guardar archivos y ejecutar scripts, queda disponible."
echo
"$PY" "$INSPECTOR" -- "$RUTA_SQL" -R 1 -mcp | tee "${SALIDA}/catalogo-nivel-1.txt"

echo
echo "======================================================================"
echo " Lo que hay que mirar"
echo "======================================================================"
cat <<'TEXTO'

  El catálogo de herramientas es casi el mismo en los dos niveles. Y ahí está
  justamente el punto que vale la pena entender:

  El nivel de restricción NO cambia cuántas herramientas hay. Cambia lo que
  `run-sqlcl` acepta ejecutar por dentro. Una sola herramienta llamada
  «ejecuta comandos de SQLcl» puede ser inofensiva o puede escribir archivos y
  llamar al sistema operativo, según un parámetro de arranque que no se ve en
  el catálogo.

  De ahí salen las dos preguntas del módulo:

    1. ¿Con qué nivel arranca el servidor que se conectó, y quién lo decidió?
    2. ¿Con qué usuario de base de datos conecta? Porque el nivel de restricción
       limita a SQLcl, no a la base: si la conexión guardada es ADMIN, el agente
       tiene los permisos de ADMIN.

  La segunda es la más importante y la que casi nadie hace.

TEXTO

echo "Catálogos guardados en evidencias/ para compararlos entre corridas:"
echo "  diff ${SALIDA}/catalogo-nivel-4.txt ${SALIDA}/catalogo-nivel-1.txt"
