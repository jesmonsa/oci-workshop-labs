#!/usr/bin/env bash
# Descarga el wallet de la base y guarda la conexión que usará el servidor MCP.
#
#   ./10-preparar-conexion.sh [nombre-de-la-conexion]
#
# El servidor MCP de SQLcl no recibe credenciales: usa las conexiones que ya están
# guardadas en el equipo. Ese detalle es una decisión de diseño y conviene decirlo
# en la sesión: el agente no ve la contraseña, solo puede usar conexiones que una
# persona guardó antes.

set -uo pipefail

CONEXION="${1:-lab06}"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF="${AQUI}/../terraform/basedatos"
WALLET_DIR="${AQUI}/../wallet"

command -v oci >/dev/null || { echo "Falta OCI CLI."; exit 1; }
command -v sql >/dev/null || { echo "Falta SQLcl."; exit 1; }

ADB=$(cd "$TF" && terraform output -raw adb_ocid 2>/dev/null || echo "")
DBNAME=$(cd "$TF" && terraform output -raw db_name 2>/dev/null || echo "")
if [ -z "$ADB" ]; then
  echo "No encuentro el OCID de la base. ¿Se aplicó terraform/basedatos?"
  echo "Si la base se creó desde Resource Manager, pasar el OCID a mano:"
  echo "  ADB=<ocid> ./10-preparar-conexion.sh"
  [ -z "${ADB:-}" ] && [ -n "${ADB_OCID:-}" ] && ADB="$ADB_OCID"
  [ -z "$ADB" ] && exit 1
fi

echo "Base: ${DBNAME:-(nombre no disponible)}"
echo

# --- Contraseña del wallet ---------------------------------------------------
# El wallet se protege con su propia contraseña, distinta de la de ADMIN.
if [ -z "${WALLET_PASSWORD:-}" ]; then
  read -r -s -p "Contraseña para proteger el wallet (mínimo 8 caracteres): " WALLET_PASSWORD
  echo
fi
if [ "${#WALLET_PASSWORD}" -lt 8 ]; then
  echo "La contraseña del wallet debe tener al menos 8 caracteres."
  exit 1
fi

echo "Descargando el wallet..."
mkdir -p "$WALLET_DIR"
rm -f "${WALLET_DIR}/wallet.zip"
oci db autonomous-database generate-wallet \
  --autonomous-database-id "$ADB" \
  --password "$WALLET_PASSWORD" \
  --file "${WALLET_DIR}/wallet.zip" >/dev/null || {
    echo "No se pudo generar el wallet. ¿La base ya está disponible (estado AVAILABLE)?"
    exit 1
  }

if command -v unzip >/dev/null 2>&1; then
  unzip -o -q "${WALLET_DIR}/wallet.zip" -d "$WALLET_DIR"
else
  python -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
    "${WALLET_DIR}/wallet.zip" "$WALLET_DIR"
fi
echo "Wallet en: $WALLET_DIR"

SERVICIO="${DBNAME}_low"
echo
echo "Guardando la conexión «${CONEXION}» (servicio ${SERVICIO})..."
echo
echo "SQLcl va a pedir la contraseña de ADMIN. Se guarda cifrada en el almacén"
echo "de SQLcl para que el servidor MCP pueda usarla sin que nadie se la pase."
echo

# -savepwd guarda la credencial en el almacén de SQLcl. Sin esto, el servidor MCP
# no puede conectar: la conexión existiría pero pediría contraseña por teclado,
# y no hay nadie del otro lado para escribirla.
sql /nolog <<EOF
set cloudconfig ${WALLET_DIR}/wallet.zip
connect -save ${CONEXION} -savepwd ADMIN@${SERVICIO}
exit
EOF

echo
echo "Comprobando que la conexión guardada funciona..."
if sql -S "${CONEXION}" <<< "select 'conexion ok' as estado from dual;" 2>/dev/null | grep -q "conexion ok"; then
  echo "  Conexión «${CONEXION}» lista."
  echo
  echo "Siguiente:  ./20-cargar-esquema.sh ${CONEXION}"
else
  echo "  La conexión no respondió. Revisar la contraseña de ADMIN y el nombre del servicio."
  echo "  Servicios disponibles:  cd ../terraform/basedatos && terraform output servicios_de_conexion"
  exit 1
fi
