#!/usr/bin/env bash
# Demo del borde: mismo ataque, dos balanceadores.
#
#   ./20-prueba-waf.sh <ip-lb-taller3-sin-waf> <ip-lb-taller4-con-waf>
#
# Cuatro solicitudes contra cada uno: una normal, un XSS, una inyección SQL y un
# intento de ruta administrativa. Se muestra solo el código HTTP, en columnas, para
# que la sala lo lea de un vistazo.
#
# Mensaje para la sala: el WAF no reemplaza el código seguro. Compra tiempo y reduce
# ruido. Lo que ven aquí son payloads de libro de texto: un atacante real es más sutil.

set -uo pipefail

SIN="${1:-}"; CON="${2:-}"
if [ -z "$SIN" ] || [ -z "$CON" ]; then
  echo "Uso: $0 <ip-lb-sin-waf> <ip-lb-con-waf>"
  echo "  módulo 1:  cd ../../01-elasticidad/terraform/elasticidad && terraform output -raw lb_ip"
  echo "  módulo 2:  cd ../terraform/seguro && terraform output -raw lb_ip"
  exit 1
fi

codigo() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null || echo "---"; }

# Payloads codificados para que viajen en la URL tal cual.
XSS='%3Cscript%3Ealert(document.cookie)%3C%2Fscript%3E'
SQLI='1%27%20OR%20%271%27%3D%271%27%20--%20'

printf '\n%-34s %-16s %-16s\n' "Solicitud" "Sin WAF (T3)" "Con WAF (T4)"
printf '%-34s %-16s %-16s\n'   "----------------------------------" "------------" "------------"

fila() {
  local etiqueta="$1" ruta="$2"
  local a b
  a=$(codigo "http://${SIN}${ruta}")
  b=$(codigo "http://${CON}${ruta}")
  printf '%-34s %-16s %-16s\n' "$etiqueta" "$a" "$b"
}

fila "Normal         GET /"               "/"
fila "XSS            GET /?q=<script>"    "/?q=${XSS}"
fila "SQL injection  GET /?id=1' OR '1'=" "/?id=${SQLI}"
fila "Ruta admin     GET /admin"          "/admin"

echo
echo "Esperado: la columna sin WAF responde 200 a todo (la app no distingue);"
echo "          la columna con WAF responde 200 solo a la solicitud normal y 403 al resto."
echo
echo "Si la columna con WAF muestra 200 en el XSS: revisar las llaves de capacidad en"
echo "terraform.tfvars (waf_capacidades) — ver docs/02-MANUAL-PASO-A-PASO.md, paso 3.3."
