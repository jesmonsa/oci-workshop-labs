#!/usr/bin/env bash
# Genera un ZIP por stack, listo para Oracle Cloud Resource Manager.
#
#   ./scripts/empaquetar-stacks.sh
#
# Resource Manager espera la configuración de Terraform en la RAÍZ del ZIP, junto a
# su schema.yaml. Por eso cada ZIP contiene el contenido de una carpeta de Terraform,
# no el repositorio completo.
#
# Los ZIP quedan en dist/ y son los que publica el flujo de GitHub Actions como
# activos de una release. La URL de esa release es la que usa el botón de despliegue.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="${RAIZ}/dist"

STACKS=(
  "presupuesto-y-alertas|labs/01-elasticidad/terraform/finops"
  "01-elasticidad|labs/01-elasticidad/terraform/elasticidad"
  "02-seguridad|labs/02-seguridad/terraform/seguro"
  "04-datos-analitica|labs/04-datos-analitica/terraform/heatwave"
  "05-observabilidad|labs/05-observabilidad/terraform/observabilidad"
)

command -v zip >/dev/null || { echo "Falta 'zip'."; exit 1; }

rm -rf "$SALIDA"
mkdir -p "$SALIDA"

echo "Empaquetando stacks para Resource Manager..."
echo

for entrada in "${STACKS[@]}"; do
  nombre="${entrada%%|*}"
  ruta="${RAIZ}/${entrada##*|}"

  if [ ! -d "$ruta" ]; then
    echo "  ERROR: no existe $ruta"
    exit 1
  fi
  if [ ! -f "${ruta}/schema.yaml" ]; then
    echo "  ERROR: falta schema.yaml en $ruta"
    echo "         Sin él, Resource Manager pide las variables sueltas en vez de un formulario."
    exit 1
  fi

  ( cd "$ruta" && zip -r -q "${SALIDA}/${nombre}.zip" . \
      -x '.terraform/*' '*.tfstate' '*.tfstate.*' 'terraform.tfvars' '*.tfplan' \
         '.terraform.lock.hcl' )

  tam=$(du -h "${SALIDA}/${nombre}.zip" | cut -f1)
  echo "  ${nombre}.zip  (${tam})"
done

echo
echo "Listo. ${#STACKS[@]} stacks en dist/"
echo
echo "Para probar uno a mano, sin publicarlo:"
echo "  consola de OCI -> Developer Services -> Resource Manager -> Stacks -> Create stack"
echo "  -> My configuration -> .zip file -> subir el archivo de dist/"
