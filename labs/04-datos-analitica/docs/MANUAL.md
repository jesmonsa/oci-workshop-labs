# Manual paso a paso — laboratorio de datos

Tiempo total de la primera pasada: **2 a 3 horas**, de las cuales buena parte son
esperas (el aprovisionamiento y la importación).

```
generar_datos.py ──► CSV ──► Object Storage ──► mysqlsh import ──► MySQL
                                                                      │
                                              medir_consultas.py ◄────┘
                                                      │
                                                 resultados.json
                                                      │
                                                 tablero.py ──► tablero.html
```

---

## Paso 0 · Decidir el camino

Ver `00-PLAN-DE-TRABAJO.md`, sección 1. Este manual cubre el camino **A/B** (en OCI).
El camino **C** (MySQL local) está en el anexo del final: mismos datos, mismas
consultas, mismo tablero.

Verificar antes de nada qué shapes hay en la región:

```bash
COMP="<ocid-lab-04-datos>"
oci mysql shape list --compartment-id "$COMP" --output table
oci mysql shape list --compartment-id "$COMP" --is-supported-for HEATWAVECLUSTER --output table
```

Si la segunda lista viene vacía, el acelerador no está disponible: camino B, y el
tablero lo dirá solo.

---

## Paso 1 · Desplegar

```bash
cd talleres/04-datos-analitica/terraform/heatwave
cp terraform.tfvars.example terraform.tfvars   # completar; el shape que sí exista
export TF_VAR_admin_password='...'             # la contraseña NUNCA en el tfvars
curl -s ifconfig.me                            # -> ips_admin_cidr

terraform init && terraform apply
```

**Tarda 15–25 minutos.** Se lanza y se hace otra cosa mientras (por ejemplo, generar
los datos del paso 2).

**Si el apply falla:**

| Error | Causa | Arreglo |
|---|---|---|
| Menciona `shape` inválido | El nombre no existe en la región | Paso 0 |
| `LimitExceeded` | Límite de MySQL del trial | Camino C |
| Menciona `admin_password` | No cumple la complejidad exigida | Mayúsculas, minúsculas, número y símbolo |
| Tarda más de 40 min | Suele terminar igual | Esperar antes de cancelar: un destroy a medias deja recursos sueltos |

---

## Paso 2 · Generar los datos

```bash
cd ../../datos
python generar_datos.py --filas 200000 --salida prueba.csv     # primero, prueba
python generar_datos.py --filas 3000000 --salida documentos.csv
```

Tres millones de filas ocupan cerca de 400 MB y tardan 2–4 minutos en generarse.

> **Los datos traen dos hallazgos plantados**: un cliente que se deteriora y un canal
> lento. No se anuncian en la sesión — la gracia es que la sala los encuentre. Ver el
> encabezado de `generar_datos.py`.

---

## Paso 3 · El túnel

La base no tiene endpoint público, igual que se predicó en la preparación. Se llega por el
bastión:

```bash
cd ../scripts
./10-tunel-mysql.sh
# y en OTRA terminal, el comando que imprime; dejarla abierta
```

Verificación:

```bash
mysqlsh --mysql -u admin -h 127.0.0.1 -P 3306 --sql -e "SELECT VERSION();"
```

Si no conecta, casi siempre es la IP: `curl -s ifconfig.me` contra `ips_admin_cidr`.

---

## Paso 4 · Cargar los datos

### 4.1 Crear el esquema

```bash
mysqlsh --mysql -u admin -h 127.0.0.1 -P 3306 --sql < ../datos/esquema.sql
```

### 4.2 Subir el CSV a Object Storage

```bash
oci os bucket create --compartment-id "$COMP" --name lab04-datos --public-access-type NoPublicAccess
oci os object put --bucket-name lab04-datos --file ../datos/documentos.csv --parallel-upload-count 4
```

### 4.3 Importar

La base alcanza Object Storage por el Service Gateway, sin salir a internet:

```bash
mysqlsh --mysql -u admin -h 127.0.0.1 -P 3306 -- util import-table \
  "documentos.csv" \
  --osBucketName=lab04-datos \
  --schema=operacion --table=documentos \
  --fieldsTerminatedBy="," \
  --threads=4 --bytesPerChunk=50M
```

> **No pasar `--linesTerminatedBy`.** El salto de línea ya es el valor por defecto, y
> escribirlo hace que la herramienta lo reciba literal y falle con *«Separators cannot
> be the same or be a prefix of another»*, que no dice nada de la causa real.
>
> Medido: 3 millones de filas (305 MB) se importan en **4 minutos** con 4 hilos sobre
> un shape MySQL.2, con el tráfico pasando por el túnel del bastión.

> Si `util import-table` no encuentra el bucket, la alternativa es importar desde el
> archivo local con `--local-infile` habilitado, que tarda más pero no depende de
> Object Storage.

Verificación — **hacerla siempre**, porque una importación a medias produce un tablero
convincente y equivocado:

```sql
SELECT COUNT(*) FROM operacion.documentos;
SELECT MIN(fecha_emision), MAX(fecha_emision) FROM operacion.documentos;
SELECT estado, COUNT(*) FROM operacion.documentos GROUP BY estado;
```

Lo esperado: el conteo coincide con las filas del CSV, el rango cubre seis meses hasta
hoy, y cerca del 94 % está en `ACEPTADO`.

### 4.4 Cargar en el acelerador (solo camino A)

```sql
ALTER TABLE operacion.documentos SECONDARY_ENGINE = RAPID;
ALTER TABLE operacion.documentos SECONDARY_LOAD;
```

---

## Paso 5 · Medir y construir el tablero

```bash
cd ../datos
pip install -r requirements.txt
python medir_consultas.py --usuario admin --password "$TF_VAR_admin_password"
python tablero.py --entrada resultados.json --salida tablero.html
```

El script detecta solo si hay acelerador; si no lo hay, lo dice y mide únicamente el
motor transaccional. **No estima el segundo número.**

### 5.1 Revisar el tablero con los ojos

Ábrelo y confirma que:

- [ ] Los cuatro indicadores de arriba tienen valores razonables.
- [ ] La gráfica de volumen muestra el patrón semanal y los picos de fin de mes.
- [ ] La tasa de rechazo agregada **no** muestra nada alarmante.
- [ ] La tabla de clientes en riesgo tiene al **cliente 47** de primero, en rojo.
- [ ] El canal **LOTE** aparece con el p95 más alto, muy por encima del API.
- [ ] La tabla de tiempos dice la verdad sobre el acelerador.

Si el cliente 47 no aparece, es porque la muestra es pequeña: la consulta exige más de
100 documentos en siete días. Con tres millones de filas aparece; con doscientas mil,
puede que no.

**Guarda una copia de este archivo.** Es el respaldo den la preparación.

---

## Paso 6 · Teardown

```bash
cd ../scripts && ./99-destroy.sh
```

El borrado del sistema de base de datos tarda varios minutos. No interrumpirlo.

---

## Anexo · Camino C: MySQL local, sin OCI

Sirve para preparar el bloque sin gastar crédito, y también como plan B den la preparación.

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

Todo funciona igual salvo la comparación de motores. Si el bloque se hace así, se dice
tal cual: *"esta corrida es sobre MySQL a secas; la comparación con el acelerador la
medimos con su carga real cuando ustedes quieran"*. Que, además, es una segunda reunión.
