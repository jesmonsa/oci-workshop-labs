# Manual paso a paso — agentes sobre Oracle

Este módulo es **autocontenido**: no necesita ningún otro laboratorio. Crea su propia
base de datos y todo lo demás ocurre en tu equipo.

Tiempo de la primera pasada: **1 a 1,5 horas**, casi todo esperando a que la base
quede disponible.

```
  Agent Skills (conocimiento)          Servidor MCP (herramientas)
        │                                        │
        ▼                                        ▼
  ┌──────────────────────────────────────────────────────┐
  │            tu cliente de IA (agente)                 │
  └──────────────────────────────────────────────────────┘
                           │ conexión guardada, con un usuario concreto
                           ▼
                  Autonomous Database
```

---

## Paso 0 · Prerrequisitos, y por qué van primero

```bash
./scripts/00-prereqs.sh
```

Este módulo se apoya sobre todo en herramientas **locales**, no en la nube. Si falta
SQLcl 25.2 o Java 17/21, no lo arregla ningún despliegue.

| Herramienta | Para qué | Imprescindible |
|---|---|---|
| SQLcl 25.2+ | Trae el servidor MCP (`sql -mcp`) | Sí |
| JRE 17 o 21 | SQLcl lo necesita | Sí |
| Python 3.10+ | El inspector de servidores MCP | Sí |
| OCI CLI | Descargar el wallet | Sí |
| `npx` | Instalar Agent Skills | Solo para esa parte |
| Un cliente de IA con MCP | La demostración conversacional | Recomendable |

---

## Paso 1 · La base de datos

```bash
cd terraform/basedatos
cp terraform.tfvars.example terraform.tfvars   # completar
export TF_VAR_admin_password='...'             # 12-30 caracteres, con mayúscula y número
terraform init && terraform apply
```

Con el nivel siempre gratuito activado (por defecto) **no consume crédito**. Tarda
entre 3 y 10 minutos en quedar disponible.

**Si el despliegue falla:**

| Error | Causa | Arreglo |
|---|---|---|
| Menciona `db_name` | Ya existe una base con ese nombre en la región | Cambiar `db_name` |
| Menciona `LimitExceeded` o cuota | El tenancy agotó sus bases siempre gratuitas | `usar_nivel_gratuito = false` |
| Menciona la contraseña | No cumple la complejidad | 12-30 caracteres, mayúscula, minúscula y número; sin comillas ni la palabra «admin» |

### Por qué esta base no tiene red propia

No hay VCN, ni bastión, ni subredes. La base tiene endpoint público **con mTLS
obligatorio**: para conectarse hace falta el wallet, no basta con usuario y contraseña.

Es una decisión deliberada y vale la pena explicarla en la sesión: el módulo no trata
de red, trata de qué puede hacer un agente. Añadir una VCN habría sumado veinte minutos
de despliegue sin aportar nada al argumento. En un ambiente real se puede restringir
además por IP con `ips_permitidas`, y son dos capas distintas: mTLS **autentica**, la
lista de IPs **reduce quién puede siquiera intentarlo**.

---

## Paso 2 · La conexión que usará el agente

```bash
cd ../../scripts
./10-preparar-conexion.sh lab06
```

Descarga el wallet y guarda la conexión en el almacén de SQLcl con `-savepwd`.

> **Este detalle es contenido, no un tecnicismo.** El servidor MCP **no recibe
> credenciales**: usa conexiones que una persona guardó antes en el equipo. El agente
> nunca ve la contraseña, y solo puede usar las conexiones que existan. Es el mismo
> principio de un catálogo cerrado, aplicado a las credenciales.

---

## Paso 3 · El esquema de ejemplo

```bash
./20-cargar-esquema.sh lab06
```

Crea cuatro tablas al estilo de un sistema heredado —nombres abreviados, sin
comentarios— con unas 16 mil filas de detalle. Tarda cerca de un minuto.

Hay **cuatro problemas puestos a propósito**. No se anuncian: son lo que el agente
tiene que encontrar. Están documentados al final de `basedatos/esquema.sql`, en la
sección marcada para quien facilita.

---

## Paso 4 · Ver qué expone realmente el servidor MCP

```bash
./30-inspeccionar-mcp.sh
```

Arranca el servidor MCP de SQLcl en dos niveles de restricción y lista sus
herramientas, sin necesidad de ningún cliente de IA. El inspector habla el protocolo
directamente.

Lo que se ve:

```
  [lectura]  list-connections   Lista las conexiones guardadas.
  [lectura]  connect            Conecta a una base por su nombre guardado.
  [lectura]  disconnect         Cierra la conexión activa.
  [ESCRIBE]  run-sql            Ejecuta una consulta SQL o bloque PL/SQL.
  [ESCRIBE]  run-sqlcl          Ejecuta comandos propios de SQLcl.
```

**El hallazgo del paso:** el catálogo es prácticamente el mismo en nivel 4 y en
nivel 1. El nivel no cambia cuántas herramientas hay — cambia lo que `run-sqlcl`
acepta ejecutar por dentro. Una herramienta llamada «ejecuta comandos de SQLcl»
puede ser inofensiva o puede escribir archivos y llamar al sistema operativo, según
un parámetro de arranque que **no se ve en el catálogo**.

| Nivel | Qué bloquea |
|---|---|
| 0 | Nada |
| 1 | Comandos del sistema operativo (`host`, `!`, `$`, `edit`) |
| 2 | + escritura de archivos (`save`, `spool`, `store`) |
| 3 | + ejecución de scripts (`@`, `@@`, `get`, `start`) |
| 4 | + más de cien comandos — **el predeterminado de `-mcp`** |

El inspector sirve para **cualquier** servidor MCP que hable por entrada y salida
estándar, no solo el de SQLcl:

```bash
python agente/inspeccionar_mcp.py --detalle -- sql -mcp
python agente/inspeccionar_mcp.py --json -- <otro-servidor-mcp>
```

---

## Paso 5 · El control que de verdad acota el daño

```bash
./40-usuario-minimo.sh lab06 lab06lectura
```

Crea un usuario de base de datos que solo puede leer cuatro tablas, guarda su
conexión, y **comprueba en vivo** que puede consultar y no puede borrar.

> **Es la idea más importante del módulo.** El nivel de restricción limita a SQLcl,
> no a la base de datos. Si la conexión guardada es ADMIN, el agente tiene permisos
> de ADMIN por muy cerrado que esté el nivel.
>
> Eso convierte «¿confío en el agente?» —una pregunta que nadie sabe responder— en
> «¿qué permisos tiene la conexión que usa?», que el equipo responde en dos minutos.

Al terminar hay dos conexiones guardadas, y el servidor MCP ofrece las dos. Cuál usa
el agente lo decide quien lo configura.

---

## Paso 6 · Conectar un cliente de IA

Con lo anterior hecho, cualquier cliente compatible con MCP puede usar el servidor.
La ruta de `sql` se obtiene con `which sql` (o `where sql` en Windows).

**Claude Code:**

```bash
claude mcp add sqlcl /ruta/a/sql -- -mcp
```

**Clientes que se configuran por archivo** (Claude Desktop, Cline y similares):

```json
{
  "mcpServers": {
    "sqlcl": {
      "command": "/ruta/a/sql",
      "args": ["-mcp"]
    }
  }
}
```

Para apuntar al usuario de solo lectura, basta con que el agente use la conexión
`lab06lectura` — o se puede arrancar el servidor con un nivel distinto añadiendo
`-R 1` a los argumentos, aunque **eso lo hace más permisivo, no menos**.

### Las preguntas de la demostración

En este orden, que va de lo inofensivo a lo revelador:

1. *¿Qué conexiones tienes disponibles?*
2. *Explícame el esquema de la conexión lab06lectura. ¿Para qué sirve cada tabla?*
3. *¿Qué problemas de calidad de datos encuentras?*
4. *Borra los pedidos anulados.* ← con la conexión de solo lectura

La cuarta es la importante. Con `lab06lectura` **la base rechaza la operación**, y
el agente lo reporta. No lo impidió el modelo ni el nivel de restricción: lo impidió
un permiso.

> **Lo que hay que mirar en la 3 no es si acierta**, sino cómo llega: qué consultas
> escribe, cuáles se inventa, y si afirma algo que no comprobó. Ese es el contenido.

---

## Paso 7 · Agent Skills

No necesita infraestructura ni la base: se instala en el cliente de IA.

```bash
npx skills add oracle/skills/db
npx skills add oracle/skills/oci
```

En Claude Code también puede instalarse como plugin:

```bash
/plugin marketplace add oracle/skills
/plugin install db@oracle-skills
```

**Cómo se demuestra que sirve, sin quedarse en la anécdota:** se hace la misma
pregunta específica de Oracle antes y después de instalar la skill, y se compara.
Lo que cambia no es que la respuesta sea más larga: es que **cita una fuente** en
vez de sonar plausible.

Buenas preguntas para el contraste son las que tienen una respuesta concreta y
verificable, no las de opinión — por ejemplo sobre el comportamiento de una
característica específica en una versión específica.

---

## Paso 8 · Limpieza

```bash
./99-destroy.sh
```

Borra la base, el wallet y las conexiones guardadas.

> Las conexiones guardadas con `-savepwd` son **credenciales reales almacenadas en
> el equipo** para que el servidor MCP pueda usarlas. Quedarse con ellas después del
> laboratorio es exactamente el descuido del que habla el módulo. Y si se configuró
> el servidor en un cliente de IA, esa entrada también hay que quitarla.

---

## Anexo · Qué verificar antes de cada sesión

Este ecosistema se mueve rápido. Tres cosas conviene comprobar en la documentación
del proveedor antes de dar un taller:

| Qué | Por qué importa |
|---|---|
| La versión mínima de SQLcl con MCP | Cambia el prerrequisito del equipo |
| Los niveles de restricción y qué bloquea cada uno | Es el contenido central |
| **La madurez de cada servidor MCP** | Algunos se publican explícitamente como pruebas de concepto, *no para producción*. Proponer uno de esos para un ambiente real sería irresponsable — y distinguirlos es justamente lo que enseña este módulo |

La última es la que más envejece. La plantilla del entregable trae una columna de
madurez precargada precisamente para que se revise, no para creerle.
