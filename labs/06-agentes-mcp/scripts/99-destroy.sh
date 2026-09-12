#!/usr/bin/env bash
# Teardown del módulo 6.
#
# Con el nivel siempre gratuito la base no consume crédito, así que no hay prisa
# por borrarla. Pero sí conviene quitar las conexiones guardadas y el wallet del
# equipo: son credenciales reales, guardadas en claro para el servidor MCP, y
# quedarse con ellas después del laboratorio es exactamente el descuido del que
# habla este módulo.

set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF="${AQUI}/../terraform/basedatos"
WALLET="${AQUI}/../wallet"

echo "Se van a eliminar:"
echo "  · las conexiones guardadas de SQLcl del laboratorio (lab06, lab06lectura)"
echo "  · el wallet descargado en ${WALLET}"
echo "  · la base de datos, con todo lo que contiene"
echo
read -r -p "Escribir 'destruir' para confirmar: " R
[ "$R" = "destruir" ] || { echo "Cancelado."; exit 0; }

echo
echo "1/3 Borrando conexiones guardadas..."
for c in lab06 lab06lectura; do
  sql /nolog <<EOF >/dev/null 2>&1 || true
connect -delete ${c}
exit
EOF
  echo "    ${c}"
done

echo "2/3 Borrando el wallet..."
rm -rf "$WALLET" && echo "    ${WALLET}"

echo "3/3 Destruyendo la base..."
if [ -d "$TF" ] && [ -f "${TF}/terraform.tfstate" ]; then
  cd "$TF" && terraform destroy -auto-approve
else
  echo "    Sin estado de Terraform aquí."
  echo "    Si la base se creó desde Resource Manager, usar la acción Destroy del stack."
fi

echo
echo "Listo."
echo
echo "Un último recordatorio que vale para cualquier equipo, no solo para este"
echo "laboratorio: si se configuró un servidor MCP en un cliente de IA, la entrada"
echo "sigue ahí y apunta a algo que ya no existe. Conviene quitarla también."
