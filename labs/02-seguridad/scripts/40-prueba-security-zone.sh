#!/usr/bin/env bash
# Demo de prevención: Security Zone rechaza lo que viola la política.
#
#   ./40-prueba-security-zone.sh <compartment-ocid-de-la-zona>
#
# Crea un bucket PRIVADO (debe funcionar) y luego intenta uno PÚBLICO (debe fallar
# con un error que cita la política de la zona). Al final borra el privado.
#
# Mensaje: detectar te avisa a las 3 a.m.; prevenir no te despierta.
# Prerrequisito: la zona configurada según docs/02-MANUAL-PASO-A-PASO.md, paso 5.

set -uo pipefail

ZONA="${1:-}"
if [ -z "$ZONA" ]; then
  echo "Uso: $0 <compartment-ocid-de-la-zona>"
  echo
  echo "Si escribiste una variable como \$T04ZONA y llegó vacía, es que falta cargar"
  echo "el entorno del día en ESTA terminal:"
  echo "    source ../../../docs/entorno-del-dia.sh"
  exit 1
fi

SUFIJO=$(date +%H%M%S)

echo
echo "1) Bucket privado en la zona segura..."
if oci os bucket create --compartment-id "$ZONA" --name "lab02-privado-$SUFIJO" \
     --public-access-type NoPublicAccess >/dev/null 2>&1; then
  echo "   CREADO. Lo que cumple la política pasa sin fricción."
else
  echo "   Falló también el privado: la receta de la zona es más estricta de lo esperado"
  echo "   (por ejemplo, exige llave de Vault). Ver paso 5 del manual."
fi

echo
echo "2) Bucket PÚBLICO en la misma zona..."
ERR=$(oci os bucket create --compartment-id "$ZONA" --name "lab02-publico-$SUFIJO" \
        --public-access-type ObjectRead 2>&1 >/dev/null)
if [ $? -ne 0 ]; then
  echo "   RECHAZADO por la plataforma:"
  echo "$ERR" | grep -oiE '"message": *"[^"]+"' | head -1 | sed 's/^/     /'
else
  echo "   SE CREÓ — la zona no tiene la política 'deny public buckets'. Borrándolo..."
  oci os bucket delete --bucket-name "lab02-publico-$SUFIJO" --force >/dev/null 2>&1
fi

echo
echo "3) Limpieza..."
oci os bucket delete --bucket-name "lab02-privado-$SUFIJO" --force >/dev/null 2>&1 \
  && echo "   Bucket privado borrado."
