#!/usr/bin/env bash
# Teardown del laboratorio de datos.
#
# Importante: el sistema de base de datos es, con diferencia, lo más caro de todos
# los laboratorios de la jornada. Si se deja encendido un fin de semana completo, se
# nota en el crédito del trial. Destruirlo al terminar cada día de preparación.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${AQUI}/../terraform/heatwave"

echo "Se destruirá el laboratorio de datos: base de datos, acelerador (si existe),"
echo "bastión y red. Los datos cargados se pierden — se regeneran con generar_datos.py."
echo
read -r -p "Escribir 'destruir' para confirmar: " R
[ "$R" = "destruir" ] || { echo "Cancelado."; exit 0; }

BASTION=$(terraform output -raw bastion_id 2>/dev/null || echo "")
if [ -n "$BASTION" ]; then
  for S in $(oci bastion session list --bastion-id "$BASTION" \
               --session-lifecycle-state ACTIVE --all --query 'data[].id' 2>/dev/null | jq -r '.[]?'); do
    oci bastion session delete --session-id "$S" --force >/dev/null 2>&1 || true
  done
  echo "Sesiones de bastión cerradas."
fi

# El sistema de base de datos tarda varios minutos en borrarse: no interrumpir.
terraform destroy -auto-approve

echo
echo "Listo. Verificar en Cost Analysis con el filtro Modulo=04-datos-analitica."
