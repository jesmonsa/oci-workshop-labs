#!/usr/bin/env bash
# Prueba de extremo a extremo: genera carga y cronometra cuánto tarda la alarma
# en dispararse.
#
#   ./10-probar-alarma.sh <compartment-taller07> <ip-lb-taller3> [nombre-alarma]
#
# Para qué sirve: en la preparación, para MEDIR el tiempo real de disparo — que es lo que
# permite cronometrar el guion den la preparación. Igual que se hizo con el ciclo de
# autoescalamiento en el módulo 1, y por la misma razón: no se puede narrar en vivo
# algo cuyo tiempo no se conoce.
#
# Lo que se espera ver, y que es el corazón del bloque:
#   1. la alarma pasa a DISPARADA
#   2. llega el correo
#   3. el autoescalamiento agrega instancias
#   4. la CPU por instancia baja y la alarma se cierra SOLA
#
# El paso 4 es el interesante: una alarma que se resuelve sola no debería despertar
# a nadie, pero sí quedar registrada.

set -uo pipefail

COMP="${1:-}"
LB_IP="${2:-}"
ALARMA="${3:-lab05-saturacion-cpu}"

if [ -z "$COMP" ] || [ -z "$LB_IP" ]; then
  echo "Uso: $0 <compartment-ocid-taller07> <ip-lb-taller3> [nombre-alarma]"
  exit 1
fi

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARGA="${AQUI}/../../01-elasticidad/scripts/10-carga.sh"
BITACORA="${AQUI}/../evidencias/tiempos-alarma.md"
mkdir -p "$(dirname "$BITACORA")"

estado_alarma() {
  oci monitoring alarm-status list-alarms-status --compartment-id "$COMP" \
    --query "data[?\"display-name\"=='${ALARMA}'].status | [0]" --raw-output 2>/dev/null || echo "?"
}

echo "Estado inicial de '${ALARMA}': $(estado_alarma)"
echo

if [ ! -x "$CARGA" ]; then
  echo "No encuentro el generador de carga del módulo 1 en:"
  echo "  $CARGA"
  echo "Arráncalo a mano y vuelve a correr este script para solo cronometrar."
  exit 1
fi

INICIO=$(date +%s)
echo "Arrancando carga contra ${LB_IP} a las $(date '+%H:%M:%S')..."
"$CARGA" "$LB_IP" 40 400 >/dev/null 2>&1 &
PID_CARGA=$!

limpiar() {
  echo; echo "Deteniendo carga..."
  kill "$PID_CARGA" 2>/dev/null || true
  pkill -P "$PID_CARGA" 2>/dev/null || true
  exit 0
}
trap limpiar INT TERM

DISPARO=""
CIERRE=""
echo "Vigilando la alarma. Ctrl-C para salir."
echo

while true; do
  sleep 20
  AHORA=$(date +%s)
  TRANSCURRIDO=$(( AHORA - INICIO ))
  ESTADO=$(estado_alarma)
  printf '  %s  t+%-5s  estado: %s\n' "$(date '+%H:%M:%S')" "${TRANSCURRIDO}s" "$ESTADO"

  if [ "$ESTADO" = "FIRING" ] && [ -z "$DISPARO" ]; then
    DISPARO=$TRANSCURRIDO
    echo
    echo "  >>> DISPARÓ a los ${DISPARO}s desde el inicio de la carga."
    echo "  >>> Revisa el correo ahora: debe llegar en menos de un minuto."
    echo
    echo "  Ahora deja correr: el autoescalamiento del módulo 1 va a agregar"
    echo "  instancias y la alarma debería cerrarse sola."
    echo
  fi

  if [ -n "$DISPARO" ] && [ "$ESTADO" = "OK" ] && [ -z "$CIERRE" ]; then
    CIERRE=$TRANSCURRIDO
    echo
    echo "  >>> SE CERRÓ SOLA a los ${CIERRE}s (${DISPARO}s disparada)."
    {
      echo "## Medición $(date '+%Y-%m-%d %H:%M')"
      echo
      echo "| Evento | Segundos desde el inicio de la carga |"
      echo "|---|---|"
      echo "| La alarma dispara | ${DISPARO} |"
      echo "| La alarma se cierra sola | ${CIERRE} |"
      echo "| Tiempo disparada | $(( CIERRE - DISPARO )) |"
      echo
      echo "Umbral y duración pendiente: ver terraform.tfvars."
      echo "Este es el número que se dice en voz alta en la preparación."
      echo
    } >> "$BITACORA"
    echo "  Anotado en $BITACORA"
    limpiar
  fi
done
