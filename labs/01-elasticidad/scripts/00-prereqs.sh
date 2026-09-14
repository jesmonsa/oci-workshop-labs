#!/usr/bin/env bash
# Verificación de prerrequisitos del laboratorio — correr el D-7.
#
# No crea nada. Solo responde una pregunta: ¿este trial aguanta el laboratorio?
# Guardar la salida:  ./00-prereqs.sh | tee ../evidencias/00-prereqs-$(date +%F).txt

set -uo pipefail

ok()    { printf '  [ OK ]  %s\n' "$1"; }
falta() { printf '  [FALTA] %s\n' "$1"; FALLOS=$((FALLOS+1)); }
aviso() { printf '  [ !  ]  %s\n' "$1"; }
titulo(){ printf '\n== %s ==\n' "$1"; }

FALLOS=0

titulo "Herramientas locales"
for cmd in oci terraform jq curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd $("$cmd" --version 2>/dev/null | head -1)"
  else
    falta "$cmd no está instalado"
  fi
done

titulo "Identidad y región"
# Se filtra con jq y NO con --query. En algunas versiones del CLI, un filtro que
# lleva un campo entrecomillado con guiones ("is-home-region") acaba compilandose
# como expresion regular y revienta con "bad character range s-h". Como la salida
# va a /dev/null, el script concluia que OCI no responde cuando responde
# perfectamente, y anunciaba "NO SE PUEDE CONTINUAR" como primera impresion del
# laboratorio.
if ! REGION=$(oci iam region-subscription list --output json 2>/dev/null               | jq -r '[.data[] | select(."is-home-region") | ."region-name"][0] // empty' | tr -d '
')    || [ -z "$REGION" ]; then
  falta "No se pudo consultar OCI. Revisar ~/.oci/config y la llave de API."
  echo
  echo "Resultado: NO SE PUEDE CONTINUAR. Corregir autenticación antes de seguir."
  exit 1
fi
ok "Región home: $REGION"
oci iam region-subscription list --query 'data[].{"region":"region-name"}' --output table 2>/dev/null

TENANCY=$(oci iam compartment list --compartment-id-in-subtree true --all \
  --query 'data[0]."compartment-id"' --raw-output 2>/dev/null || echo "")
[ -n "$TENANCY" ] && ok "Tenancy accesible" || aviso "No se listaron compartments"

titulo "Compartment del laboratorio"
# --compartment-id-in-subtree es imprescindible: lab-01-elasticidad no cuelga del
# tenancy sino de lab, y sin recorrer el arbol la busqueda vuelve vacia. El
# script concluia que el compartment no existe teniendolo delante, y lo marcaba
# como bloqueante.
COMP_ID=$(oci iam compartment list --compartment-id "${TENANCY:-}" \
  --compartment-id-in-subtree true --all --name lab-01-elasticidad \
  --query 'data[0].id' --raw-output 2>/dev/null | tr -d '\015' || echo "")
if [ -n "$COMP_ID" ] && [ "$COMP_ID" != "null" ]; then
  ok "lab-01-elasticidad existe: ${COMP_ID:0:35}..."
else
  falta "No existe el compartment lab-01-elasticidad. Crearlo antes de aplicar Terraform."
fi

titulo "Límites de servicio — el riesgo número uno de un trial"
echo "  Si alguno aparece en 0, solicitar aumento HOY: la aprobación toma días."
echo

chequear_limite () {
  local servicio="$1" nombre="$2" descripcion="$3"
  local valor
  valor=$(oci limits value list --service-name "$servicio" \
            --compartment-id "${TENANCY:-$COMP_ID}" \
            --name "$nombre" --query 'data[0].value' --raw-output 2>/dev/null || echo "")
  if [ -z "$valor" ] || [ "$valor" = "null" ]; then
    aviso "$descripcion: no consultable desde CLI, verificar en consola"
  elif [ "$valor" = "0" ]; then
    falta "$descripcion: límite en 0 — SOLICITAR AUMENTO"
  else
    ok "$descripcion: $valor"
  fi
}

chequear_limite "compute" "standard-e4-core-count"     "Cores E4.Flex"
chequear_limite "compute" "standard-e5-core-count"     "Cores E5.Flex"
chequear_limite "load-balancer" "lb-flexible-count"    "Balanceadores flexibles"
chequear_limite "mysql"   "vm-standard-e3-core-count"  "MySQL HeatWave (cores)"

echo
echo "  Verificar además en la consola (Limits, Quotas and Usage):"
echo "    - Instance Pool / Autoscaling habilitados"
echo "    - Block Volume (GB disponibles)"
echo "    - Autonomous Database (si se usa como alternativa administrada)"

titulo "Crédito del trial"
echo "  Consultar manualmente en: Billing & Cost Management > Subscriptions."
echo "  Anotar en evidencias/: crédito otorgado, consumido y fecha de expiración."

titulo "Resultado"
if [ "$FALLOS" -eq 0 ]; then
  echo "  Sin bloqueantes detectados. Se puede continuar con terraform/finops."
else
  echo "  $FALLOS bloqueante(s). Resolver antes de aplicar Terraform."
  echo "  Recordatorio: los aumentos de límite NO son inmediatos. Pedirlos hoy."
fi
exit 0
