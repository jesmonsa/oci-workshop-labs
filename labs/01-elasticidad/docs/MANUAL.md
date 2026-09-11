# Manual paso a paso — construcción del laboratorio

Todo lo de este manual se ejecuta en el **tenancy del SE Trial**, nunca en un ambiente
de la organización. Tiempo estimado de la primera pasada completa: **2,5 a 3 horas**, incluyendo
esperas de provisión.

Al terminar tendrás: un balanceador público, un pool de 2 instancias que crece a 6 bajo
carga y vuelve a bajar solo, y evidencia medida de cuánto tarda cada paso.

---

## Paso 0 · Antes de tocar nada (D-7)

### 0.1 Abrir el trial y anotar lo que caduca

Registra en `evidencias/00-trial.md`:

| Dato | Valor |
|---|---|
| Fecha de activación | |
| Fecha de expiración | |
| Crédito otorgado (USD) | |
| Región home | |
| Regiones suscritas | |

> El crédito y la fecha son el presupuesto real del ejercicio. Todo lo demás se
> subordina a esos dos números.

### 0.2 Instalar y configurar herramientas

```bash
# OCI CLI
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"

# Terraform >= 1.5 (Windows: winget install HashiCorp.Terraform)
terraform -version

# Configurar credenciales: genera el par de llaves y sube la pública en
# Identity > Users > tu usuario > API Keys
oci setup config
```

Verificación:

```bash
oci iam region-subscription list --output table
```

Si esto falla, nada de lo que sigue funciona. Corrígelo antes de continuar.

### 0.3 Crear el compartment

> **Actualización 11-sep:** si vas a preparar también el módulo 2, crea primero un
> compartment padre `lab` y cuelga de él `lab-01-elasticidad`, `lab-02-seguridad` y
> `lab-02-zona-segura`. Así un solo presupuesto cubre todo. Ver el paso 0 de
> `../../02-seguridad/docs/02-MANUAL-PASO-A-PASO.md`. Si ya creaste `lab-01-elasticidad` en la
> raíz, no pasa nada: se puede mover con `oci iam compartment move`.

```bash
oci iam compartment create \
  --compartment-id "<OCID-del-tenancy>" \
  --name "lab-01-elasticidad" \
  --description "Laboratorio Taller de arquitectura en OCI - módulo 1" \
  --freeform-tags '{"Proyecto":"TallerOCI","Modulo":"01-elasticidad","Efimero":"si"}'
```

Guarda el OCID que devuelve: lo usarás en `terraform.tfvars`.

> **Por qué un compartment aparte y no el raíz:** el filtro de costo, el presupuesto y
> el borrado masivo del final dependen de esa separación. Es también el primer patrón
> de FinOps que se menciona en la sesión.

### 0.4 Verificar límites de servicio — *el paso que más gente se salta*

```bash
./scripts/00-prereqs.sh | tee evidencias/00-prereqs-$(date +%F).txt
```

Y en la consola: **Governance & Administration → Limits, Quotas and Usage**.
Confirma que hay cupo para el shape elegido, para balanceador flexible y para
instance pool.

> **Si algún límite está en 0, solicita el aumento hoy.** La aprobación no es
> instantánea y en la preparación ya es tarde. Este es, con diferencia, el motivo más común
> por el que un laboratorio sobre trial no llega a la fecha.

### 0.5 Poner el presupuesto ANTES de crear recursos

```bash
cd terraform/finops
cat > terraform.tfvars <<'FIN'
tenancy_ocid      = "ocid1.tenancy.oc1..<el-tuyo>"
compartment_ocid  = "ocid1.compartment.oc1..<lab-01-elasticidad>"
region            = "us-ashburn-1"
monto_presupuesto = 150
email_alertas     = "tu.correo@oracle.com"
FIN

terraform init
terraform apply
```

Esta pantalla se muestra en la demo. Es el ejemplo más barato de FinOps que existe:
un control que se activa en cinco minutos y avisa antes de que el gasto ocurra.

---

## Paso 1 · Desplegar el laboratorio de elasticidad (D-6)

### 1.1 Preparar variables

```bash
cd terraform/elasticidad
cp terraform.tfvars.example terraform.tfvars

# Datos que necesitas a mano:
cat ~/.ssh/id_rsa.pub    # llave pública -> ssh_public_key
curl -s ifconfig.me      # tu IP        -> mi_ip_cidr (agregar /32)
```

Edita `terraform.tfvars` con tus OCIDs, región, llave e IP.

> **`mi_ip_cidr` no debe quedar en `0.0.0.0/0`.** Un laboratorio con SSH abierto al
> mundo, mostrado en una sesión donde el siguiente bloque es de seguridad, es un
> autogol. Y en un trial nuevo los escaneos empiezan en minutos.

### 1.2 Aplicar

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=lab.tfplan
terraform apply lab.tfplan
```

Tiempo típico: 5–8 minutos (el balanceador es lo más lento).

### 1.3 Verificar que la aplicación responde

```bash
LB=$(terraform output -raw lb_ip)
echo "http://$LB"

curl -s "http://$LB/health"     # -> ok
curl -s "http://$LB/"           # -> muestra el host que atendió
curl -s "http://$LB/" ; curl -s "http://$LB/"   # el hostname debe alternar
```

**Si el health check no pasa** (backends en `CRITICAL`), en orden:

| Síntoma | Causa probable | Verificación |
|---|---|---|
| Backend `CRITICAL`, instancia `RUNNING` | firewalld bloqueando el 80 | `ssh opc@<ip>` y `sudo firewall-cmd --list-ports` |
| Ninguna instancia responde | cloud-init falló | `sudo cat /var/log/cloud-init-output.log` |
| Servicio caído | `lab-app.service` no arrancó | `sudo systemctl status lab-app` |
| Timeout desde tu equipo | security list | Revisar regla de ingreso al 80 |

### 1.4 Confirmar que existen métricas

Consola: **Observability & Management → Monitoring → Metrics Explorer**
Namespace `oci_computeagent`, métrica `CpuUtilization`, agrupado por `resourceId`.

> **Si no aparece nada, el autoescalamiento nunca va a disparar.** El plugin de
> monitoreo del agente debe estar habilitado (ya viene así en `compute.tf`) y las
> instancias tardan unos minutos tras el arranque en publicar la primera métrica.
> Espera 5–10 minutos antes de concluir que algo está mal.

---

## Paso 2 · Medir el ciclo real de escalamiento (D-6) — *el paso que define el guion*

Este es el paso más importante de toda la preparación. Sin estos números no puedes
cronometrar la demo ni decidir si se hace en vivo.

En **tres terminales simultáneas**:

```bash
# Terminal 1 — observador
cd scripts
./20-observar.sh \
  "$(cd ../terraform/elasticidad && terraform output -raw instance_pool_id)" \
  "$(cd ../terraform/elasticidad && terraform output -raw load_balancer_id)" \
  "$(cd ../terraform/elasticidad && terraform output -raw backend_set_name)" \
  "$(cd ../terraform/elasticidad && terraform output -raw lb_ip)"

# Terminal 2 — carga
cd scripts
./10-carga.sh "$(cd ../terraform/elasticidad && terraform output -raw lb_ip)" 40 400

# Terminal 3 — cronómetro y notas
date '+%H:%M:%S inicio de carga'
```

Llena esta tabla en `evidencias/tiempos-elasticidad.md`:

| Evento | Hora | Δ desde inicio de carga |
|---|---|---|
| Inicio de la carga | | 0 |
| CPU del pool supera el umbral en Metrics Explorer | | |
| El pool cambia de tamaño (2 → 4) | | |
| Instancia nueva en estado `RUNNING` | | |
| Backend nuevo en estado `OK` en el balanceador | | |
| **Total: de carga a capacidad sirviendo tráfico** | | **← este número se dice en voz alta en la demo** |
| Se detiene la carga | | |
| Primer scale-in (6 → 5) | | |

> **Cómo leer el resultado.** Si el total da menos de ~8 minutos, la demo puede ir en
> vivo empezando la carga al minuto 8 del bloque. Si da más, se pre-calienta a las 14:45
> y en el bloque se muestra el ciclo ya en marcha. Esa decisión se toma con este número,
> no con optimismo.

Repite la medición **dos veces**. La primera pasada siempre incluye el arranque en frío
de la métrica y no es representativa.

### 2.1 Ajustes si el ciclo es muy lento para la demo

En `terraform.tfvars`, en este orden de preferencia:

1. `scale_out_threshold` de 55 a 45 — dispara antes.
2. `scale_out_step` de 2 a 3 — el cambio es más visible en pantalla.
3. `ocpus` de 1 a 1 con más hilos de carga — la CPU sube más rápido en máquinas pequeñas.
4. `cooldown_seconds` no bajar de 300: es el mínimo práctico y bajarlo produce oscilación,
   que es justamente el antipatrón que no quieres mostrar.

---

## Paso 3 · Escalamiento vertical, para tener el contraste (D-5)

Necesitas un número propio para la Decisión 1: cuánto cuesta en tiempo redimensionar
una VM.

```bash
# Crear una VM suelta (fuera del pool) para no romper la demo principal
oci compute instance launch \
  --compartment-id "<comp>" --availability-domain "<AD>" \
  --shape "VM.Standard.E4.Flex" \
  --shape-config '{"ocpus":1,"memoryInGBs":8}' \
  --image-id "<image>" --subnet-id "<subnet>" \
  --display-name "lab01-vertical" \
  --freeform-tags '{"Proyecto":"TallerOCI","Modulo":"01-elasticidad","Efimero":"si"}'
```

Luego, **cronometrando desde que lanzas el comando hasta que la máquina vuelve a
responder**, cambia el tamaño a 2 OCPUs:

```bash
date '+%H:%M:%S inicio resize'
oci compute instance update --instance-id "<id>" \
  --shape-config '{"ocpus":2,"memoryInGBs":16}' --force

# En otra terminal, medir cuándo vuelve a responder:
while ! curl -s --max-time 3 "http://<ip>/health" >/dev/null; do sleep 2; done
date '+%H:%M:%S vuelve a responder'
```

Anota la ventana en `evidencias/tiempos-vertical.md`. **Ese es el dato que sustenta la
Decisión 1**: escalar vertical cuesta minutos de servicio caído; escalar horizontal, no.

---

## Paso 4 · Servicio administrado vs. VM (D-5)

Aquí la comparación es de **esfuerzo operativo**, no de rendimiento. No hace falta
benchmark, y meterse en uno es la forma más rápida de perder el miércoles.

### 4.1 Lado administrado

Elige uno según lo que permitan el crédito y los límites:

- **MySQL HeatWave DB System** — más cercano al stack de la organización y alineado con la
  conversación que ya tiene el equipo en la cuenta. Es la opción preferida.
- **Autonomous Database** — alternativa si el crédito aprieta; tiene nivel Always Free.

Provisiona por consola (es más rápido que escribir Terraform para un recurso de un solo
uso) y **cronometra**.

### 4.2 Lado VM

Una VM y la base instalada a mano: paquete, inicialización, usuario, arranque,
configuración de respaldo con `cron`. Cronometra también.

### 4.3 Llenar la tabla que se proyecta en la sesión

Guarda en `evidencias/administrado-vs-vm.md`:

| Tarea | En VM | Administrado |
|---|---|---|
| Provisión inicial hasta "listo para conectar" | | |
| Configurar backup automático diario | | |
| Aplicar un parche de seguridad | | |
| Restaurar a un punto en el tiempo | | |
| Agregar una réplica de lectura | | |
| Escalar cómputo sin recrear | | |
| Quién responde a las 2 a.m. | Equipo de la organización | Oracle |

> **Sé honesto en las dos columnas.** El equipo de la organización opera infraestructura para
> terceros: es su negocio. Si inflas la columna de la VM, lo notan y pierdes el bloque
> entero. La tabla convence sola cuando los números son reales.

---

## Paso 5 · FinOps y la tabla de costo (D-4)

### 5.1 Verificar el showback por tag

Consola: **Billing & Cost Management → Cost Analysis**.
Filtra por tag `Proyecto = TallerOCI` y agrupa por `Service`.

> Necesita ~24 h de datos acumulados. Por eso los tags se aplicaron en la preparación y no el jueves.

### 5.2 Construir la comparación

En `evidencias/costo-comparativo.md`:

| Escenario | Cómputo | Balanceador | Total mes (USD) |
|---|---|---|---|
| A. 6 instancias fijas 24×7 | | | |
| B. 2 base + ráfaga a 6 durante 3 h/día | | | |
| **Diferencia** | | | |

Fuentes: consumo real observado en el trial + el **Cost Estimator** de OCI para la
extrapolación mensual. **Cita la fuente en la lámina.**

> **Lo que no se hace:** repetir el rango de "20–30% más eficiente que otras nubes"
> que se mencionó en la reunión del la fecha. El acta lo dejó marcado como punto de
> atención pendiente de validar. Aquí presentas *tu* medición, de *esta* configuración,
> en *esta* región, con fecha. Eso es más pequeño y muchísimo más creíble — y además
> abre la puerta al benchmark real, que es una de las líneas del backlog.

---

## Paso 6 · GitOps: el flujo que también se demuestra (D-4)

Si sobra tiempo en el bloque (o para el hands-on posterior), este flujo vale 3 minutos
y conecta directamente con lo que la organización ya hace con Terraform:

1. Crear una rama, cambiar `pool_max` de 6 a 8.
2. Abrir un PR → GitHub Actions ejecuta `fmt`, `validate` y `plan`, y publica el plan
   como comentario.
3. El plan se revisa como se revisa código.
4. Al hacer merge, el cambio se aplica.

El mensaje: *"la capacidad dejó de ser una decisión de consola y pasó a ser un cambio
revisable, con historial y con reversa."* Ver `.github/workflows/terraform-plan.yml`.

---

## Paso 7 · Cierre del día

```bash
./scripts/99-destroy.sh
```

Todos los días. Sin excepción. Se vuelve a levantar en 8 minutos con un `apply`,
y el crédito del trial no vuelve.

---

## Anexo · Comandos de rescate durante la sesión

```bash
# ¿Cuántas instancias hay ahora?
oci compute-management instance-pool get --instance-pool-id "$POOL" --query 'data.size'

# Forzar tamaño manualmente (si el autoescalamiento no coopera y hay público mirando)
oci compute-management instance-pool update --instance-pool-id "$POOL" --size 5 --force

# Deshabilitar el autoescalamiento para congelar el estado en pantalla
oci autoscaling configuration update --auto-scaling-configuration-id "$AS" --is-enabled false --force

# Salud de los backends
oci lb backend-health list --load-balancer-id "$LB" --backend-set-name "$BSET" --output table
```

> El comando de forzar tamaño es tu red de seguridad. Si a los 90 segundos el
> autoescalamiento no ha disparado, lo ejecutas y narras: *"les fuerzo el cambio para no
> gastarles el tiempo; el disparo automático lo vieron en la métrica."* Nadie lo nota, y
> es preferible a tres minutos de silencio frente a una pantalla que no cambia.
