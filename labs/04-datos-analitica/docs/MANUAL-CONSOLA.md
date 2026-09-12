---
titulo: Manual de consola — Datos y analítica operacional sobre MySQL HeatWave
subtitulo: Una base MySQL administrada sin endpoint público, alcanzada por bastión, con tres millones de documentos cargados desde Object Storage y un tablero construido sobre ellos
modulo: "06"
duracion: "2 a 3 horas la primera pasada, de las cuales cerca de la mitad son esperas"
costo: "unidades de USD por día de laboratorio encendido; el sistema de base de datos es el rubro dominante (proyección medida del conjunto de laboratorios: 2,10 USD contra un presupuesto de 150)"
---

## 1. Qué se construye y para qué

Este manual levanta, haciendo clic en la consola de OCI, un laboratorio de analítica
operacional: una base de datos MySQL administrada, sin dirección pública, dentro de
una subred privada, alcanzable únicamente a través de un bastión. Sobre esa base se
cargan tres millones de documentos electrónicos sintéticos y se ejecutan ocho
consultas cronometradas cuyos resultados alimentan un tablero HTML de un solo archivo.

La decisión que el laboratorio ayuda a tomar no es «qué herramienta de tableros
compramos». Es anterior y más incómoda: **¿la infraestructura de datos que ya
tenemos responde en un tiempo que sirva para decidir, y responde sin exponer la base
a internet?** El laboratorio produce dos evidencias concretas para esa conversación:

- El tiempo real de las consultas que importan. Sobre tres millones de filas y un
  shape pequeño, la consulta más pesada del conjunto tardó **5,62 segundos**. No es
  una estimación: está medida y se vuelve a medir en cada corrida.
- Lo que el promedio esconde. La tasa de rechazo agregada del período fue **5,04 %**,
  una cifra tranquila. Debajo de ella, un cliente concreto pasó de **6,2 % a 23,8 %**
  en siete días. Un tablero que solo muestre el agregado da tranquilidad y se
  equivoca.

Hay una segunda decisión, de costo, que el laboratorio obliga a tomar antes de
empezar: **si se crea o no el clúster acelerador de HeatWave**. Es un cargo aparte
del sistema de base de datos y se consume rápido. El manual documenta los dos
caminos y, cuando el acelerador no existe, el flujo de medición lo detecta solo y el
tablero lo declara en lugar de inventar una comparación.

### El diagrama

```text
                         Su equipo (terminal + navegador)
                                      │
                   sesión de reenvío de puerto (SSH, TCP 22)
                                      │
  ┌───────────────────────────────────┼──────────────────────────────────┐
  │ VCN  lab04-vcn   10.60.0.0/16     │                                  │
  │                                   ▼                                  │
  │   ┌──────────────────────────────────────────────────────────────┐   │
  │   │ Subred PRIVADA  lab04-subnet-privada-datos   10.60.1.0/24    │   │
  │   │ (prohibida la IP pública en las VNIC)                        │   │
  │   │                                                              │   │
  │   │   [ endpoint del bastión ]───► 3306 ───►[ DB System MySQL ]  │   │
  │   │        10.60.1.x                            10.60.1.y        │   │
  │   │                                             sin IP pública   │   │
  │   │                                                   │          │   │
  │   │                                          (opcional camino A) │   │
  │   │                                          [ clúster HeatWave ]│   │
  │   └──────────────────────────────────────────────────────────────┘   │
  │            │ tabla de rutas: Oracle Services Network                  │
  │            ▼                                                          │
  │   [ Service Gateway ]  ──── sin salir a internet ────►  Object Storage│
  └───────────────────────────────────────────────────────────────────────┘

   Flujo de los datos:
   generar CSV ─► bucket de Object Storage ─► util import-table ─► MySQL
                                                                    │
                              medir_consultas.py ◄──────────────────┘
                                        │
                                   resultados.json ─► tablero.py ─► HTML
```

### Qué NO tiene este laboratorio

No tiene Internet Gateway ni NAT Gateway. La subred no sale a internet: la única
salida es hacia servicios de OCI por el Service Gateway. No tiene alta
disponibilidad, no tiene respaldos automáticos y no tiene protección de borrado. Las
tres cosas están apagadas a propósito, porque es un ambiente efímero y el crédito es
finito. En cualquier ambiente con datos reales las tres van al revés, y esa
diferencia merece decirse en voz alta.

---

## 2. Equivalencias con otras nubes

Solo los servicios que aparecen en este manual.

| Concepto | AWS | Azure | OCI |
|---|---|---|---|
| Red virtual | VPC | Virtual Network (VNet) | Virtual Cloud Network (VCN) |
| Subred sin salida a internet | Subnet privada | Subnet sin NAT/IG | Subred con `Prohibit public IP` |
| Cortafuegos a nivel de subred | Network ACL | NSG asociado a subred | Security List |
| Salida privada a servicios del proveedor | VPC Endpoint (Gateway) | Private Endpoint / Service Endpoint | Service Gateway |
| Tabla de rutas | Route Table | Route Table | Route Table |
| Acceso administrado sin IP pública | Systems Manager Session Manager | Azure Bastion | OCI Bastion |
| MySQL administrado | RDS for MySQL / Aurora MySQL | Azure Database for MySQL | MySQL HeatWave (DB System) |
| Acelerador analítico en memoria sobre la misma base | Aurora + Redshift ZeroETL | (sin equivalente directo integrado) | Clúster HeatWave |
| Almacenamiento de objetos | S3 | Blob Storage | Object Storage |
| Agrupación lógica con control de acceso | (cuenta / OU / tags) | Resource Group | Compartment |
| Control de gasto con avisos | AWS Budgets | Cost Management Budgets | Budgets |

Dos diferencias que conviene tener presentes desde el principio, porque cambian el
orden de los pasos:

1. **El compartimento no es un grupo de recursos cosmético.** En OCI es la unidad
   sobre la que se escriben las políticas de acceso y sobre la que se filtra el
   costo. Casi todas las pantallas de creación preguntan primero por el
   compartimento, y si el selector está en el equivocado, el recurso no aparecerá
   después donde usted lo busca.
2. **El DB System de MySQL no admite Network Security Groups.** A diferencia de una
   instancia de cómputo, su control de acceso de red es la security list de la
   subred. Esto obliga a crear la security list **antes** que la subred, porque la
   subred la referencia.

---

## 3. Prerrequisitos

### 3.1 En la cuenta de OCI

| Requisito | Detalle |
|---|---|
| Tenancy con crédito disponible | Un trial sirve. Revise el saldo antes de empezar: el sistema de base de datos es el recurso más caro del laboratorio |
| Permisos | Capacidad de crear VCN, subredes, security lists, gateways, bastiones, DB Systems de MySQL y buckets en el compartimento del laboratorio. Con el rol de administrador del tenancy alcanza |
| Compartimento del laboratorio | Cree uno dedicado, por ejemplo `lab-04-datos`. No trabaje en el compartimento raíz |
| Límite de servicio de MySQL | Debe ser mayor que cero. Se verifica en el capítulo 4 |
| Presupuesto con avisos | Opcional pero muy recomendado. Ver 3.4 |

### 3.2 En su equipo

| Herramienta | Para qué | Verificación |
|---|---|---|
| Un par de llaves SSH | La sesión del bastión exige la llave pública | `ssh-keygen -t rsa -b 4096` si no tiene una |
| Cliente SSH | Sostener el túnel | `ssh -V` |
| MySQL Shell (`mysqlsh`) | Crear el esquema e importar el CSV. **No hay sustituto por consola**: OCI no ofrece un cliente SQL web para el DB System de MySQL | `mysqlsh --version` |
| Python 3.10 o superior | Generar los datos, medir las consultas y armar el tablero | `python --version` |
| OCI CLI | Solo para las verificaciones de shapes y límites del capítulo 4, y para algunas comprobaciones. Todo lo demás es consola | `oci --version` |

**Este laboratorio no se termina solo con clics.** Del capítulo 4 al 12 todo se hace
en la consola. Del 13 en adelante, no: la creación del esquema, la importación del
CSV y la medición de las consultas exigen una terminal con `mysqlsh` y Python, porque
OCI no expone un editor SQL para el DB System de MySQL. Es la parte donde está la
sustancia del laboratorio, y conviene saberlo antes de sentarse a hacerlo.

### 3.3 Los archivos del taller

Tenga a mano el directorio `talleres/04-datos-analitica/`. Del él se usan cuatro
cosas:

| Archivo | Para qué |
|---|---|
| `datos/generar_datos.py` | Produce el CSV sintético de tres millones de filas |
| `datos/esquema.sql` | Crea la base `operacion` y la tabla `documentos` con sus tres índices |
| `datos/medir_consultas.py` | Ejecuta y cronometra las ocho consultas, y escribe `resultados.json` |
| `datos/tablero.py` | Convierte `resultados.json` en un HTML autocontenido |

Los datos son **inventados**. No hay en ellos ni un registro de ninguna organización
real, y conviene decirlo en voz alta cuando el tablero se proyecte.

### 3.4 El presupuesto, antes que nada

> CONSOLA: Billing & Cost Management › Budgets › Create Budget

| Campo | Valor |
|---|---|
| Budget scope | El compartimento del laboratorio |
| Name | `lab-presupuesto` |
| Monthly budget amount | Un límite que le duela antes de que le duela la factura |
| Alert rule | Avisos por porcentaje del gasto real y por gasto proyectado |

Tenga claro qué hace y qué no hace un presupuesto: **un presupuesto en OCI no apaga
nada, notifica.** Es un límite informativo, y el aviso además llega con retraso: OCI
evalúa las reglas de alerta **cada 24 horas**. Sirve para enterarse de que algo quedó
encendido, no para impedir que quede encendido. La única medida que realmente controla
el gasto de este laboratorio es el capítulo de limpieza, y hay que ejecutarlo.

---

## 4. Verificación previa: qué shapes existen y qué límites tiene la región

Este capítulo no crea nada. Es el que evita perder dos horas.

Los nombres de los shapes de MySQL **cambian entre regiones y con el tiempo**, y la
disponibilidad de shapes con acelerador HeatWave cambia todavía más. Empezar a crear
el DB System sin haber mirado esto produce un error a mitad del formulario, o peor,
un laboratorio a medio camino del camino que usted creía.

### 4.1 Los shapes del sistema de base de datos, desde la consola

1. Abra el menú de navegación y vaya a la sección de bases de datos.
2. Entre a **MySQL** y luego a **DB Systems**.
3. Pulse **Create DB system**. No va a crear nada todavía.
4. En el selector de compartimento de la parte superior izquierda, elija el
   compartimento del laboratorio.
5. Baje hasta la sección de configuración de hardware y pulse el botón para cambiar
   el shape.
6. Anote qué aparece en la lista. Cierre el formulario sin crear nada.

Lo que busca en esa lista son dos familias distintas:

- Los shapes **standalone**, del tipo `MySQL.2`, `MySQL.4`, `MySQL.8` o sus variantes
  flexibles. Cualquiera sirve para el laboratorio. El ensayo se hizo sobre `MySQL.2`
  y todas las cifras de este manual salen de ahí.
- Los shapes **con acelerador HeatWave**, que habilitan la creación posterior del
  clúster. Si la lista de HeatWave viene vacía, el camino A no está disponible en
  esa región y no hay nada que discutir.

### 4.2 La misma verificación por CLI, que es más clara

El formulario de la consola mezcla las dos familias. Por CLI se separan sin
ambigüedad, y por eso vale la pena hacer esta comprobación aunque el resto del
manual sea consola:

```bash
COMP="ocid1.compartment.oc1..aaaaEJEMPLO"

# Todos los shapes de MySQL disponibles en la región
oci mysql shape list --compartment-id "$COMP" --output table

# Solo los que sirven para el clúster acelerador
oci mysql shape list --compartment-id "$COMP" \
  --is-supported-for HEATWAVECLUSTER --output table
```

**Si la segunda lista viene vacía, el acelerador no está disponible en esa región.**
Eso no invalida el laboratorio: se toma el camino B, el tablero lo declara y no se
presenta ninguna comparación de tiempos estimada.

En el ensayo, sobre `us-chicago-1`, la segunda lista devolvió dos shapes:
`HeatWave.32GB` y `HeatWave.512GB`.

!!! TIP Para este volumen, `HeatWave.32GB` sobra
    Tres millones de filas caben de sobra en un nodo de 32 GB. El shape de 512 GB
    cuesta un múltiplo grande del de 32 y no aporta nada a la demostración. Si va
    a activar el acelerador, `HeatWave.32GB` con **un solo nodo** es la
    configuración correcta. En el ensayo este fue uno de los dos ajustes de valores
    que hubo que corregir contra la región: el valor por defecto apuntaba al de
    512 GB.

### 4.3 Los límites de servicio

> CONSOLA: Governance & Administration › Limits, Quotas and Usage

| Campo | Valor |
|---|---|
| Service | MySQL Database |
| Scope | La región y el dominio de disponibilidad donde va a desplegar |

Revise dos cosas:

1. Que el límite de **DB Systems** o de núcleos de MySQL sea mayor que cero. En
   algunos trials viene en cero y no hay forma de crear nada; el laboratorio
   entonces se hace en local, contra un MySQL en contenedor, con las mismas
   consultas y el mismo tablero.
2. Si va por el camino A, que exista límite disponible para nodos de HeatWave.

### 4.4 La decisión de camino, por escrito

Antes de continuar, escriba en algún lado cuál de los dos caminos va a seguir. El
manual se bifurca en tres puntos (capítulos 9, 15 y 16) y conviene no improvisar la
decisión a mitad de camino.

| Camino | Qué demuestra | Costo |
|---|---|---|
| **A · con acelerador** | Todo, incluida la comparación del mismo SQL sobre dos motores sin cambiar una letra | El más alto: DB System + nodo de HeatWave |
| **B · sin acelerador** | El flujo completo, el tablero y los dos hallazgos. Los tiempos son los del motor transaccional | Medio: solo el DB System |

En el ensayo se siguió el camino **B**. El acelerador no se creó por costo, el script
de medición lo detectó solo, y el tablero lo declara explícitamente en vez de estimar
la comparación. El argumento central del laboratorio —el promedio esconde al cliente
que se está quemando— no depende del acelerador.

---

## 5. La red: VCN y Service Gateway

> CONSOLA: Networking › Virtual Cloud Networks › Create VCN

Use la opción de creación simple, no el asistente. El asistente crea Internet Gateway
y NAT Gateway, y este laboratorio no debe tener ninguno de los dos.

| Campo | Valor |
|---|---|
| Name | `lab04-vcn` |
| Create in compartment | El compartimento del laboratorio |
| IPv4 CIDR Blocks | `10.60.0.0/16` |
| DNS resolution | Marcado |
| DNS label | `lab04` |
| Tags | Clave `Taller`, valor `04-datos-analitica` |

1. Verifique que el selector de compartimento de la izquierda apunta al
   compartimento del laboratorio.
2. Pulse **Create VCN**.
3. Escriba `lab04-vcn` en el nombre.
4. En el bloque CIDR escriba `10.60.0.0/16`.
5. Marque la resolución de DNS y ponga `lab04` como etiqueta DNS. La etiqueta no se
   puede cambiar después.
6. Despliegue las etiquetas y agregue `Taller = 04-datos-analitica`. Esta etiqueta es
   la que después permite filtrar el costo del laboratorio y verificar que quedó
   apagado.
7. Pulse **Create VCN**.

**Etiquete todo, desde el primer recurso.** La etiqueta `Taller` en cada recurso es lo
que hace que el análisis de costo responda «este laboratorio costó tanto» en vez de
«la cuenta costó tanto». Es treinta segundos por recurso y es la diferencia entre
poder auditar el gasto y tener que adivinarlo. Todos los recursos de este manual
llevan la misma etiqueta.

### 5.1 El Service Gateway

La base de datos necesita un camino hacia Object Storage para que la importación no
tenga que salir a internet. Ese camino es el Service Gateway.

> CONSOLA: Networking › Virtual Cloud Networks › lab04-vcn › Service Gateways › Create Service Gateway

| Campo | Valor |
|---|---|
| Name | `lab04-sgw` |
| Create in compartment | El compartimento del laboratorio |
| Services | La entrada que cubre **todos** los servicios de la Oracle Services Network en esa región |

1. Entre a la VCN recién creada.
2. En el panel de recursos de la izquierda, elija los service gateways.
3. Pulse **Create Service Gateway**.
4. Escriba `lab04-sgw` como nombre.
5. En el selector de servicios hay dos opciones: una que cubre solo Object Storage de
   la región y otra que cubre todos los servicios de la Oracle Services Network.
   **Elija la que cubre todos**, que es la que aparece con el nombre de la región
   seguido de la mención a la Oracle Services Network. La opción restringida a Object
   Storage también funcionaría para la importación, pero deja fuera cualquier otra
   comprobación que quiera hacer después.
6. Pulse **Create Service Gateway**.

### 5.2 La tabla de rutas de la subred privada

> CONSOLA: Networking › Virtual Cloud Networks › lab04-vcn › Route Tables › Create Route Table

| Campo | Valor |
|---|---|
| Name | `lab04-rt-privada` |
| Target Type | Service Gateway |
| Destination Service | El mismo conjunto de servicios que eligió en el gateway |
| Target Service Gateway | `lab04-sgw` |

1. Pulse **Create Route Table**.
2. Nómbrela `lab04-rt-privada`.
3. Agregue una regla de ruta. Como tipo de destino elija el service gateway.
4. En el servicio de destino elija el mismo conjunto que configuró en el gateway.
5. Seleccione `lab04-sgw` como gateway destino.
6. Pulse **Create**.

Esta tabla tiene **una sola regla**. No agregue una ruta por defecto hacia
`0.0.0.0/0`: precisamente lo que hace privada a esta subred es que esa ruta no
exista.

---

## 6. La security list de la base de datos

Este capítulo va antes que la subred porque la subred va a referenciar esta lista.

> CONSOLA: Networking › Virtual Cloud Networks › lab04-vcn › Security Lists › Create Security List

| Campo | Valor |
|---|---|
| Name | `lab04-sl-mysql` |
| Create in compartment | El compartimento del laboratorio |

Reglas de entrada, dos, ambas con origen `10.60.1.0/24`:

| Campo | Regla 1 | Regla 2 |
|---|---|---|
| Stateless | Sin marcar | Sin marcar |
| Source Type | CIDR | CIDR |
| Source CIDR | `10.60.1.0/24` | `10.60.1.0/24` |
| IP Protocol | TCP | TCP |
| Destination Port Range | `3306` | `33060` |
| Description | `MySQL protocolo clasico, solo desde la subred` | `MySQL protocolo X, solo desde la subred` |

Regla de salida, una:

| Campo | Valor |
|---|---|
| Stateless | Sin marcar |
| Destination Type | CIDR |
| Destination CIDR | `0.0.0.0/0` |
| IP Protocol | All Protocols |

1. Pulse **Create Security List** y escriba `lab04-sl-mysql`.
2. Pulse **+ Another Ingress Rule** y complete la primera regla con el puerto `3306`.
3. Repita con el puerto `33060`. Es el puerto del protocolo X, que es el que usa
   MySQL Shell cuando no se le fuerza el protocolo clásico. Si lo omite, algunas
   conexiones funcionarán y otras no, y el diagnóstico es confuso.
4. Agregue la regla de salida hacia `0.0.0.0/0` con todos los protocolos. Parece
   contradictorio en una subred privada, pero no lo es: la salida está permitida por
   la lista y **bloqueada por la tabla de rutas**, que no tiene camino hacia
   internet. El control efectivo es el enrutamiento.
5. Pulse **Create Security List**.

### Por qué el origen es el CIDR de la subred y no la IP del bastión

Sería más estricto permitir únicamente la dirección exacta del endpoint del bastión.
No se puede hacer en este orden: esa dirección solo existe después de crear el
bastión, y el bastión vive en la subred que aún no existe. En esta subred solo hay
dos cosas —la base de datos y el endpoint del bastión—, así que el alcance real es el
mismo.

Si quiere apretarlo, se puede: cree todo, anote la IP privada del endpoint del
bastión, y vuelva a esta security list a cambiar el origen de `10.60.1.0/24` a esa
dirección con máscara `/32`. Es un cambio en caliente y no interrumpe nada.

---

## 7. La subred privada

> CONSOLA: Networking › Virtual Cloud Networks › lab04-vcn › Subnets › Create Subnet

| Campo | Valor |
|---|---|
| Name | `lab04-subnet-privada-datos` |
| Subnet Type | Regional |
| IPv4 CIDR Block | `10.60.1.0/24` |
| Route Table | `lab04-rt-privada` |
| Subnet Access | **Private Subnet** |
| DNS resolution | Marcado |
| DNS Label | `datos` |
| Security Lists | `lab04-sl-mysql` |

1. Pulse **Create Subnet**.
2. Nómbrela `lab04-subnet-privada-datos`.
3. Deje el tipo **Regional**. Una subred regional abarca todos los dominios de
   disponibilidad y evita el problema de crear la base en un dominio y la subred en
   otro.
4. Escriba `10.60.1.0/24` como bloque CIDR.
5. Seleccione `lab04-rt-privada` como tabla de rutas.
6. En el acceso de la subred elija **Private Subnet**. Esta casilla es la que impide
   asignar direcciones IP públicas a cualquier VNIC de la subred. No es una
   sugerencia: es una prohibición a nivel de subred, y es lo que garantiza que la
   base de datos no pueda quedar expuesta por un descuido posterior.
7. Marque la resolución de DNS y escriba `datos` como etiqueta.
8. En las security lists **quite la lista por defecto de la VCN** y seleccione
   `lab04-sl-mysql`. Si deja las dos, las reglas se suman y la lista por defecto
   abre cosas que este laboratorio no necesita.
9. Pulse **Create Subnet**.

**Cómo saber que la subred quedó bien.** En su página de detalle deben ser ciertas
tres cosas: el acceso dice que es privada, la tabla de rutas asociada es
`lab04-rt-privada` y su única regla apunta al service gateway, y la única security
list asociada es `lab04-sl-mysql`. Si alguna de las tres falla, arréglela ahora:
corregirla después de crear la base de datos es posible, pero el diagnóstico del
fallo será mucho más confuso.

---

## 8. El sistema de base de datos MySQL

Este es el recurso caro y el que más tarda. En el ensayo el aprovisionamiento tomó
alrededor de **20 minutos**. Lánzelo y aproveche la espera para generar el CSV del
capítulo 12: el orden de los capítulos es el de creación, no el de ejecución
obligatoria.

> CONSOLA: Databases › MySQL › DB Systems › Create DB system

En algunas versiones de la consola el menú aparece como **HeatWave MySQL** en lugar
de **MySQL**. Es el mismo servicio.

### 8.1 Identificación y tipo

| Campo | Valor |
|---|---|
| Compartment | El compartimento del laboratorio |
| Name | `lab04-documentos` |
| Description | `Laboratorio de analitica operacional` |
| Tipo de sistema | **Standalone** |

1. Verifique el compartimento.
2. Escriba `lab04-documentos` como nombre.
3. En la selección del tipo de sistema hay tres opciones: independiente, alta
   disponibilidad y HeatWave. **Elija la independiente.** La de alta disponibilidad
   crea tres instancias y triplica el costo sin aportar nada a este laboratorio. La
   opción de HeatWave no es necesaria aquí: el clúster acelerador se agrega después,
   sobre el sistema ya creado, y así es más fácil decidir con calma (capítulo 9).

Antes de pulsar nada más, tenga presente que **este recurso es el más caro de todo el
conjunto**: cobra por estar encendido, no por usarse, y un fin de semana olvidado se
nota en el crédito del trial. Si va a interrumpir el laboratorio por más de unas
horas, vaya al capítulo 19 y bórrelo. El capítulo 19 desarrolla esto, porque es donde
más daño hace no leerlo.

### 8.2 Credenciales del administrador

| Campo | Valor |
|---|---|
| Username | `admin` |
| Password | Una contraseña que cumpla la política de complejidad |
| Confirm password | La misma |

La contraseña debe llevar mayúsculas, minúsculas, número y símbolo. Si el formulario
la rechaza, es casi siempre el símbolo lo que falta. Anótela donde la vaya a
recuperar: la va a necesitar en el capítulo 13 y en el 16, y cambiarla después exige
entrar a la base.

### 8.3 Hardware

| Campo | Valor |
|---|---|
| Shape | Uno de los que verificó en el capítulo 4 (el ensayo usó `MySQL.2`) |
| Data storage size | `50` GB |

1. Pulse el botón para cambiar el shape.
2. Elija un shape de la familia standalone. Con `MySQL.2` alcanza: los tres millones
   de filas se cargaron en cuatro minutos sobre ese shape y las consultas del
   laboratorio se resolvieron en los tiempos que este manual cita.
3. Deje el almacenamiento en `50` GB, que es el mínimo. Tres millones de documentos
   ocupan bastante menos: el CSV de origen pesa alrededor de **305 MB**.

### 8.4 Red y ubicación

| Campo | Valor |
|---|---|
| Virtual cloud network | `lab04-vcn` |
| Subnet | `lab04-subnet-privada-datos` |
| Availability domain | El primero de la lista |

1. Seleccione la VCN y la subred privada.
2. Elija un dominio de disponibilidad. Cualquiera sirve; use el primero y recuérdelo.

Observe que el formulario **no ofrece asignar una dirección pública**. Eso no es una
limitación del servicio: es la consecuencia de haber marcado la subred como privada
en el capítulo 7. El DB System de MySQL tampoco ofrece Network Security Groups; su
control de red es la security list que ya creó.

### 8.5 Respaldos y plan de borrado

Abra las opciones avanzadas del formulario.

| Campo | Valor | Por qué |
|---|---|---|
| Enable automatic backups | **Desmarcado** | Laboratorio efímero, crédito finito |
| Enable delete protection | **Desmarcado** | Para poder borrarlo sin fricción al terminar |
| Require final backup | **Desmarcado** | Un respaldo final huérfano sigue cobrando |
| Retain automatic backups after deletion | **Desmarcado** | Igual que el anterior |
| Port | `3306` |  |
| X Protocol port | `33060` |  |

**En un ambiente con datos, estas cuatro casillas van al revés:** respaldos
automáticos encendidos, protección de borrado encendida, respaldo final obligatorio y
retención de respaldos tras el borrado. Aquí están apagadas porque el objetivo
explícito es poder destruir el laboratorio sin dejar nada cobrando. Si alguien copia
esta configuración a un ambiente productivo, ha copiado exactamente la parte
equivocada del manual.

### 8.6 Crear y esperar

1. Agregue la etiqueta `Taller = 04-datos-analitica`.
2. Pulse **Create**.
3. El estado pasa a estar en creación. **Tarda entre 15 y 25 minutos**; en el ensayo
   fueron cerca de 20.
4. Cuando quede activo, entre al detalle y **anote la dirección IP privada**. Es el
   dato que va a necesitar en el capítulo 11. Tendrá la forma `10.60.1.x`.

Si a los 40 minutos sigue creándose, espere. Suele terminar. Cancelar a medias deja
recursos sueltos que después hay que cazar uno por uno.

---

## 9. El acelerador de HeatWave — solo camino A

**Si eligió el camino B, salte al capítulo 10.** Todo el resto del laboratorio
funciona sin este capítulo; lo único que se pierde es la comparación de tiempos entre
motores, que entonces no se presenta con cifras estimadas.

> CONSOLA: Databases › MySQL › DB Systems › lab04-documentos › HeatWave › Add HeatWave cluster

| Campo | Valor |
|---|---|
| Shape | `HeatWave.32GB` |
| Node count | `1` |
| Lakehouse | Desactivado |

1. Entre al detalle del sistema `lab04-documentos`.
2. En el panel de recursos, elija la sección de HeatWave.
3. Pulse el botón para agregar el clúster.
4. Seleccione el shape `HeatWave.32GB`. Si la consola ofrece una estimación
   automática del número de nodos, puede usarla, pero para este volumen va a
   proponer uno y con uno basta.
5. Deje el número de nodos en `1`.
6. Deje la opción de lakehouse desactivada. Sirve para consultar archivos en Object
   Storage sin cargarlos a la base, y no es lo que este laboratorio demuestra.
7. Pulse **Add HeatWave cluster**.

**El clúster cobra aparte y cobra desde que existe.** No es un modo de operación del
sistema de base de datos: es capacidad de cómputo adicional, facturada por separado,
y empieza a contar en cuanto el clúster queda activo. En el ensayo se decidió no
crearlo. La decisión no fue técnica: fue de presupuesto, y el tablero lo dice.

El clúster tarda varios minutos en quedar activo. Crearlo **no** hace por sí solo que
las consultas se aceleren: falta marcar la tabla y cargarla en memoria, que es el
capítulo 15, y eso solo se puede hacer después de que los datos estén cargados.

---

## 10. El bastión

La base de datos no tiene dirección pública. El bastión es la única puerta.

> CONSOLA: Identity & Security › Bastion › Create bastion

| Campo | Valor |
|---|---|
| Bastion name | `lab04bastion` |
| Compartment | El compartimento del laboratorio |
| Target virtual cloud network | `lab04-vcn` |
| Target subnet | `lab04-subnet-privada-datos` |
| CIDR block allowlist | `0.0.0.0/0` en este laboratorio — ver el recuadro |
| Maximum session time-to-live | `10800` segundos (3 horas) |

1. Pulse **Create bastion**.
2. Escriba `lab04bastion` como nombre. **Sin guiones ni puntos**: el nombre del
   bastión solo admite letras y números, y el formulario rechaza `lab04-bastion` con
   un mensaje que no siempre es claro sobre la causa.
3. Seleccione la VCN y la subred privada. El bastión crea un endpoint dentro de esa
   subred, y ese endpoint es el que va a alcanzar la base de datos.
4. En la lista de CIDR permitidos, escriba el valor que corresponda (ver abajo).
5. En el tiempo máximo de vida de sesión, escriba `10800`. Son tres horas, suficiente
   para una jornada de trabajo sobre los datos sin tener que recrear la sesión.
6. Agregue la etiqueta `Taller = 04-datos-analitica`.
7. Pulse **Create bastion**.

!!! IMPORTANTE La lista de clientes está abierta a `0.0.0.0/0` a propósito
    En este laboratorio la lista de CIDR permitidos se deja en `0.0.0.0/0`, y el
    puerto 22 queda abierto a internet, **porque es un ambiente desechable, con
    datos sintéticos, que se destruye el mismo día**. Se hace así para que el túnel
    funcione desde cualquier red sin tener que reconfigurar el bastión cada vez que
    cambia la IP de salida.

    La práctica correcta en un ambiente con datos es la contraria: la lista
    contiene únicamente los rangos de salida conocidos de la organización —la VPN
    corporativa, la oficina— con máscara `/32` cuando se trata de una dirección
    fija, y se revisa cuando cambian. Un bastión con la lista abierta sigue
    exigiendo credenciales de OCI y la llave privada de la sesión, de modo que no
    es una puerta abierta; pero es una puerta visible desde todo internet, y no hay
    ninguna razón para dejarla visible cuando se sabe de dónde van a venir los
    administradores.

    Si prefiere apretarlo desde el principio, obtenga su dirección pública de
    salida con `curl -s ifconfig.me` y escríbala con `/32`. Tendrá que actualizarla
    cada vez que cambie de red, y hay que contar con eso.

8. Cuando el bastión quede activo, entre a su detalle y **anote la dirección IP
   privada de su endpoint**. Es la que está autorizada por la security list del
   capítulo 6.

---

## 11. La sesión de reenvío de puerto y el túnel

Aquí es donde se conectan las dos mitades del laboratorio. La consola no abre el
túnel: crea una sesión y le entrega un comando. El túnel lo sostiene su terminal.

### 11.1 Crear la sesión

> CONSOLA: Identity & Security › Bastion › lab04bastion › Sessions › Create session

| Campo | Valor |
|---|---|
| Session type | **SSH port forwarding session** |
| Session name | `lab04-mysql` |
| Connect to the target host by using its IP address | Marcado |
| IP address | La IP privada del DB System, anotada en 8.6 |
| Port | `3306` |
| Add SSH key | Pegue o cargue su llave **pública** |
| Maximum session time-to-live | `10800` segundos |

1. Entre al bastión y pulse **Create session**.
2. En el tipo de sesión elija la de **reenvío de puerto SSH**. La otra opción, la de
   sesión administrada, sirve para conectarse a una instancia de cómputo con el
   agente de bastión instalado; una base de datos administrada no tiene ese agente,
   así que esa opción no aplica.
3. Nombre la sesión `lab04-mysql`.
4. Indique que se conecta por dirección IP y escriba la IP privada de la base de
   datos.
5. Escriba `3306` como puerto destino.
6. Cargue o pegue su llave **pública** (el archivo `.pub`). Es un error frecuente
   pegar la privada; el formulario la rechaza, pero no siempre con un mensaje que
   deje claro qué pasó.
7. Pulse **Create session**. Tarda uno o dos minutos en quedar activa.

**Cree la sesión antes de necesitarla, no durante.** Crear una sesión de bastión toma
entre uno y dos minutos, y una sesión expirada no se renueva: hay que crear otra. Si
este laboratorio se va a mostrar en vivo, la sesión se abre antes de empezar, no
delante de la audiencia. Con un TTL de tres horas alcanza para una jornada completa.

### 11.2 Qué se hace con el comando que entrega

1. En la lista de sesiones, abra el menú de acciones de la sesión recién creada.
2. Elija la opción de copiar el comando SSH.
3. Péguelo en un editor. Tiene esta forma:

```text
ssh -i <privateKey> -N -L <localPort>:10.60.1.9:3306 -p 22 \
  <ocid-de-la-sesion>@host.bastion.<region>.oci.oraclecloud.com

  donde <ocid-de-la-sesion> tiene la forma
  ocid1.bastionsession.oc1..aaaaEJEMPLO
```

4. Sustituya `<privateKey>` por la ruta a su llave **privada** (el archivo sin la
   extensión `.pub`).
5. Sustituya `<localPort>` por `3306`.
6. Ejecute el comando en una terminal **y deje esa terminal abierta**. La opción
   `-N` significa que no se abre una shell remota: el proceso se queda ahí,
   aparentemente colgado, sosteniendo el túnel. Que no imprima nada es la señal de
   que funciona.
7. Todo el trabajo siguiente se hace en **otra** terminal, conectándose a
   `127.0.0.1:3306`.

!!! CUIDADO La ruta de la llave con espacios rompe el comando en Windows
    En Windows el directorio del usuario suele llevar un espacio, y la ruta de la
    llave parte el comando en dos. La corrección es encerrar **solo la ruta de la
    llave** entre comillas **simples**:

        ssh -i 'C:/Users/Nombre Apellido/.ssh/id_rsa' -N -L 3306:10.60.1.9:3306 ...

    Las comillas dobles fallan de otra manera y el diagnóstico se enreda. Este fue
    uno de los nueve fallos encontrados en el ensayo, y costó un rato entenderlo.

    Si además la primera conexión le pide aceptar la huella del servidor y el
    proceso parece quedarse esperando, agregue
    `-o StrictHostKeyChecking=accept-new` al comando. En el ensayo la huella se
    pidió **dos veces**, con dos silencios incómodos de por medio.

### 11.3 Comprobar que el túnel sirve

En la segunda terminal:

```bash
mysqlsh --mysql -u admin -h 127.0.0.1 -P 3306 --sql -e "SELECT VERSION();"
```

!!! VALIDACION El túnel está vivo si esto devuelve una versión
    El comando debe imprimir la versión del servidor MySQL. Si no conecta, revise
    en este orden: (1) que la terminal del túnel siga abierta y sin errores; (2)
    que su dirección pública de salida esté dentro de la lista de CIDR del bastión
    —`curl -s ifconfig.me` y compare—; (3) que la sesión siga activa en la consola
    y no haya expirado; (4) que la security list permita `3306` desde el CIDR de la
    subred. En el ensayo, la causa fue casi siempre la segunda.

---

## 12. El bucket de Object Storage y el CSV

### 12.1 Generar los datos

Esto se hace en su equipo y no necesita el túnel. Si lanzó la creación del DB System
hace unos minutos, este es el momento de hacerlo.

```bash
cd talleres/04-datos-analitica/datos

# Primero una prueba pequeña, para ver que el script corre
python generar_datos.py --filas 200000 --salida prueba.csv

# Y el conjunto real
python generar_datos.py --filas 3000000 --salida documentos.csv
```

Tres millones de filas tardan entre **2 y 4 minutos** en generarse y producen un
archivo de alrededor de **305 MB**. El CSV sale sin encabezado, en el orden exacto de
columnas del esquema.

Los datos traen **dos hallazgos plantados a propósito**, que no se anuncian al
presentar el tablero: un cliente que se deteriora y un canal lento. La gracia del
ejercicio es que quien mire el tablero los encuentre solo.

### 12.2 Crear el bucket

> CONSOLA: Storage › Object Storage & Archive Storage › Buckets › Create Bucket

| Campo | Valor |
|---|---|
| Bucket Name | `lab04-datos` |
| Create in compartment | El compartimento del laboratorio |
| Default Storage Tier | Standard |
| Encryption | Claves gestionadas por Oracle |
| Visibility | **Private** |

1. Verifique el compartimento en el selector de la izquierda.
2. Pulse **Create Bucket**.
3. Escriba `lab04-datos`.
4. Deje el nivel estándar y el cifrado por defecto.
5. Pulse **Create**.
6. Entre al bucket y confirme que la visibilidad dice **Private**. Un bucket público
   con datos, aunque sean sintéticos, es exactamente el hallazgo que cualquier
   auditoría reporta primero.

### 12.3 Subir el CSV

> CONSOLA: Storage › Object Storage & Archive Storage › Buckets › lab04-datos › Upload

1. Entre al bucket.
2. En la sección de objetos, pulse **Upload**.
3. Deje el prefijo vacío.
4. Seleccione `documentos.csv`.
5. Pulse **Upload** y espere. Son 305 MB: la consola sube el archivo en partes y
   tarda lo que dé su conexión de subida.

Si la carga por navegador se cae —pasa con archivos grandes y conexiones
inestables—, la alternativa por CLI es más robusta porque paraleliza y reintenta:

```bash
oci os object put --bucket-name lab04-datos \
  --file documentos.csv --parallel-upload-count 4
```

**Compruebe el tamaño antes de seguir.** En la lista de objetos del bucket, el tamaño
de `documentos.csv` debe coincidir con el del archivo local, byte por byte. Un objeto
truncado importa sin error y produce una tabla a medias, que es el peor de los fallos
posibles de este laboratorio porque no se ve: produce un tablero completo y
equivocado.

---

## 13. El esquema y la carga de los datos

A partir de aquí el trabajo es en terminal, con el túnel abierto. No hay equivalente
por consola: OCI no expone un editor SQL para el DB System de MySQL.

### 13.1 Crear la base y la tabla

```bash
mysqlsh --mysql -u admin -h 127.0.0.1 -P 3306 --sql < ../datos/esquema.sql
```

El esquema crea la base `operacion` y una sola tabla ancha, `documentos`, con doce
columnas y tres índices. La tabla es ancha a propósito: el laboratorio no trata sobre
modelado dimensional, trata sobre qué decisiones se pueden tomar con estos datos y
cuánto tarda la consulta que las responde.

Los tres índices —por fecha, por cliente y fecha, y por estado y fecha— están puestos
para las consultas concretas del capítulo 16. Sobre el motor transaccional son lo que
hace la diferencia; sobre el acelerador dejan de importar, y ese contraste es parte
de lo que el laboratorio muestra.

### 13.2 Importar el CSV

```bash
mysqlsh --mysql -u admin -h 127.0.0.1 -P 3306 -- util import-table \
  "documentos.csv" \
  --osBucketName=lab04-datos \
  --schema=operacion --table=documentos \
  --fieldsTerminatedBy="," \
  --threads=4 --bytesPerChunk=50M
```

MySQL Shell lee el objeto del bucket con sus propias credenciales de OCI y empuja las
filas hacia la base por el túnel, en cuatro hilos paralelos, en trozos de 50 MB. El
Service Gateway es lo que da a la subred un camino privado hacia los servicios de
OCI sin Internet Gateway ni NAT.

**Medido en el ensayo: tres millones de filas, 305 MB, en cuatro minutos**, con un
shape `MySQL.2` y el tráfico pasando por el túnel del bastión.

!!! IMPORTANTE No pase `--linesTerminatedBy`. El error que produce no dice nada de la causa
    Si agrega `--linesTerminatedBy="\n"` al comando —que es lo que uno escribiría
    por simetría con `--fieldsTerminatedBy`—, la importación falla con este mensaje:

        Separators cannot be the same or be a prefix of another

    El mensaje habla de separadores iguales o uno prefijo del otro, que no es lo
    que está pasando. Lo que pasa es que la herramienta recibe la secuencia
    literal de dos caracteres en vez de un salto de línea, y ese literal entra en
    conflicto con el separador de campos. **La solución es sencilla: no pase ese
    parámetro.** El salto de línea ya es el valor por defecto.

    Está registrado como el fallo número 9 del ensayo, y es el tipo de error que
    cuesta media hora si no se sabe de antemano.

Si `util import-table` no encuentra el bucket —por credenciales, por región o por
permisos—, la alternativa es importar desde el archivo local:

```bash
mysqlsh --mysql -u admin -h 127.0.0.1 -P 3306 -- util import-table \
  "documentos.csv" \
  --schema=operacion --table=documentos \
  --fieldsTerminatedBy="," --threads=4
```

Tarda más porque todo el volumen sube por el túnel desde su equipo, pero no depende
de Object Storage.

---

## 14. Verificación de la carga

**Este capítulo no es opcional.** Una importación a medias no produce un error: produce
un tablero completo, convincente y equivocado. Tres consultas bastan.

```sql
-- 1. El conteo
SELECT COUNT(*) FROM operacion.documentos;

-- 2. El rango de fechas
SELECT MIN(fecha_emision), MAX(fecha_emision) FROM operacion.documentos;

-- 3. La distribución por estado
SELECT estado, COUNT(*) FROM operacion.documentos GROUP BY estado;
```

Qué debe ver:

| Comprobación | Esperado | Medido en el ensayo |
|---|---|---|
| Conteo de filas | Coincide con las líneas del CSV | `2.999.882` |
| Rango de fechas | Cubre seis meses hacia atrás desde hoy | Seis meses completos |
| Estado `ACEPTADO` | Alrededor del 94 % del total | Consistente con una tasa de rechazo del 5,04 % |

!!! VALIDACION Las tres tienen que pasar, no dos de tres
    Si el conteo no coincide, la importación quedó a medias: vacíe la tabla con
    `TRUNCATE TABLE operacion.documentos;` y repítala. No intente completarla
    importando de nuevo encima: la clave primaria rechazará los duplicados y el
    resultado será todavía más difícil de interpretar.

    Si el rango de fechas no llega hasta hoy, el CSV es de otra corrida. Las
    consultas del laboratorio usan ventanas relativas (`CURDATE() - INTERVAL 30
    DAY`) y con datos viejos devuelven conjuntos vacíos, lo que se parece mucho a
    un error de conexión sin serlo.

---

## 15. Cargar la tabla en el acelerador — solo camino A

**Si eligió el camino B, salte al capítulo 16.**

Crear el clúster no acelera nada por sí solo. Hacen falta dos sentencias: una marca la
tabla como candidata y la otra la carga en la memoria del acelerador.

```sql
USE operacion;
ALTER TABLE documentos SECONDARY_ENGINE = RAPID;
ALTER TABLE documentos SECONDARY_LOAD;
```

La segunda tarda: está moviendo la tabla entera a memoria columnar. Verifique que
quedó cargada:

```sql
SELECT NAME, LOAD_STATUS
FROM performance_schema.rpd_tables
JOIN performance_schema.rpd_table_id USING (ID);
```

A partir de aquí, **la misma consulta SQL, sin cambiar una letra**, puede resolverse
en un motor o en el otro. Ese es el argumento comercial del laboratorio: no hay que
reescribir la aplicación para tener analítica rápida.

Si el clúster no existe, estas sentencias fallan. No pasa nada más: la tabla sigue
ahí, las consultas siguen funcionando sobre el motor transaccional y el resto del
laboratorio es idéntico.

---

## 16. Las mediciones y el tablero

```bash
cd ../datos
pip install -r requirements.txt

python medir_consultas.py --usuario admin --password '...' --puerto 3306
python tablero.py --entrada resultados.json --salida tablero.html
```

El script de medición hace tres cosas que conviene conocer:

1. **Comprueba de verdad si hay acelerador.** No lo asume por configuración: intenta
   forzar el motor secundario en la sesión y ve si la consulta se resuelve. Si no,
   lo dice y sigue.
2. **Ejecuta cada consulta varias veces y toma la mediana.** Una sola medición sobre
   una base recién cargada mide más el estado de la caché que la consulta.
3. **Nunca inventa el segundo número.** Si no hay acelerador, la columna de
   comparación queda vacía y el tablero lo declara explícitamente.

### 16.1 Los tiempos medidos, sin acelerador

Sobre tres millones de filas, shape `MySQL.2`, motor transaccional:

| Consulta | Tiempo |
|---|---|
| Clientes cuya tasa de rechazo empeoró esta semana | **5,62 s** |
| Agregación completa de seis meses por cliente, tipo y estado | **3,88 s** |
| Tasa de rechazo diaria (30 días) | 0,66 s |
| Tiempo de validación p50 y p95 por canal | 0,66 s |
| Documentos emitidos por día (30 días) | 0,21 s |
| La misma analítica para un solo cliente | 0,21 s |
| Motivos de rechazo (30 días) | 0,13 s |
| Documentos detenidos hace más de 4 horas | 0,09 s |

Las dos primeras son las que justifican la conversación sobre el acelerador. Las seis
restantes se resuelven por debajo del segundo con los índices adecuados, y esa es una
conclusión igual de valiosa: **no todo problema de lentitud necesita capacidad
adicional; buena parte necesita el índice correcto.**

### 16.2 Los dos hallazgos

| Hallazgo | Medido |
|---|---|
| Tasa de rechazo **agregada** del período | 5,04 % — tranquila |
| **Cliente 47** | **23,8 %**, contra 6,2 % en el período previo |
| Siguiente cliente de la lista | 8,1 % |
| Canal LOTE | p50 **18 min**, p95 **56 min** |
| Canal PORTAL | p50 6 min, p95 17 min |
| Canal API | p50 2 min, p95 5 min |
| Documentos detenidos más de 4 horas | 978 |
| Documentos emitidos en 30 días | 504.753 |

El primero es el argumento del laboratorio: **la mediana del canal por lotes es casi
cuatro veces la del API, y su p95 es once veces el p95 del API.** Eso no es un
problema de reportes: es una decisión de arquitectura. Y el cliente 47, con 23,8 %
contra un agregado de 5,04 %, está invisible en cualquier indicador promediado.

### 16.3 Revisar el tablero con los ojos

El tablero es **un solo archivo HTML sin dependencias ni llamadas externas**. Abre
con doble clic, sin internet. Eso no es una limitación: es el patrón de analítica
embebida, y es la parte del laboratorio que se puede llevar a una reunión sin
infraestructura detrás.

Ábralo y confirme, una por una:

- [ ] Los cuatro indicadores de la parte superior tienen valores razonables.
- [ ] La gráfica de volumen muestra el patrón semanal y los picos de fin de mes.
- [ ] La tasa de rechazo agregada **no** muestra nada alarmante.
- [ ] La tabla de clientes en riesgo tiene al **cliente 47** de primero, en rojo.
- [ ] El canal **LOTE** aparece con el p95 más alto, muy por encima del API.
- [ ] La tabla de tiempos dice la verdad sobre el acelerador: o muestra la
      comparación real, o declara que no hubo acelerador.

Si el cliente 47 no aparece, casi siempre es porque la muestra es pequeña: la
consulta exige más de 100 documentos en siete días para considerar a un cliente. Con
tres millones de filas aparece (tuvo 492 documentos en la ventana); con doscientas
mil, puede que no.

**Guarde una copia del tablero generado.** Si el laboratorio se va a mostrar, ese
archivo es el respaldo: no necesita base de datos, ni túnel, ni red.

---

## 17. Validación de extremo a extremo

Seis comprobaciones. Si las seis pasan, el laboratorio está completo y correcto.

| # | Qué se comprueba | Dónde | Resultado esperado |
|---|---|---|---|
| 1 | La base no tiene dirección pública | Consola › detalle del DB System | Solo aparece una IP privada `10.60.1.x` |
| 2 | La subred prohíbe direcciones públicas | Consola › detalle de la subred | El acceso dice que es privada |
| 3 | La única salida es el Service Gateway | Consola › tabla de rutas `lab04-rt-privada` | Una sola regla, hacia el service gateway; ninguna hacia `0.0.0.0/0` |
| 4 | El túnel conecta | Terminal | `SELECT VERSION();` devuelve una versión |
| 5 | Los datos están completos | Terminal | El conteo coincide con las líneas del CSV |
| 6 | El tablero contiene los dos hallazgos | Navegador | Cliente 47 de primero; canal LOTE con el p95 más alto |

Y una verificación que vale la pena hacer aunque parezca redundante:

```bash
# Confirmar que la base NO responde desde fuera del túnel.
# Debe fallar. Si conecta, algo se configuró mal.
mysqlsh --mysql -u admin -h 10.60.1.9 -P 3306 --sql -e "SELECT 1;"
```

**El fallo de esa última comprobación es el resultado correcto.** El comando debe
fallar por tiempo de espera agotado desde cualquier equipo que no esté dentro de la
VCN. Que falle es precisamente lo que demuestra el control de red: la base solo es
alcanzable a través del bastión. Si conecta, revise que no quedó una regla de entrada
de más en la security list y que no asoció por error la security list por defecto de
la VCN a la subred.

---

## 18. Qué puede salir mal

Todos los fallos de esta tabla están documentados en el repositorio del laboratorio y
fueron encontrados desplegando de verdad, no imaginando.

| Síntoma | Causa | Arreglo |
|---|---|---|
| La importación falla con *«Separators cannot be the same or be a prefix of another»* | Se pasó `--linesTerminatedBy`; la herramienta recibe la secuencia literal y choca con el separador de campos. El mensaje no menciona la causa real | **No pasar ese parámetro.** El salto de línea es el valor por defecto. Fallo 9 del ensayo |
| El comando SSH del bastión se parte en dos en Windows | La ruta del directorio del usuario lleva un espacio | Encerrar **solo la ruta de la llave** entre comillas simples. Con dobles falla de otra manera. Fallo 7 |
| La primera conexión pide aceptar la huella dos veces | Comportamiento por defecto de SSH en ese flujo | Agregar `-o StrictHostKeyChecking=accept-new` al comando. Fallo 8 |
| El formulario del DB System rechaza el shape | El nombre no existe en esa región | Capítulo 4. Los nombres cambian entre regiones |
| El formulario rechaza la contraseña | No cumple la política de complejidad | Mayúsculas, minúsculas, número y símbolo |
| La creación del DB System falla con un error de límite excedido | El límite de MySQL del trial está en cero o agotado | Solicitar aumento de límite, o hacer el laboratorio contra un MySQL local con las mismas consultas y el mismo tablero |
| La creación del DB System lleva más de 40 minutos | Suele terminar igual | Esperar. Cancelar a medias deja recursos sueltos que hay que borrar uno por uno |
| La sesión del bastión se crea pero el túnel no conecta | Su dirección pública de salida no está en la lista de CIDR del bastión | `curl -s ifconfig.me` y comparar. Es la causa más frecuente con diferencia |
| El túnel conecta y `mysqlsh` no | Falta el puerto `33060` en la security list, o el protocolo X no está permitido | Revisar las dos reglas de entrada del capítulo 6 |
| La sesión del bastión expiró a mitad de trabajo | El TTL se agotó | Crear otra sesión. No se renuevan; esto toma uno o dos minutos |
| `util import-table` no encuentra el bucket | Credenciales, región o permisos de OCI del cliente | Importar desde el archivo local (final del capítulo 13). Tarda más, no depende de Object Storage |
| El conteo de filas no coincide con el CSV | Importación a medias, u objeto truncado en el bucket | `TRUNCATE TABLE` y repetir. **No** importar encima: la clave primaria rechaza duplicados y el resultado es peor de interpretar |
| `ALTER TABLE ... SECONDARY_ENGINE` falla | No hay clúster de HeatWave | Es el camino B y es correcto. El tablero lo declara solo |
| El script de medición dice que no hay acelerador teniéndolo | El clúster existe pero la tabla no se cargó en memoria | Ejecutar `SECONDARY_LOAD` y verificar en `performance_schema.rpd_tables` |
| El cliente 47 no aparece en la tabla de riesgo | La muestra es pequeña: la consulta exige más de 100 documentos en siete días | Generar los tres millones de filas, no una muestra de prueba |
| Las consultas devuelven conjuntos vacíos | El CSV es de una corrida vieja y las ventanas de las consultas son relativas a hoy | Regenerar los datos |
| Los números del tablero se ven raros y no sabe por qué | Cualquiera de las causas de carga incompleta | **Deténgase.** Un tablero con datos incompletos es peor que ningún tablero: es convincente y está mal |

---

## 19. Limpieza

El orden importa. Borrar en el orden equivocado produce errores de dependencia que
obligan a volver atrás, y peor: deja recursos cobrando que uno cree haber borrado.

!!! CUIDADO El sistema de base de datos es lo más caro del conjunto y cobra aunque nadie lo use
    No cobra por consulta, ni por conexión, ni por dato leído: cobra por estar
    encendido. Una base de datos que nadie toca durante un fin de semana cuesta
    exactamente lo mismo que una que se usa sin parar. Si además creó el clúster de
    HeatWave, son dos cargos, y el del clúster es el mayor de los dos.

    En el ensayo se reportó en un momento que este laboratorio se había destruido.
    **No era cierto**: el sistema seguía activo, con su VCN, su bastión y sus tres
    millones de filas. Nadie se dio cuenta porque nada falla cuando esto pasa: lo
    único que ocurre es que el crédito baja. Por eso el último paso de este
    capítulo no es borrar, es **verificar** que se borró.

    La regla operativa es simple: **si no va a tocar el laboratorio en las próximas
    horas, bórrelo.** Volver a crearlo cuesta veinte minutos de espera y cero
    dólares de atención.

### 19.1 El orden

| Orden | Recurso | Nota |
|---|---|---|
| 1 | Sesiones del bastión | Termine las sesiones activas antes de borrar el bastión |
| 2 | Clúster de HeatWave | Solo camino A. Se borra desde el detalle del DB System |
| 3 | **DB System de MySQL** | El caro. Tarda varios minutos; no interrumpir |
| 4 | Bastión | Ya sin sesiones |
| 5 | Objetos del bucket, y luego el bucket | Un bucket con objetos no se borra |
| 6 | Subred | Después de que no queden VNIC en ella |
| 7 | Security list, tabla de rutas, service gateway | En cualquier orden entre sí |
| 8 | VCN | Última |

### 19.2 Los pasos

1. **Sesiones del bastión.** Vaya a `Identity & Security › Bastion › lab04bastion ›
   Sessions` y termine cada sesión activa desde su menú de acciones.
2. **Clúster de HeatWave** (camino A). Entre al detalle de `lab04-documentos`, vaya a
   la sección de HeatWave y borre el clúster. Espere a que desaparezca.
3. **DB System.** En el detalle de `lab04-documentos`, use la acción de borrado. La
   consola preguntará qué hacer con los respaldos y con la protección de borrado; si
   siguió el capítulo 8, la protección está desactivada y no hay respaldos
   automáticos que retener. **Confirme que no se retiene ningún respaldo final**: un
   respaldo huérfano sigue consumiendo almacenamiento y sigue cobrando. El borrado
   tarda varios minutos.
4. **Bastión.** Bórrelo desde su página de detalle.
5. **Bucket.** Entre a `lab04-datos`, borre `documentos.csv` y luego el bucket. Un
   bucket con objetos dentro no se deja borrar; el mensaje de error lo dice, pero es
   fácil pasarlo por alto.
6. **Subred.** Bórrela desde la VCN. Si se niega, es porque todavía queda una VNIC:
   revise que el DB System y el endpoint del bastión hayan terminado de borrarse.
7. **Security list, tabla de rutas y service gateway.** Bórrelos desde el panel de
   recursos de la VCN.
8. **VCN.** La consola ofrece una acción de borrado que arrastra los recursos
   dependientes que queden. Úsela al final.

### 19.3 Verificar que quedó limpio

> CONSOLA: Billing & Cost Management › Cost Analysis

1. Filtre por la etiqueta `Taller = 04-datos-analitica`.
2. Revise los dos días siguientes al borrado. El consumo debe caer a cero.

Los datos de consumo **tardan horas en consolidar**, así que la cifra del mismo día no
sirve para concluir nada. Por eso vale la pena la comprobación directa:

```bash
# Debe devolver una lista vacía, o solo elementos en estado DELETED
oci mysql db-system list --compartment-id "$COMP" \
  --query 'data[].{nombre:"display-name",estado:"lifecycle-state"}' --output table

oci bastion bastion list --compartment-id "$COMP" \
  --query 'data[].{nombre:name,estado:"lifecycle-state"}' --output table
```

Para referencia de orden de magnitud: en el ensayo, el conjunto completo de
laboratorios de la jornada proyectaba **2,10 USD** contra un presupuesto de 150, con
0,13 USD de cómputo ya consolidados al momento de medir. El sistema de base de datos
de este laboratorio es el rubro dominante de esa cifra. [VALIDAR el costo exacto
contra Cost Analysis una vez consolidado, que puede tardar más de un día]

---

## 20. Documentación oficial

Las rutas profundas de la documentación de Oracle cambian con frecuencia. Estos son
los puntos de entrada por servicio, que son estables.

| Tema | Enlace |
|---|---|
| MySQL HeatWave en OCI (servicio completo) | https://docs.oracle.com/en-us/iaas/mysql-database/index.html |
| Redes virtuales (VCN, subredes, rutas) | https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/overview.htm |
| Security lists | https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securitylists.htm |
| Service Gateway | https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/servicegateway.htm |
| OCI Bastion | https://docs.oracle.com/en-us/iaas/Content/Bastion/home.htm |
| Object Storage | https://docs.oracle.com/en-us/iaas/Content/Object/home.htm |
| Compartimentos y políticas | https://docs.oracle.com/en-us/iaas/Content/Identity/home.htm |
| Límites de servicio y cuotas | https://docs.oracle.com/en-us/iaas/Content/General/Concepts/servicelimits.htm |
| Facturación, costo y presupuestos | https://docs.oracle.com/en-us/iaas/Content/Billing/home.htm |
| MySQL Shell — utilidad de importación paralela de tablas | https://dev.mysql.com/doc/mysql-shell/8.0/en/mysql-shell-utilities-parallel-table.html |
| MySQL Shell (manual completo) | https://dev.mysql.com/doc/mysql-shell/8.0/en/ |

---

## Anexo · El laboratorio sin OCI

Si el límite de servicio de MySQL está en cero, si el crédito no alcanza o si
simplemente quiere preparar el trabajo de datos sin gastar nada, todo el contenido de
los capítulos 13 a 16 funciona igual contra un MySQL local:

```bash
docker run --name lab04 -e MYSQL_ROOT_PASSWORD=lab04 -p 3306:3306 -d mysql:8.4
sleep 40
docker exec -i lab04 mysql -uroot -plab04 < esquema.sql
docker exec -i lab04 mysql -uroot -plab04 --local-infile=1 operacion \
  -e "LOAD DATA LOCAL INFILE '/dev/stdin' INTO TABLE documentos
      FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';" < documentos.csv

python medir_consultas.py --usuario root --password lab04 --acelerador no
python tablero.py
```

Mismas consultas, mismo tablero, mismos dos hallazgos, cero crédito. Lo único que no
existe en este camino es la comparación entre motores — y en ese caso se dice tal
cual, sin estimarla.

Lo que sí se pierde, y conviene tenerlo presente, es todo el capítulo de red: la base
sin dirección pública, el aislamiento de la subred, el Service Gateway y el bastión.
Ese es justamente el contenido que este manual existe para enseñar, así que el camino
local sirve para preparar el trabajo de datos, no para sustituir el laboratorio.
