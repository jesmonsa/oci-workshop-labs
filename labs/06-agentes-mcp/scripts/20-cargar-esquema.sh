#!/usr/bin/env bash
# Carga el esquema de ejemplo en la base.
#
#   ./20-cargar-esquema.sh [nombre-de-la-conexion]
#
# El esquema imita un sistema heredado de pedidos, con cuatro problemas puestos a
# propósito. No se anuncian en la sesión: son lo que el agente tiene que encontrar.

set -uo pipefail

CONEXION="${1:-lab06}"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL="${AQUI}/../basedatos/esquema.sql"

command -v sql >/dev/null || { echo "Falta SQLcl."; exit 1; }
[ -f "$SQL" ] || { echo "No encuentro $SQL"; exit 1; }

echo "Cargando el esquema en «${CONEXION}»..."
echo "Tarda alrededor de un minuto: son unas 16 mil filas de detalle."
echo

sql -S "${CONEXION}" @"${SQL}"

echo
echo "Comprobación independiente del script de carga:"
sql -S "${CONEXION}" <<'EOF'
set feedback off
set pagesize 50
select table_name, num_rows from user_tables
 where table_name in ('CLI_MST','PRD_CAT','PED_HDR','PED_DET')
 order by table_name;
exit
EOF

echo
echo "Siguiente:  ./30-inspeccionar-mcp.sh"
