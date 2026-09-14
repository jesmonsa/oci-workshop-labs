#!/usr/bin/env bash
# Prueba de extremo a extremo del ciclo de la alarma: suena, llega el correo, el
# pool crece, se corta la carga y la alarma se cierra.
#
#   ./10-probar-alarma.sh <compartment-taller07> <ip-lb-taller3> [segundos-con-alarma] [nombre-alarma]
#
#   segundos-con-alarma  cuánto se mantiene la carga DESPUÉS de que suene (300 por
#                        defecto). Sirve para ver crecer el pool con la alarma sonando.
#
# Para qué sirve: MEDIR los tiempos reales del ciclo, que es lo que permite narrarlo
# en el guion. No se puede narrar en vivo algo cuyo tiempo no se conoce.
#
# Lo que pasa, MEDIDO el la fecha (no lo que uno esperaría):
#   1. la alarma pasa a DISPARADA            ~195 s desde que arranca la carga
#   2. llega el correo, con el runbook
#   3. el autoescalamiento agrega instancias
#   4. la alarma SIGUE sonando mientras haya carga. Se dejó 35 min con el pool en su
#      máximo de 6 y no se cerró. El generador manda la siguiente petición en cuanto
#      recibe la anterior: más capacidad no baja la utilización, sube el rendimiento.
#   5. se corta la carga y la alarma se cierra ~115 s después.
#
# Antes este script esperaba a que la alarma se cerrara CON la carga puesta para
# cortarla. Como eso no ocurre, no terminaba nunca. Ahora corta la carga él mismo.
#
# Si está exportada $POOL (docs/entorno-del-dia.sh), muestra también el tamaño del pool.

set -uo pipefail

COMP="${1:-}"
LB_IP="${2:-}"
MANTENER="${3:-300}"
ALARMA="${4:-lab05-saturacion-cpu}"
MS_CARGA=400
TOPE_CIERRE=600      # si tras cortar la carga no cierra en 10 min, algo más pasa

if [ -z "$COMP" ] || [ -z "$LB_IP" ]; then
  echo "Uso: $0 <compartment-ocid-taller07> <ip-lb-taller3> [segundos-con-alarma] [nombre-alarma]"
  echo
  echo "Con el entorno del día cargado:  $0 \$T07 \$LB_INSEGURO"
  exit 1
fi
command -v jq >/dev/null || { echo "Falta jq. Carga el entorno:  source <repo>/docs/entorno-del-dia.sh"; exit 1; }

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARGA="${AQUI}/../../01-elasticidad/scripts/10-carga.sh"
BITACORA="${AQUI}/../evidencias/tiempos-alarma.md"
mkdir -p "$(dirname "$BITACORA")"

# Se cruza con jq y NO con --query: un filtro con campo entrecomillado revienta en
# el CLI y el error se pierde en /dev/null. El efecto sería que este script informe
# que la alarma nunca dispara, justo mientras está disparada en la pantalla de al lado.
estado_alarma() {
  oci monitoring alarm-status list-alarms-status --compartment-id "$COMP" --all 2>/dev/null \
    | jq -r --arg n "$ALARMA" '[.data[] | select(."display-name"==$n) | .status][0] // "?"' \
    | tr -d '\015'
}

tamano_pool() {
  [ -z "${POOL:-}" ] && { echo "-"; return; }
  oci compute-management instance-pool get --instance-pool-id "$POOL" 2>/dev/null \
    | jq -r '.data.size // "?"' | tr -d '\015'
}

# En Git Bash para Windows NO existen pkill ni pgrep (dan 127). Con `|| echo 0` el
# error se esconde y el conteo dice siempre 0: "carga detenida" mientras sigue.
# Encontrado probando el la fecha. Se usa tasklist/taskkill si están.
cargas_vivas() {
  if command -v tasklist >/dev/null 2>&1; then
    tasklist //FI "IMAGENAME eq curl.exe" //NH 2>/dev/null | grep -ci "curl.exe"
  else
    pgrep -fc "burn\?ms=${MS_CARGA}" 2>/dev/null | head -1
  fi
}

echo "Estado inicial de '${ALARMA}': $(estado_alarma)   ·   pool: $(tamano_pool)"
echo

if [ ! -x "$CARGA" ]; then
  echo "No encuentro el generador de carga del módulo 1 en:"
  echo "  $CARGA"
  exit 1
fi

INICIO=$(date +%s)
echo "Arrancando carga contra ${LB_IP} a las $(date '+%H:%M:%S')..."
"$CARGA" "$LB_IP" 40 "$MS_CARGA" >/dev/null 2>&1 &
PID_CARGA=$!
CARGA_CORTADA="no"

# Cortar la carga de verdad. Mandarle TERM al generador no basta: su trampa solo se
# atiende cuando termina el `sleep 60` de su latido, y durante ese minuto la carga
# sigue. Eso falsearía justo lo que se mide aquí —cuánto tarda en cerrar tras el
# corte—. Se matan los subprocesos y las peticiones directamente.
cortar_carga() {
  [ "$CARGA_CORTADA" = "si" ] && return
  local _
  for _ in 1 2 3; do
    if command -v taskkill >/dev/null 2>&1; then
      # Windows: los subprocesos del generador son copias de 10-carga.sh; se matan
      # primero para que no vuelvan a lanzar curl, y luego las peticiones en curso.
      # taskkill mata TODOS los curl.exe del equipo: durante la demo no hay otros.
      ps -ef 2>/dev/null | awk '/[1]0-carga\.sh/ {print $2}' | xargs -r kill -9 2>/dev/null
      taskkill //IM curl.exe //F >/dev/null 2>&1
    else
      pkill -P "$PID_CARGA" 2>/dev/null; kill "$PID_CARGA" 2>/dev/null
      pkill -f "burn\?ms=${MS_CARGA}" 2>/dev/null
    fi
    sleep 1
  done
  CARGA_CORTADA="si"
  local vivas; vivas=$(cargas_vivas)
  if [ "${vivas:-0}" -gt 0 ]; then
    echo "  AVISO: quedan ${vivas} peticiones vivas. Revisar con:  tasklist //FI \"IMAGENAME eq curl.exe\""
  fi
}

salir() {
  echo
  if [ "$CARGA_CORTADA" = "no" ]; then
    echo "Deteniendo carga..."
    cortar_carga
  fi
  echo "Carga detenida. Salgo."
  exit 0
}
trap salir INT TERM

DISPARO=""
CORTE=""
CIERRE=""
POOL_AL_CORTE="-"
echo "Vigilando cada 20 s (los tiempos se miden con esa resolución). Ctrl-C para salir."
echo

while true; do
  sleep 20
  AHORA=$(date +%s)
  T=$(( AHORA - INICIO ))
  ESTADO=$(estado_alarma)
  TAM=$(tamano_pool)
  printf '  %s  t+%-5s  alarma: %-7s  pool: %s\n' "$(date '+%H:%M:%S')" "${T}s" "$ESTADO" "$TAM"

  # 1 · Suena
  if [ "$ESTADO" = "FIRING" ] && [ -z "$DISPARO" ]; then
    DISPARO=$T
    echo
    echo "  >>> DISPARÓ a los ${DISPARO}s desde el inicio de la carga."
    echo "  >>> Revisa el correo ahora: debe traer el enlace al runbook."
    echo
    echo "  La carga sigue ${MANTENER}s más. Vas a ver crecer el pool y la alarma"
    echo "  SEGUIR sonando: más capacidad no baja la utilización, sube el rendimiento."
    echo
  fi

  # 2 · Se corta la carga
  if [ -n "$DISPARO" ] && [ -z "$CORTE" ] && [ "$T" -ge $(( DISPARO + MANTENER )) ]; then
    POOL_AL_CORTE="$TAM"
    cortar_carga
    CORTE=$(( $(date +%s) - INICIO ))
    echo
    echo "  >>> CARGA CORTADA a los ${CORTE}s, con el pool en ${POOL_AL_CORTE} y la alarma en ${ESTADO}."
    echo "  >>> Ahora sí debería cerrarse: medido, unos 2 minutos después del corte."
    echo
  fi

  # 3 · Se cierra
  if [ -n "$CORTE" ] && [ "$ESTADO" = "OK" ] && [ -z "$CIERRE" ]; then
    CIERRE=$T
    echo
    echo "  >>> SE CERRÓ a los ${CIERRE}s: $(( CIERRE - CORTE ))s después de cortar la carga."
    {
      echo "## Medición $(date '+%Y-%m-%d %H:%M')"
      echo
      echo "| Evento | Segundos desde el inicio de la carga |"
      echo "|---|---|"
      echo "| La alarma dispara | ${DISPARO} |"
      echo "| Se corta la carga (pool en ${POOL_AL_CORTE}, alarma aún sonando) | ${CORTE} |"
      echo "| La alarma se cierra | ${CIERRE} |"
      echo "| **Cierre tras cortar la carga** | **$(( CIERRE - CORTE ))** |"
      echo
      echo "Resolución de 20 s. La alarma NO se cerró mientras hubo carga: se cerró al bajar la demanda."
      echo
    } >> "$BITACORA"
    echo "  Anotado en $BITACORA"
    exit 0
  fi

  # Red de seguridad: si tras cortar no cierra, no quedarse esperando para siempre.
  if [ -n "$CORTE" ] && [ -z "$CIERRE" ] && [ $(( T - CORTE )) -ge "$TOPE_CIERRE" ]; then
    echo
    echo "  >>> La alarma sigue en ${ESTADO} ${TOPE_CIERRE}s después de cortar la carga."
    echo "      Revisar si quedaron peticiones vivas (tasklist //FI \"IMAGENAME eq curl.exe\") o si hay otra carga."
    exit 1
  fi
done
