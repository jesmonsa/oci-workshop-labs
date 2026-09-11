#!/usr/bin/env bash
# Estado de las alarmas en vivo — se proyecta durante la demo.
#
#   ./20-estado-alarmas.sh <compartment-ocid-taller07> [segundos-refresco]
#
# Muestra, para cada alarma: si está disparada, desde cuándo, y —lo importante—
# si está recibiendo datos. Una alarma "sin datos" no es una alarma tranquila:
# es una alarma ciega, y se ve exactamente igual que una que está bien.

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

  ALARMAS=$(oci monitoring alarm list --compartment-id "$COMP" --all 2>/dev/null \
            || echo '{"data":[]}')

  TOTAL=$(echo "$ALARMAS" | jq '[.data[]?] | length')
  if [ "$TOTAL" = "0" ]; then
    echo "  No hay alarmas en este compartment."
  fi

  echo "$ALARMAS" | jq -r '.data[]? | [.id, ."display-name", .severity, (."is-enabled"|tostring)] | @tsv' \
  | while IFS=$'\t' read -r ID NOMBRE SEVERIDAD HABILITADA; do
      ESTADO=$(oci monitoring alarm-status list --compartment-id "$COMP" \
                --query "data[?\"alarm-id\"=='$ID'].status | [0]" --raw-output 2>/dev/null || echo "?")
      case "$ESTADO" in
        FIRING)     MARCA=$'\033[31mDISPARADA\033[0m' ;;
        OK)         MARCA=$'\033[32mtranquila\033[0m' ;;
        SUSPENDED)  MARCA="suspendida" ;;
        *)          MARCA=$'\033[33mSIN DATOS\033[0m' ;;
      esac
      printf '  %-34s %-10s %-8s %b\n' "${NOMBRE:0:34}" "$SEVERIDAD" \
             "$([ "$HABILITADA" = "true" ] && echo "activa" || echo "APAGADA")" "$MARCA"
    done

  echo
  echo "  SIN DATOS no significa que todo esté bien: significa que la alarma no está"
  echo "  viendo nada. Es el estado más peligroso, porque se parece a la calma."
  echo
  echo "  Refresco cada ${REFRESCO}s. Ctrl-C para salir."
  sleep "$REFRESCO"
done
