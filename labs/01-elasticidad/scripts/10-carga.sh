#!/usr/bin/env bash
# Generador de carga para la demo de elasticidad.
#
#   ./10-carga.sh <ip-del-lb> [hilos] [ms-por-request]
#
# Golpea /burn a través del balanceador. Como el balanceador reparte en round robin,
# la CPU sube en TODAS las instancias del pool a la vez — incluidas las nuevas que
# entren. Eso es lo que hace que después baje sola y dispare el scale-in: más
# instancias repartiéndose la misma carga = menos CPU por instancia.
#
# Ese detalle vale la pena narrarlo en la demo: es la elasticidad completa, no
# solo la mitad de subir.
#
# Detener con Ctrl-C. El script limpia sus procesos hijos al salir.

set -uo pipefail

LB_IP="${1:-}"
HILOS="${2:-40}"
MS="${3:-400}"

if [ -z "$LB_IP" ]; then
  echo "Uso: $0 <ip-del-lb> [hilos] [ms-por-request]"
  echo "     La IP sale de:  terraform output -raw lb_ip"
  exit 1
fi

command -v curl >/dev/null || { echo "curl no está instalado"; exit 1; }

echo "Verificando que el balanceador responde..."
if ! curl -fsS --max-time 10 "http://${LB_IP}/health" >/dev/null; then
  echo "ERROR: http://${LB_IP}/health no responde."
  echo "Revisar: backends en OK, firewalld en las instancias, security list del 80."
  exit 1
fi
echo "OK."
echo

PIDS=()
limpiar() {
  echo
  echo "Deteniendo carga..."
  for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
  echo "Carga detenida $(date '+%H:%M:%S'). El scale-in empieza tras el enfriamiento."
  exit 0
}
trap limpiar INT TERM

echo "Iniciando carga: ${HILOS} hilos, ${MS}ms de CPU por request, contra ${LB_IP}"
echo "Inicio: $(date '+%H:%M:%S')  <-- anotar esta hora para medir el ciclo"
echo "Ctrl-C para detener."
echo

for _ in $(seq 1 "$HILOS"); do
  ( while true; do
      curl -s --max-time 15 "http://${LB_IP}/burn?ms=${MS}" >/dev/null 2>&1 || true
    done ) &
  PIDS+=($!)
done

# Latido: una línea por minuto para dejar rastro de la ventana de carga.
while true; do
  sleep 60
  echo "  ... carga activa $(date '+%H:%M:%S')"
done
