#!/usr/bin/env bash
# Crea una sesión de Bastion hacia una instancia privada y deja listo el comando SSH.
#
#   ./30-sesion-bastion.sh [ttl-segundos]
#
# Toma bastion_id e instancia desde `terraform output` de terraform/seguro.
#
# Crear la sesión toma 1–2 minutos. en la preparación se ejecuta en la pausa café (15:40),
# con TTL de 3 horas, y en el bloque solo se usa el comando ya generado.
#
# Intenta primero una sesión SSH administrada (requiere el plugin Bastion activo en
# la instancia). Si falla, cae a port forwarding al 22, que no depende del plugin.

set -uo pipefail

TTL="${1:-10800}"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF="${AQUI}/../terraform/seguro"
LLAVE_PUB="${SSH_PUB:-$HOME/.ssh/id_rsa.pub}"
LLAVE_PRIV="${LLAVE_PUB%.pub}"

BASTION=$(cd "$TF" && terraform output -raw bastion_id)
INSTANCIA=$(cd "$TF" && terraform output -json instancia_ids | jq -r '.[0]')
IP_PRIV=$(cd "$TF" && terraform output -json instancia_ips_privadas | jq -r '.[0]')

echo "Tu IP pública ahora: $(curl -s --max-time 5 ifconfig.me || echo '?')"
echo "Debe estar en ips_admin_cidr. Si no, la sesión se crea pero la conexión no entra."
echo

echo "Creando sesión SSH administrada (TTL ${TTL}s) hacia ${IP_PRIV}..."
SESION=$(oci bastion session create-managed-ssh \
  --bastion-id "$BASTION" \
  --target-resource-id "$INSTANCIA" \
  --target-os-username opc \
  --ssh-public-key-file "$LLAVE_PUB" \
  --session-ttl "$TTL" \
  --display-name "lab02-demo-$(date +%H%M)" \
  --wait-for-state SUCCEEDED --wait-for-state FAILED \
  --query 'data.resources[0].identifier' --raw-output 2>/dev/null || echo "")

TIPO="managed"
if [ -z "$SESION" ] || [ "$SESION" = "null" ]; then
  echo "La sesión administrada falló (¿plugin Bastion aún no activo?). Probando port forwarding..."
  TIPO="port-forwarding"
  SESION=$(oci bastion session create-port-forwarding \
    --bastion-id "$BASTION" \
    --target-private-ip "$IP_PRIV" \
    --target-port 22 \
    --ssh-public-key-file "$LLAVE_PUB" \
    --session-ttl "$TTL" \
    --display-name "lab02-demo-pf-$(date +%H%M)" \
    --wait-for-state SUCCEEDED --wait-for-state FAILED \
    --query 'data.resources[0].identifier' --raw-output 2>/dev/null || echo "")
fi

[ -z "$SESION" ] && { echo "No se pudo crear la sesión. Ver docs/06-PLAN-B.md."; exit 1; }

CMD=$(oci bastion session get --session-id "$SESION" \
       --query 'data."ssh-metadata".command' --raw-output)
# La ruta de la llave va entre comillas SIMPLES, y se arma en una variable aparte.
#
# Dos razones, las dos aprendidas rompiéndolo:
#   · En Windows el directorio del usuario suele llevar un espacio. Sin comillas,
#     el comando SSH se parte y falla con «Identity file ... not accessible».
#   · Las comillas no pueden ser dobles: el ProxyCommand ya viene envuelto en
#     dobles, y unas dobles dentro lo cierran antes de tiempo. El síntoma es un
#     desconcertante «remote username contains invalid characters».
RUTA_LLAVE="'${LLAVE_PRIV}'"
CMD="${CMD//<privateKey>/${RUTA_LLAVE}}"

# La PRIMERA conexión al bastión pide aceptar su huella, y el salto interno
# (ProxyCommand) la pide por separado. Frente a un cliente eso son dos pausas
# incómodas, así que se aceptan automáticamente las huellas nuevas. Sigue
# avisando si una huella conocida CAMBIA, que es el caso que de verdad importa.
CMD="${CMD/-W %h:%p/-o StrictHostKeyChecking=accept-new -W %h:%p}"
CMD="${CMD} -o StrictHostKeyChecking=accept-new"
[ "$TIPO" = "port-forwarding" ] && CMD="${CMD//<localPort>/2222}"

echo
echo "Sesión ${TIPO} ACTIVA — expira en $((TTL/60)) minutos."
echo
echo "Comando:"
echo "  $CMD"
[ "$TIPO" = "port-forwarding" ] && echo "  # y en otra terminal:  ssh -i $LLAVE_PRIV -p 2222 opc@localhost"
echo
echo "$CMD" > "${AQUI}/../evidencias/.comando-bastion"
echo "Guardado en evidencias/.comando-bastion (no se versiona)."
echo
echo "Qué mostrar ya dentro de la máquina:"
echo "  hostname; ip -4 addr show | grep inet    # solo IP privada"
echo "  curl -s ifconfig.me                       # sale por el NAT, no por una IP propia"
