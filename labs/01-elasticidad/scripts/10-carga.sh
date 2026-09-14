#!/usr/bin/env bash
# Generador de carga para la demo de elasticidad.
#
#   ./10-carga.sh <ip-del-lb> [hilos] [ms-por-request]
#
# Golpea /burn a través del balanceador. Como el balanceador reparte en round robin,
# la CPU sube en TODAS las instancias del pool a la vez — incluidas las nuevas que
# entren.
#
# Ojo con lo que NO hace: la CPU no baja al crecer el pool. Este generador es de
# lazo cerrado —cada hilo manda la siguiente petición en cuanto recibe la anterior—,
# así que más instancias atienden más peticiones, igual de ocupadas. Medido el 12 de
# septiembre: 35 min con el pool en su máximo de 6 y la CPU arriba. El scale-in llega
# cuando se CORTA la carga. Con tráfico real de llegada fija sí bajaría: es una
# propiedad del generador, y conviene decirlo así en la demo.
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
  # Matar solo el subshell NO basta: sus curl hijos quedan huérfanos y siguen
  # generando carga. Medido: tras un Ctrl-C aparentemente limpio, la CPU seguía
  # al 80 % y el scale-in nunca llegaba. Hay que matar también a los hijos.
  for p in "${PIDS[@]:-}"; do
    pkill -P "$p" 2>/dev/null || true
    kill "$p" 2>/dev/null || true
  done
  sleep 1
  pkill -f "burn\?ms=${MS}" 2>/dev/null || true   # red de seguridad
  wait 2>/dev/null || true

  # En Git Bash para Windows NO existen pkill ni pgrep: los de arriba fallan en
  # silencio, y con `pgrep ... || echo 0` este aviso decía siempre "detenida".
  # Con Ctrl-C la carga sí se detiene (la señal llega a todo el grupo de procesos),
  # pero la comprobación era de adorno. Encontrado el la fecha.
  local vivos
  if command -v tasklist >/dev/null 2>&1; then
    vivos=$(tasklist //FI "IMAGENAME eq curl.exe" //NH 2>/dev/null | grep -ci "curl.exe")
  else
    vivos=$(pgrep -fc "burn\?ms=${MS}" 2>/dev/null | head -1)
  fi
  if [ "${vivos:-0}" -gt 0 ]; then
    echo "AVISO: quedan ${vivos} peticiones vivas. Si el pool no baja, cortarlas con:"
    echo "  taskkill //IM curl.exe //F        (Windows)   ·   pkill curl   (Linux/Mac)"
  else
    echo "Carga detenida $(date '+%H:%M:%S'). El scale-in empieza tras el enfriamiento."
  fi
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
