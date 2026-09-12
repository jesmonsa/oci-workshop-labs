#!/usr/bin/env bash
# Verificación de prerrequisitos del módulo 6 — correr ANTES de desplegar nada.
#
# No crea nada. Responde una sola pregunta: ¿este equipo puede correr el laboratorio?
#
# Este módulo es distinto de los demás: casi todo pasa en tu equipo, no en la nube.
# El servidor MCP de SQLcl es un proceso local, y las Agent Skills se instalan en
# tu cliente de IA. Si algo falta aquí, no lo arregla ningún despliegue.

set -uo pipefail

ok()    { printf '  [ OK ]  %s\n' "$1"; }
falta() { printf '  [FALTA] %s\n' "$1"; FALLOS=$((FALLOS+1)); }
aviso() { printf '  [ !  ]  %s\n' "$1"; }
titulo(){ printf '\n== %s ==\n' "$1"; }

FALLOS=0

titulo "SQLcl — el que trae el servidor MCP"
if command -v sql >/dev/null 2>&1; then
  VER=$(sql -V 2>/dev/null | head -1)
  ok "sql encontrado: $VER"
  # El servidor MCP existe desde SQLcl 25.2. En versiones anteriores, -mcp no existe.
  NUM=$(printf '%s' "$VER" | grep -oE '[0-9]+\.[0-9]+' | head -1)
  MAY=${NUM%%.*}; MEN=${NUM##*.}
  if [ -n "$MAY" ] && { [ "$MAY" -gt 25 ] || { [ "$MAY" -eq 25 ] && [ "$MEN" -ge 2 ]; }; }; then
    ok "Versión suficiente para MCP (hace falta 25.2 o posterior)"
  else
    falta "SQLcl $NUM no trae servidor MCP. Hace falta 25.2 o posterior."
  fi
else
  falta "sql (SQLcl) no está en el PATH — https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/"
fi

titulo "Java — SQLcl lo necesita"
if command -v java >/dev/null 2>&1; then
  JV=$(java -version 2>&1 | head -1)
  ok "$JV"
  JNUM=$(printf '%s' "$JV" | grep -oE '"[0-9]+' | tr -d '"')
  if [ -n "$JNUM" ] && { [ "$JNUM" = "17" ] || [ "$JNUM" = "21" ]; }; then
    ok "Versión compatible (17 o 21)"
  else
    aviso "SQLcl pide JRE 17 o 21; aquí hay $JNUM. Puede funcionar, pero no está soportado."
  fi
else
  falta "java no está en el PATH"
fi

titulo "Python — para el inspector de servidores MCP"
if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
  PY=$(command -v python3 || command -v python)
  ok "$("$PY" --version 2>&1)"
else
  falta "python no está en el PATH (hace falta 3.10 o posterior)"
fi

titulo "Node — para instalar Agent Skills"
if command -v npx >/dev/null 2>&1; then
  ok "npx $(npx --version 2>/dev/null)"
else
  aviso "npx no está. Solo hace falta para 'npx skills add'; el resto del módulo funciona sin él."
fi

titulo "OCI CLI — para descargar el wallet"
if command -v oci >/dev/null 2>&1; then
  ok "$(oci --version 2>/dev/null)"
  if oci iam region list >/dev/null 2>&1; then
    ok "Credenciales configuradas"
  else
    falta "OCI CLI instalado pero sin credenciales válidas — correr 'oci setup config'"
  fi
else
  falta "oci no está en el PATH"
fi

titulo "Cliente de IA con soporte MCP"
ENCONTRADO=0
for c in claude code cursor; do
  command -v "$c" >/dev/null 2>&1 && { ok "$c encontrado"; ENCONTRADO=1; }
done
[ "$ENCONTRADO" -eq 0 ] && aviso "No se detectó ninguno en el PATH. Puede ser una aplicación de escritorio, que no aparece aquí: se configura por archivo (ver el manual)."

titulo "Resultado"
if [ "$FALLOS" -eq 0 ]; then
  echo "  Sin bloqueantes. Se puede continuar con terraform/basedatos."
else
  echo "  $FALLOS bloqueante(s). Resolverlos antes de desplegar: este módulo se apoya"
  echo "  sobre todo en herramientas locales, y ningún despliegue las sustituye."
fi
exit 0
