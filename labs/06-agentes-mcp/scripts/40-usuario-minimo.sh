#!/usr/bin/env bash
# Crea un usuario de base de datos de SOLO LECTURA y guarda su conexión, para que
# el agente no trabaje como ADMIN.
#
#   ./40-usuario-minimo.sh [conexion-admin] [conexion-nueva]
#
# Por qué existe este script:
#
# El nivel de restricción del servidor MCP limita a SQLcl, no a la base de datos.
# Si la conexión guardada es ADMIN, el agente puede hacer todo lo que puede hacer
# ADMIN — por muy cerrado que esté el nivel. El control que de verdad acota el
# daño es el de siempre: un usuario con los permisos mínimos.
#
# Esto convierte la conversación de «¿confío en el agente?» en «¿qué permisos
# tiene la conexión que usa?», que es una pregunta que el equipo ya sabe responder.

set -uo pipefail

ADMIN_CONN="${1:-lab06}"
NUEVA_CONN="${2:-lab06lectura}"
USUARIO="AGENTE_RO"

command -v sql >/dev/null || { echo "Falta SQLcl."; exit 1; }

if [ -z "${AGENTE_PASSWORD:-}" ]; then
  read -r -s -p "Contraseña para el usuario ${USUARIO} (12-30 caracteres): " AGENTE_PASSWORD
  echo
fi
if [ "${#AGENTE_PASSWORD}" -lt 12 ]; then
  echo "La contraseña debe tener al menos 12 caracteres."
  exit 1
fi

echo "Creando ${USUARIO} con permisos de solo lectura..."

sql -S "${ADMIN_CONN}" <<EOF
set feedback off
declare
  v_existe number;
begin
  select count(*) into v_existe from all_users where username = '${USUARIO}';
  if v_existe > 0 then
    execute immediate 'drop user ${USUARIO} cascade';
  end if;
end;
/

create user ${USUARIO} identified by "${AGENTE_PASSWORD}";

-- Lo mínimo para conectarse y leer el diccionario de datos. Nada más.
grant create session to ${USUARIO};
grant select_catalog_role to ${USUARIO};

-- Lectura sobre las cuatro tablas del laboratorio, una por una.
-- Deliberadamente NO se concede 'select any table': lo que se busca es el
-- alcance más pequeño que permita el trabajo, no el más cómodo de escribir.
grant select on ADMIN.CLI_MST to ${USUARIO};
grant select on ADMIN.PRD_CAT to ${USUARIO};
grant select on ADMIN.PED_HDR to ${USUARIO};
grant select on ADMIN.PED_DET to ${USUARIO};

-- Sinónimos para que las consultas del agente no tengan que llevar prefijo.
create or replace synonym ${USUARIO}.CLI_MST for ADMIN.CLI_MST;
create or replace synonym ${USUARIO}.PRD_CAT for ADMIN.PRD_CAT;
create or replace synonym ${USUARIO}.PED_HDR for ADMIN.PED_HDR;
create or replace synonym ${USUARIO}.PED_DET for ADMIN.PED_DET;

prompt Usuario creado.
exit
EOF

DBNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform/basedatos" && terraform output -raw db_name 2>/dev/null || echo "")
SERVICIO="${DBNAME}_low"

echo
echo "Guardando la conexión «${NUEVA_CONN}»..."
sql /nolog <<EOF
connect -save ${NUEVA_CONN} -savepwd ${USUARIO}/"${AGENTE_PASSWORD}"@${SERVICIO}
exit
EOF

echo
echo "Comprobando qué puede y qué no puede hacer ${USUARIO}:"
echo

sql -S "${NUEVA_CONN}" <<'EOF'
set feedback off
set pagesize 30
prompt -- Leer: debe funcionar
select count(*) as pedidos_visibles from PED_HDR;

prompt
prompt -- Escribir: debe fallar
begin
  execute immediate 'delete from PED_HDR where rownum = 1';
  dbms_output.put_line('PROBLEMA: el borrado funcionó. Revisar los permisos.');
exception
  when others then
    dbms_output.put_line('Correcto: el borrado fue rechazado -> ' || sqlerrm);
end;
/
rollback;
exit
EOF

cat <<TEXTO

----------------------------------------------------------------------
 Ahora hay dos conexiones guardadas, y esa es la demostración:

   ${ADMIN_CONN}         ADMIN        puede todo
   ${NUEVA_CONN}   ${USUARIO}   solo puede leer cuatro tablas

 El servidor MCP ofrece las dos con «list-connections». Cuál usa el agente
 es una decisión de quien lo configura, no del modelo.

 Y conviene decirlo tal cual en la sesión: el nivel de restricción del
 servidor MCP no habría impedido nada de esto. El permiso sí.
----------------------------------------------------------------------
TEXTO
