#!/usr/bin/env bash
# Abre un túnel a la base de datos a través del bastión.
#
#   ./10-tunel-mysql.sh [ttl-segundos]
#
# La base no tiene endpoint público (control D-01 del módulo 2). Este script crea
# una sesión de reenvío de puerto y deja 127.0.0.1:3306 apuntando a ella, para que
# mysqlsh, medir_consultas.py y cualquier cliente se conecten a localhost.
#
# en la preparación se ejecuta antes del bloque, no durante: crear la sesión toma 1-2 min.

set -uo pipefail

TTL="${1:-10800}"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF="${AQUI}/../terraform/heatwave"
LLAVE_PUB="${SSH_PUB:-$HOME/.ssh/id_rsa.pub}"
LLAVE_PRIV="${LLAVE_PUB%.pub}"
PUERTO_LOCAL="${PUERTO_LOCAL:-3306}"

BASTION=$(cd "$TF" && terraform output -raw bastion_id)
IP_MYSQL=$(cd "$TF" && terraform output -raw mysql_ip_privada)

echo "Tu IP pública ahora: $(curl -s --max-time 5 ifconfig.me || echo '?')"
echo "Debe estar en ips_admin_cidr del bastión, o la sesión se crea pero no conecta."
echo

echo "Creando sesión de reenvío de puerto hacia ${IP_MYSQL}:3306 (TTL ${TTL}s)..."
SESION=$(oci bastion session create-port-forwarding \
  --bastion-id "$BASTION" \
  --target-private-ip "$IP_MYSQL" \
  --target-port 3306 \
  --ssh-public-key-file "$LLAVE_PUB" \
  --session-ttl "$TTL" \
  --display-name "lab04-mysql-$(date +%H%M)" \
  --wait-for-state SUCCEEDED --wait-for-state FAILED \
  --query 'data.resources[0].identifier' --raw-output 2>/dev/null || echo "")

[ -z "$SESION" ] && { echo "No se pudo crear la sesión. Ver docs/06-PLAN-B.md."; exit 1; }

CMD=$(oci bastion session get --session-id "$SESION" \
       --query 'data."ssh-metadata".command' --raw-output)
CMD="${CMD//<privateKey>/$LLAVE_PRIV}"
CMD="${CMD//<localPort>/$PUERTO_LOCAL}"

echo
echo "Sesión activa. Ejecutar EN OTRA TERMINAL y dejarla abierta:"
echo
echo "  $CMD"
echo
echo "Con el túnel abierto:"
echo "  mysqlsh --mysql -u admin -h 127.0.0.1 -P ${PUERTO_LOCAL} --sql"
echo "  python ../datos/medir_consultas.py --usuario admin --password '...' --puerto ${PUERTO_LOCAL}"
echo
echo "$CMD" > "${AQUI}/../evidencias/.comando-tunel"
