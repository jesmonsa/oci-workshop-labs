#!/usr/bin/env bash
# Teardown del laboratorio seguro del módulo 2.
#
# Qué NO destruye, a propósito:
#   - Cloud Guard (es de nivel tenancy y no tiene costo; se deja encendido).
#   - La Security Zone y su compartment (tampoco tienen costo).
#   - El presupuesto de terraform/finops del módulo 1.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${AQUI}/../terraform/seguro"

echo "Se destruirá el laboratorio seguro: LB, WAF, bastión, instancias, red, logs y alertas."
read -r -p "Escribir 'destruir' para confirmar: " R
[ "$R" = "destruir" ] || { echo "Cancelado."; exit 0; }

# Las sesiones activas de Bastion bloquean el borrado del bastión durante unos minutos.
BASTION=$(terraform output -raw bastion_id 2>/dev/null || echo "")
if [ -n "$BASTION" ]; then
  for S in $(oci bastion session list --bastion-id "$BASTION" --session-lifecycle-state ACTIVE \
               --all --query 'data[].id' 2>/dev/null | jq -r '.[]?'); do
    echo "Cerrando sesión de bastión ${S:0:30}..."
    oci bastion session delete --session-id "$S" --force >/dev/null 2>&1 || true
  done
fi

terraform destroy -auto-approve
echo
echo "Listo. Revisar Cost Analysis filtrando por Modulo=02-seguridad."
