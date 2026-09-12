#!/usr/bin/env bash
# Panel de texto para seguir el escalamiento en vivo.
#
#   ./20-observar.sh <instance-pool-ocid> <load-balancer-ocid> <backend-set> <ip-lb>
#
# Todos los valores salen de `terraform output` en terraform/elasticidad.
#
# Para qué sirve: la consola de OCI es la pantalla bonita, pero tarda en refrescar
# y hay que navegar. Este panel muestra en una sola vista el tamaño del pool, el
# estado de cada backend y qué host está respondiendo. En la demo se proyecta la
# consola; esta terminal es la que TÚ miras para saber cuándo hablar.
#
# También sirve para lo den la preparación: deja una traza con hora de cada cambio, que es
# exactamente lo que hay que medir para cronometrar el guion.

set -uo pipefail

POOL_ID="${1:-}"
LB_ID="${2:-}"
BSET="${3:-}"
LB_IP="${4:-}"
INTERVALO="${5:-15}"

if [ -z "$POOL_ID" ] || [ -z "$LB_ID" ] || [ -z "$BSET" ] || [ -z "$LB_IP" ]; then
  cat <<'AYUDA'
Uso: ./20-observar.sh <instance-pool-ocid> <lb-ocid> <backend-set> <ip-lb> [segundos]

Obtener los valores:
  cd ../terraform/elasticidad
  ./20-observar.sh \
    "$(terraform output -raw instance_pool_id)" \
    "$(terraform output -raw load_balancer_id)" \
    "$(terraform output -raw backend_set_name)" \
    "$(terraform output -raw lb_ip)"
AYUDA
  exit 1
fi

ULTIMO_TAMANO=""

while true; do
  AHORA=$(date '+%H:%M:%S')

  TAMANO=$(oci compute-management instance-pool get --instance-pool-id "$POOL_ID" \
            --query 'data.size' --raw-output 2>/dev/null || echo "?")
  ESTADO=$(oci compute-management instance-pool get --instance-pool-id "$POOL_ID" \
            --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo "?")

  clear
  echo "=============================================================="
  echo " Taller de arquitectura en OCI - módulo 1 - Elasticidad         $AHORA"
  echo "=============================================================="
  echo
  printf " Instance pool : tamaño %s   estado %s\n" "$TAMANO" "$ESTADO"

  if [ -n "$ULTIMO_TAMANO" ] && [ "$TAMANO" != "$ULTIMO_TAMANO" ]; then
    printf " >>> CAMBIO DE TAMAÑO %s -> %s a las %s\n" "$ULTIMO_TAMANO" "$TAMANO" "$AHORA"
    # Traza persistente para el ejercicio de medición den la preparación.
    echo "$AHORA  pool $ULTIMO_TAMANO -> $TAMANO" >> ../evidencias/traza-escalamiento.log
  fi
  ULTIMO_TAMANO="$TAMANO"

  echo
  echo " Backends del balanceador:"
  # El comando es backend-set-health get: «backend-health list» no existe.
  oci lb backend-set-health get --load-balancer-id "$LB_ID" --backend-set-name "$BSET" \
    --query 'data.{Estado:status,Total:"total-backend-count",Criticos:"critical-state-backend-names"}' \
    --output table 2>/dev/null || echo "   (sin datos todavía)"

  echo
  echo " Quién responde (5 peticiones seguidas):"
  for _ in 1 2 3 4 5; do
    HOST=$(curl -s --max-time 5 "http://${LB_IP}/" 2>/dev/null | awk -F': *' '/Atendido por/{print $2}')
    printf "   - %s\n" "${HOST:-sin respuesta}"
  done

  echo
  echo " Refresco cada ${INTERVALO}s. Ctrl-C para salir."
  sleep "$INTERVALO"
done
