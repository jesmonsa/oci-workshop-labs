#!/usr/bin/env bash
# Teardown del laboratorio. Correr al final de cada día de preparación
# y al cierre de la jornada.
#
# Dos razones: el crédito del trial es finito, y apagar lo que no se usa es el
# primer hábito de FinOps que se predica en el taller. Predicarlo sin practicarlo
# se nota.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_ELAST="${AQUI}/../terraform/elasticidad"

echo "Se destruirá TODO el laboratorio de elasticidad (pool, balanceador, red)."
echo "El presupuesto y las alertas de terraform/finops NO se tocan: se dejan puestos."
echo
read -r -p "Escribir 'destruir' para confirmar: " RESPUESTA
[ "$RESPUESTA" = "destruir" ] || { echo "Cancelado."; exit 0; }

echo
echo "1/3 Deshabilitando el autoescalamiento para que no recree instancias..."
AS_ID=$(cd "$TF_ELAST" && terraform output -raw autoscaling_configuration_id 2>/dev/null || echo "")
if [ -n "$AS_ID" ]; then
  oci autoscaling configuration update --auto-scaling-configuration-id "$AS_ID" \
    --is-enabled false --force >/dev/null 2>&1 || true
  echo "    Deshabilitado."
  sleep 10
else
  echo "    Sin configuración de autoescalamiento en el estado. Se continúa."
fi

echo "2/3 terraform destroy..."
cd "$TF_ELAST"
terraform destroy -auto-approve

echo "3/3 Verificación: instancias que sigan vivas en el compartment"
COMP=$(terraform output -raw compartment_ocid 2>/dev/null || echo "")
if [ -n "$COMP" ]; then
  oci compute instance list --compartment-id "$COMP" \
    --lifecycle-state RUNNING \
    --query 'data[].{Nombre:"display-name",Estado:"lifecycle-state"}' \
    --output table 2>/dev/null || echo "    (nada corriendo)"
fi

echo
echo "Listo. Revisar el consumo del día en Billing & Cost Management > Cost Analysis,"
echo "filtrando por el tag Proyecto=TallerOCI."
