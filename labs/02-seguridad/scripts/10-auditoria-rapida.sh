#!/usr/bin/env bash
# Auditoría rápida de postura — SOLO LECTURA.
#
#   ./10-auditoria-rapida.sh <compartment-ocid> [tenancy-ocid]
#
# No crea, no modifica, no borra nada. Solo ejecuta list/get. Por eso es seguro
# entregárselo a la organización para que lo corra contra su propio tenancy de desarrollo:
# lo único que necesita es un usuario con permisos de lectura (inspect/read).
#
# En la sesión se corre contra el compartment del módulo 1, que se construyó
# simplificado a propósito. Cada hallazgo apunta al ID del control en el checklist.
#
# Salida: tabla en pantalla + archivo en ../evidencias/auditoria-<fecha>.txt

set -uo pipefail

COMP="${1:-}"
TENANCY="${2:-}"

if [ -z "$COMP" ]; then
  echo "Uso: $0 <compartment-ocid> [tenancy-ocid]"
  echo "     Con tenancy-ocid se agregan los chequeos de IAM, Cloud Guard y Audit."
  exit 1
fi

command -v oci >/dev/null || { echo "Falta OCI CLI"; exit 1; }
command -v jq  >/dev/null || { echo "Falta jq"; exit 1; }

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${AQUI}/../evidencias"
SALIDA="${AQUI}/../evidencias/auditoria-$(date +%Y%m%d-%H%M).txt"

ALTOS=0; MEDIOS=0; OKS=0
HALLAZGOS=()

# Los valores vienen del CLI, que en Windows escribe CRLF. Un retorno de carro
# dentro del texto de un hallazgo hace que el terminal vuelva al inicio de la
# linea y escriba encima: el hallazgo sale ilegible en pantalla, aunque el conteo
# sea correcto. Se limpia AQUI, en la unica puerta por la que sale todo, y no en
# cada sitio donde se arma un mensaje.
limpiar_cr() { printf '%s' "$1" | tr -d '\015'; }

hallazgo() {  # severidad control descripcion
  local sev="$1" ctl="$2" txt
  txt="$(limpiar_cr "$3")"
  HALLAZGOS+=("$(printf '%-5s  %-5s  %s' "$sev" "$ctl" "$txt")")
  case "$sev" in
    ALTO)  ALTOS=$((ALTOS+1)) ;;
    MEDIO) MEDIOS=$((MEDIOS+1)) ;;
  esac
}
cumple() { OKS=$((OKS+1)); HALLAZGOS+=("$(printf '%-5s  %-5s  %s' "ok" "$(limpiar_cr "$1")" "$(limpiar_cr "$2")")"); }
paso()   { printf '  - %s...\n' "$1"; }

echo
echo "Auditoría rápida de postura — solo lectura"
echo "Compartment: ${COMP:0:40}..."
echo

# --- R-01 · Instancias con IP pública -----------------------------------------
# Antes de decodificar se quita el retorno de carro. En Windows el CLI escribe
# CRLF, ese caracter viaja dentro de la cadena y la invalida, asi que el comando
# de decodificacion se queja en mitad de la demostracion. No altera el resultado
# de la auditoria: solo ensucia la pantalla justo cuando el cliente esta mirando.
paso "Instancias con IP pública"
INSTANCIAS=$(oci compute instance list --compartment-id "$COMP" --all \
  --lifecycle-state RUNNING --query 'data[].{id:id,n:"display-name"}' 2>/dev/null || echo "[]")
N_PUB=0
for row in $(echo "$INSTANCIAS" | jq -r '.[] | @base64'); do
  ID=$(printf '%s' "$row" | tr -d '\015' | base64 -d | jq -r .id)
  NOMBRE=$(printf '%s' "$row" | tr -d '\015' | base64 -d | jq -r .n)
  IP=$(oci compute instance list-vnics --instance-id "$ID" \
        --query 'data[0]."public-ip"' --raw-output 2>/dev/null || echo "")
  if [ -n "$IP" ] && [ "$IP" != "null" ]; then
    hallazgo ALTO R-01 "Instancia '$NOMBRE' tiene IP pública ($IP)"
    N_PUB=$((N_PUB+1))
  fi
done
[ "$N_PUB" -eq 0 ] && cumple R-01 "Ninguna instancia en ejecución tiene IP pública"

# --- R-01 · Subredes que permiten IP pública ----------------------------------
paso "Subredes públicas"
oci network subnet list --compartment-id "$COMP" --all 2>/dev/null \
  | jq -r '.data[]? | select(."prohibit-public-ip-on-vnic"==false) | ."display-name"' \
  | while read -r s; do [ -n "$s" ] && echo "MEDIO|R-01|Subred '$s' permite IP pública (válido solo para balanceadores)"; done \
  > /tmp/odt_subredes.$$ || true
while IFS='|' read -r sev ctl txt; do [ -n "$sev" ] && hallazgo "$sev" "$ctl" "$txt"; done < /tmp/odt_subredes.$$
rm -f /tmp/odt_subredes.$$

# --- R-02 · Security lists con SSH/RDP/todo abierto a internet -----------------
paso "Security lists abiertas a 0.0.0.0/0"
SLS=$(oci network security-list list --compartment-id "$COMP" --all 2>/dev/null || echo '{"data":[]}')
ABIERTAS=$(echo "$SLS" | jq -r '
  .data[]? as $sl
  | $sl."ingress-security-rules"[]?
  | select(.source=="0.0.0.0/0")
  | select(
      .protocol=="all"
      or (.protocol=="6" and (
            (."tcp-options"==null)
            or ((."tcp-options"."destination-port-range".min // 0) <= 22   and (."tcp-options"."destination-port-range".max // 65535) >= 22)
            or ((."tcp-options"."destination-port-range".min // 0) <= 3389 and (."tcp-options"."destination-port-range".max // 65535) >= 3389)
            or ((."tcp-options"."destination-port-range".min // 0) <= 3306 and (."tcp-options"."destination-port-range".max // 65535) >= 3306)
          ))
    )
  | "\($sl."display-name")|\(.protocol)|\(."tcp-options"."destination-port-range".min // "todos")"' | sort -u)
if [ -n "$ABIERTAS" ]; then
  while IFS='|' read -r nombre proto puerto; do
    hallazgo ALTO R-02 "Security list '$nombre' abre puerto $puerto (proto $proto) a 0.0.0.0/0"
  done <<< "$ABIERTAS"
else
  cumple R-02 "Ninguna security list abre SSH/RDP/MySQL a internet"
fi

# --- R-03 · NSGs con SSH/RDP abierto a internet --------------------------------
paso "NSGs abiertos a 0.0.0.0/0"
N_NSG_MAL=0
for NSG in $(oci network nsg list --compartment-id "$COMP" --all --query 'data[].id' 2>/dev/null | jq -r '.[]?'); do
  NN=$(oci network nsg get --nsg-id "$NSG" --query 'data."display-name"' --raw-output 2>/dev/null)
  MAL=$(oci network nsg rules list --nsg-id "$NSG" --all 2>/dev/null | jq -r '
    .data[]? | select(.direction=="INGRESS" and .source=="0.0.0.0/0")
    | select(.protocol=="all" or ((."tcp-options"."destination-port-range".min // 0) <= 22 and (."tcp-options"."destination-port-range".max // 65535) >= 22))
    | "x"' | head -1)
  if [ -n "$MAL" ]; then hallazgo ALTO R-03 "NSG '$NN' permite SSH o todo el tráfico desde internet"; N_NSG_MAL=$((N_NSG_MAL+1)); fi
done
[ "$N_NSG_MAL" -eq 0 ] && cumple R-03 "Ningún NSG abre SSH a internet"

# --- B-02 · Balanceadores públicos sin WAF ------------------------------------
paso "Balanceadores públicos sin WAF"
WAF_LBS=$(oci waf web-app-firewall list --compartment-id "$COMP" --all 2>/dev/null \
  | jq -r '.data.items[]? | ."load-balancer-id" // empty')
N_LB=0
for row in $(oci lb load-balancer list --compartment-id "$COMP" --all 2>/dev/null \
    | jq -r '.data[]? | select(."is-private"==false) | @base64'); do
  LBID=$(printf '%s' "$row" | tr -d '\015' | base64 -d | jq -r .id)
  LBN=$(printf '%s' "$row" | tr -d '\015' | base64 -d | jq -r '."display-name"')
  N_LB=$((N_LB+1))
  if echo "$WAF_LBS" | grep -q "$LBID"; then
    cumple B-02 "Balanceador '$LBN' tiene WAF"
  else
    hallazgo ALTO B-02 "Balanceador público '$LBN' SIN WAF"
  fi
  # B-03: ¿algún listener sin TLS?
  HTTP=$(oci lb load-balancer get --load-balancer-id "$LBID" 2>/dev/null \
    | jq -r '.data.listeners[]? | select(."ssl-configuration"==null) | .name' | head -1)
  [ -n "$HTTP" ] && hallazgo MEDIO B-03 "Balanceador '$LBN' tiene listener sin TLS ($HTTP)"
done

# --- D-02 · Buckets públicos ---------------------------------------------------
paso "Buckets de Object Storage públicos"
N_BPUB=0
for B in $(oci os bucket list --compartment-id "$COMP" --all --query 'data[].name' 2>/dev/null | jq -r '.[]?'); do
  ACC=$(oci os bucket get --bucket-name "$B" --query 'data."public-access-type"' --raw-output 2>/dev/null)
  if [ "$ACC" != "NoPublicAccess" ] && [ -n "$ACC" ]; then
    hallazgo ALTO D-02 "Bucket '$B' es público ($ACC)"; N_BPUB=$((N_BPUB+1))
  fi
done
[ "$N_BPUB" -eq 0 ] && cumple D-02 "Sin buckets públicos en el compartment"

# --- L-02 · Flow logs ----------------------------------------------------------
paso "Flow logs de VCN"
N_FLOW=0
for LG in $(oci logging log-group list --compartment-id "$COMP" --all --query 'data[].id' 2>/dev/null | jq -r '.[]?'); do
  C=$(oci logging log list --log-group-id "$LG" --all 2>/dev/null \
      | jq '[.data[]? | select(.configuration.source.service=="flowlogs")] | length')
  N_FLOW=$((N_FLOW + ${C:-0}))
done
if [ "$N_FLOW" -gt 0 ]; then cumple L-02 "$N_FLOW flow log(s) activos"
else hallazgo MEDIO L-02 "Sin flow logs: si algo pasa en la red, no hay registro de quién habló con quién"; fi

# --- Chequeos de nivel tenancy -------------------------------------------------
if [ -n "$TENANCY" ]; then
  paso "Cloud Guard"
  CG=$(oci cloud-guard configuration get --compartment-id "$TENANCY" \
        --query 'data.status' --raw-output 2>/dev/null || echo "DESCONOCIDO")
  if [ "$CG" = "ENABLED" ]; then cumple P-01 "Cloud Guard habilitado"
  else hallazgo ALTO P-01 "Cloud Guard no está habilitado (estado: $CG)"; fi

  paso "Retención de Audit"
  RET=$(oci audit config get --compartment-id "$TENANCY" \
         --query 'data."retention-period-days"' --raw-output 2>/dev/null || echo "?")
  if [ "$RET" = "365" ]; then cumple L-01 "Audit retiene 365 días"
  else hallazgo MEDIO L-01 "Audit retiene $RET días (recomendado: 365)"; fi

  paso "Usuarios sin MFA y llaves API antiguas"
  USUARIOS=$(oci iam user list --compartment-id "$TENANCY" --all 2>/dev/null || echo '{"data":[]}')
  SIN_MFA=$(echo "$USUARIOS" | jq -r '.data[]? | select(."lifecycle-state"=="ACTIVE" and ."is-mfa-activated"==false) | .name')
  if [ -n "$SIN_MFA" ]; then
    while read -r u; do hallazgo ALTO I-01 "Usuario '$u' sin MFA"; done <<< "$SIN_MFA"
  else
    cumple I-01 "Todos los usuarios activos tienen MFA (o se gestionan en un dominio de identidad)"
  fi

  LIMITE=$(date -u -d '90 days ago' +%s 2>/dev/null || date -u -v-90d +%s)
  for row in $(echo "$USUARIOS" | jq -r '.data[]? | select(."lifecycle-state"=="ACTIVE") | @base64'); do
    UID_=$(printf '%s' "$row" | tr -d '\015' | base64 -d | jq -r .id); UN=$(printf '%s' "$row" | tr -d '\015' | base64 -d | jq -r .name)
    oci iam user api-key list --user-id "$UID_" 2>/dev/null \
      | jq -r '.data[]? | ."time-created"' | while read -r t; do
          TS=$(date -u -d "${t%%.*}" +%s 2>/dev/null || echo "$LIMITE")
          [ "$TS" -lt "$LIMITE" ] && echo "MEDIO|I-05|Usuario '$UN' tiene una llave API de más de 90 días"
        done
  done > /tmp/odt_keys.$$ || true
  while IFS='|' read -r sev ctl txt; do [ -n "$sev" ] && hallazgo "$sev" "$ctl" "$txt"; done < /tmp/odt_keys.$$
  rm -f /tmp/odt_keys.$$
fi

# --- Reporte -------------------------------------------------------------------
{
  echo
  echo "=================================================================="
  echo " AUDITORÍA RÁPIDA DE POSTURA — $(date '+%Y-%m-%d %H:%M')"
  echo " Compartment: $COMP"
  echo "=================================================================="
  printf '%-5s  %-5s  %s\n' "SEV" "CTRL" "HALLAZGO"
  printf '%-5s  %-5s  %s\n' "-----" "-----" "----------------------------------------------"
  printf '%s\n' "${HALLAZGOS[@]}" | LC_ALL=C sort   # ALTO, luego MEDIO, luego ok
  echo
  echo " Resumen: ${ALTOS} alto(s) · ${MEDIOS} medio(s) · ${OKS} control(es) que cumplen"
  echo
  echo " CTRL = ID del control en el checklist (Checklist_Seguridad.xlsx)."
  echo " Este script es una muestra, no una auditoría completa: para postura continua"
  echo " se usa Cloud Guard, y para cumplimiento, el CIS OCI Foundations Benchmark."
  echo "=================================================================="
} | tee "$SALIDA"

echo "Guardado en: $SALIDA"
