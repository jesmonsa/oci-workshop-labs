#!/usr/bin/env bash
# Estado de las alarmas en vivo — se proyecta durante la demo.
#
#   ./20-estado-alarmas.sh <compartment-ocid-taller07> [segundos-refresco]
#
# Muestra, para cada alarma: si está disparada y —lo importante— si está
# recibiendo datos. Una alarma "sin datos" no es una alarma tranquila: es una
# alarma ciega, y se ve exactamente igual que una que está bien.
#
# El estado se cruza por el campo `id` de la respuesta de `list-alarms-status`.
# NO existe un campo `alarm-id`: filtrar por ese nombre no encuentra nada y
# pinta "SIN DATOS" sobre alarmas perfectamente sanas, que es justo el error que
# este panel existe para enseñar a detectar.
#
# Tampoco se usa `--query` para cruzarlas. Con un OCID dentro de la expresión, el
# CLI puede intentar compilarla como expresión regular y morir con un
# `re.error: bad character range` que no dice nada. Se trae la lista una sola vez
# y se cruza con jq: una llamada en vez de N, y sin esa trampa.
#
# Y se quitan los retornos de carro: en Windows el CLI escribe CRLF, el \r se
# pega al último campo del TSV y "OK" deja de coincidir con OK. Otra forma más
# de pintar "SIN DATOS" sobre una alarma sana.

set -uo pipefail

COMP="${1:-}"
REFRESCO="${2:-20}"

[ -z "$COMP" ] && { echo "Uso: $0 <compartment-ocid> [segundos]"; exit 1; }
command -v oci >/dev/null || { echo "Falta OCI CLI"; exit 1; }
command -v jq  >/dev/null || { echo "Falta jq"; exit 1; }

while true; do
  clear
  echo "=================================================================="
  echo " Estado de alarmas — Taller de arquitectura en OCI          $(date '+%H:%M:%S')"
  echo "=================================================================="
  echo

  ALARMAS=$(oci monitoring alarm list --compartment-id "$COMP" --all 2>/dev/null) \
    || ALARMAS=""
  ESTADOS=$(oci monitoring alarm-status list-alarms-status --compartment-id "$COMP" --all 2>/dev/null) \
    || ESTADOS=""

  if [ -z "$ALARMAS" ]; then
    echo "  No se pudo consultar el servicio de monitoreo."
    echo "  Revisar perfil, región y permisos:  oci iam region list"
    echo
    echo "  Refresco cada ${REFRESCO}s. Ctrl-C para salir."
    sleep "$REFRESCO"
    continue
  fi

  TOTAL=$(echo "$ALARMAS" | jq '[.data[]?] | length')
  [ "$TOTAL" = "0" ] && echo "  No hay alarmas en este compartment."

  # Si la consulta de estado falló, se dice. Antes se confundía "no pude
  # preguntar" con "la alarma está ciega", que son dos problemas distintos y
  # llevan a explicarle al cliente uno que no existe.
  SIN_ESTADOS="no"
  [ -z "$ESTADOS" ] && SIN_ESTADOS="si"

  VACIO='{"data":[]}'
  if [ -n "$ESTADOS" ]; then
    MAPA=$(printf '%s' "$ESTADOS" | jq -c '{data: (.data // [])}' 2>/dev/null) || MAPA="$VACIO"
  else
    MAPA="$VACIO"
  fi
  [ -z "$MAPA" ] && MAPA="$VACIO"

  echo "$ALARMAS" | jq -r --argjson est "$MAPA" '
      ([$est.data[] | {key: .id, value: .status}] | from_entries) as $estado
      | .data[]?
      | [ .id,
          ."display-name",
          .severity,
          (."is-enabled" | tostring),
          ($estado[.id] // "DESCONOCIDO") ]
      | @tsv' \
  | tr -d '\r' \
  | while IFS=$'\t' read -r ID NOMBRE SEVERIDAD HABILITADA ESTADO; do
      if [ "$SIN_ESTADOS" = "si" ]; then
        MARCA=$'\033[33mno se pudo consultar\033[0m'
      else
        case "$ESTADO" in
          FIRING)      MARCA=$'\033[31mDISPARADA\033[0m' ;;
          OK)          MARCA=$'\033[32mtranquila\033[0m' ;;
          SUSPENDED)   MARCA="suspendida" ;;
          DESCONOCIDO) MARCA=$'\033[33mSIN DATOS\033[0m' ;;
          *)           MARCA="$ESTADO" ;;
        esac
      fi
      printf '  %-34s %-10s %-8s %b\n' "${NOMBRE:0:34}" "$SEVERIDAD" \
             "$([ "$HABILITADA" = "true" ] && echo "activa" || echo "APAGADA")" "$MARCA"
    done

  echo
  echo "  SIN DATOS no significa que todo esté bien: significa que la alarma no"
  echo "  aparece en el estado del servicio, es decir, que no está viendo nada."
  echo "  Es el estado más peligroso, porque se parece a la calma."
  echo
  echo "  Refresco cada ${REFRESCO}s. Ctrl-C para salir."
  sleep "$REFRESCO"
done
