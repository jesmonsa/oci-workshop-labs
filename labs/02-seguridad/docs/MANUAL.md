# Manual paso a paso — laboratorio de seguridad

Todo se ejecuta en el **tenancy del SE Trial**, nunca en un ambiente de la organización.
Primera pasada completa: **2 a 2,5 horas**, incluyendo esperas.

Al terminar tendrás: Cloud Guard activo, un laboratorio "después" (red en tres capas,
NSGs, WAF, Bastion, flow logs y alertas), una Security Zone que rechaza lo público y un
script de auditoría que se corre contra el laboratorio "antes" del módulo 1.

```
          ANTES (módulo 1)                          DESPUÉS (módulo 2)
  ┌──────────────────────────────┐      ┌────────────────────────────────────────┐
  │ subred pública               │      │ pública   [LB + WAF]  ← solo esto      │
  │  [LB sin WAF]                │      │               │ NSG: 80 solo desde LB  │
  │  [app-1 IP pública]          │      │ privada   [app-1] [app-2]  sin IP púb. │
  │  [app-2 IP pública]          │      │               │ NSG: 3306 solo desde app│
  │  SL default: 22 ← 0.0.0.0/0  │      │ privada   [datos]  sin ruta a internet │
  └──────────────────────────────┘      │ Bastion → 22 solo desde su endpoint    │
                                        │ Flow logs · alertas de cambios · CG    │
                                        └────────────────────────────────────────┘
```

---

## Paso 0 · Estructura de compartments (viernes)

Si el módulo 1 aún no tiene nada desplegado, conviene crear un compartment padre para que
el presupuesto y el filtro de costo cubran los dos talleres de una vez:

```bash
TENANCY="<ocid-del-tenancy>"
TAGS='{"Proyecto":"TallerOCI","Efimero":"si"}'

ODT=$(oci iam compartment create --compartment-id "$TENANCY" --name lab \
      --description "Taller de arquitectura en OCI - laboratorios" --freeform-tags "$TAGS" \
      --wait-for-state ACTIVE --query 'data.id' --raw-output)

for c in lab-01-elasticidad lab-02-seguridad lab-02-zona-segura; do
  oci iam compartment create --compartment-id "$ODT" --name "$c" \
    --description "Taller de arquitectura en OCI - $c" --freeform-tags "$TAGS" \
    --wait-for-state ACTIVE --query 'data.id' --raw-output
done
```

Guarda los cuatro OCIDs. Luego aplica `01-elasticidad/terraform/finops` pasando
**el OCID de `lab`** como `compartment_ocid`.

> Los compartments recién creados tardan unos minutos en propagarse. Si un `apply`
> inmediato falla con "compartment not found", espera dos minutos y reintenta.

---

## Paso 1 · Cloud Guard (viernes — no esperar)

Consola → **Identity & Security → Cloud Guard** → *Enable Cloud Guard*.

| Opción | Valor |
|---|---|
| Reporting region | La región home del trial (no se puede cambiar después) |
| Compartments to monitor | Tenancy raíz (cubre todo lo que cuelga de `lab`) |
| Configuration detector recipe | OCI Configuration Detector Recipe (Oracle managed) |
| Activity detector recipe | OCI Activity Detector Recipe (Oracle managed) |

El asistente crea las políticas de servicio que Cloud Guard necesita. Aceptarlas.

Verificación:

```bash
oci cloud-guard configuration get --compartment-id "$TENANCY" --query 'data.status'
# -> "ENABLED"
```

> **Por qué hoy y no en la preparación.** Cloud Guard evalúa los recursos cuando cambian y en
> barridos periódicos. Recursos creados en la preparación a las 9:00 pueden aparecer como problemas
> en minutos o en horas. Con Cloud Guard encendido desde en la preparación y el lab del módulo 1
> levantado en la preparación, tienes capturas seguras y, muy probablemente, problemas vivos en la preparación.

---

## Paso 2 · Laboratorio "antes" (sábado mañana)

Es el laboratorio del módulo 1, sin cambios. Ver `../01-elasticidad/docs/02-MANUAL-PASO-A-PASO.md`.
Solo asegúrate de dejarlo encendido unas horas en la preparación para que Cloud Guard lo vea.

---

## Paso 3 · Laboratorio "después" (sábado tarde)

### 3.1 Verificar las llaves de capacidad del WAF — *antes del primer apply*

```bash
for k in 941100 942100; do
  oci waf protection-capability list --compartment-id "$TENANCY" --key "$k" --all \
    --query 'data.items[].{llave:key,version:version,nombre:"display-name"}' --output table
done
```

Si ambas aparecen, sigue. Si alguna no aparece o la versión no es 1, ajusta
`waf_capacidades` y `waf_version_capacidad` en `terraform.tfvars`. Para explorar:

```bash
oci waf protection-capability list --compartment-id "$TENANCY" --all \
  --query 'data.items[?contains("display-name", `SQL`)].{llave:key,nombre:"display-name"}' --output table
```

### 3.2 Variables

```bash
cd talleres/02-seguridad/terraform/seguro
cp terraform.tfvars.example terraform.tfvars
curl -s ifconfig.me    # -> ips_admin_cidr = ["<esta-ip>/32"]
```

### 3.3 Aplicar

```bash
terraform init
terraform validate
terraform plan -out=seg.tfplan
terraform apply seg.tfplan
```

Tiempo típico: 8–12 minutos (el balanceador y el bastión son lo más lento).

**Si el apply falla:**

| Error | Causa | Arreglo |
|---|---|---|
| En `oci_waf_web_app_firewall_policy`, menciona *protection capability* | Llave o versión no válida en la región | Paso 3.1 |
| En `oci_waf_web_app_firewall_policy`, menciona *condition* | Sintaxis JMESPath de la regla `/admin` | `waf_bloquear_admin = false` y reaplicar. La demo pierde una fila, nada más. |
| En `oci_bastion_bastion`, *name* inválido | El nombre admite solo alfanuméricos | Ya viene como `lab02bastion`; no agregar guiones |
| *LimitExceeded* | Límites del trial | Bajar `num_instancias` a 1; si es el LB, destruir el del módulo 1 mientras pruebas |
| En `oci_events_rule` | Algún tipo de evento no reconocido | Quitar las líneas de NSG de la condición y dejar solo security lists e IAM |

### 3.4 Verificar

```bash
LB=$(terraform output -raw lb_ip)
curl -s "http://$LB/"          # responde, mostrando qué host atendió
terraform output instancia_ips_privadas    # solo IPs 10.40.2.x
```

En consola: **Networking → Load Balancers → lab02-lb → Backend sets**: los dos backends
deben estar en `OK`. Si están en `CRITICAL`, la causa casi siempre es una de estas:

| Síntoma | Causa | Verificación |
|---|---|---|
| Backends `CRITICAL` | NSG del LB sin salida hacia el NSG de la app | Revisar regla `lb_out_app` |
| Backends `CRITICAL` | firewalld en las instancias | Entrar por Bastion (paso 6) y `sudo firewall-cmd --list-ports` |
| Todo bien pero el WAF no bloquea | La política tarda unos minutos en propagarse | Esperar 5 min y repetir el paso 4 |

---

## Paso 4 · Prueba del WAF

```bash
cd ../../scripts
./20-prueba-waf.sh \
  "$(cd ../../01-elasticidad/terraform/elasticidad && terraform output -raw lb_ip)" \
  "$(cd ../terraform/seguro && terraform output -raw lb_ip)"
```

Resultado esperado: columna izquierda todo 200; columna derecha 200 solo en la normal.
**Captura de pantalla de la tabla** → `evidencias/`.

---

## Paso 5 · Security Zone (domingo)

Se hace por consola: es un recurso de configuración única y el asistente es más rápido
que escribirlo en Terraform.

1. **Identity & Security → Security Zones → Recipes → Create recipe**
   - Nombre: `lab02-receta-demo`
   - Compartment: `lab`
   - Políticas: marcar **solo** la de *denegar buckets públicos* (en la categoría de
     restricción de acceso público; el nombre exacto en consola es del estilo
     *Deny public buckets*) `[VALIDAR nombre exacto en consola]`.
   > **Por qué solo una.** La receta máxima de Oracle exige también llaves de Vault en
   > buckets y volúmenes. Con ella, *hasta el bucket privado* sería rechazado, y el mensaje
   > de la demo —"lo que cumple pasa, lo que no cumple no"— se pierde.

2. **Security Zones → Create Security Zone**
   - Nombre: `lab02-zona-demo`
   - Compartment: `lab-02-zona-segura`
   - Receta: `lab02-receta-demo`

3. Probar:
   ```bash
   ./40-prueba-security-zone.sh "<ocid-lab-02-zona-segura>"
   ```
   Esperado: el privado se crea, el público se rechaza citando la política.

---

## Paso 6 · Bastion (domingo)

El plugin de Bastion de la instancia tarda unos minutos después del arranque. Espera 10
minutos desde el `apply` antes de probar.

```bash
./30-sesion-bastion.sh 3600
# pegar el comando que imprime
```

Dentro de la instancia:

```bash
hostname
ip -4 addr show | grep inet
curl -s ifconfig.me
```

Si la sesión administrada falla, el script cae solo a *port forwarding*, que no depende
del plugin. Si ambos fallan: casi siempre es la IP. Compara `curl -s ifconfig.me` con
`ips_admin_cidr`.

---

## Paso 7 · Script de auditoría

```bash
./10-auditoria-rapida.sh "<ocid-lab-01-elasticidad>" "$TENANCY"   # el "antes": muchos hallazgos
./10-auditoria-rapida.sh "<ocid-lab-02-seguridad>" "$TENANCY"   # el "después": casi todo ok
```

Correr los dos es la mejor prueba de que el script funciona: debe encontrar problemas en
uno y no en el otro. Guarda ambas salidas (quedan en `evidencias/` automáticamente).

> **Qué se espera que encuentre en el módulo 1:** instancias con IP pública, subred
> pública, la security list **por defecto** de la VCN con el 22 abierto (aunque no esté
> asociada a ninguna subred), un balanceador sin WAF y sin TLS, y ningún flow log.
> En el nivel tenancy, dependerá del trial: MFA, retención de Audit, llaves API.

---

## Paso 8 · Alertas de cambios críticos

1. Confirmar la suscripción: llega un correo de OCI Notifications a `email_alertas`.
   **Sin ese clic, no llega ninguna alerta.**
2. Prueba: consola → la VCN `lab02-vcn` → *Default Security List* → agregar cualquier regla
   → guardar. El correo debe llegar en 1–2 minutos. Luego quitar la regla (o dejar que el
   próximo `terraform apply` la revierta, que además demuestra la deriva de configuración).

---

## Paso 9 · Cierre del día

```bash
./99-destroy.sh
```

Cloud Guard y la Security Zone se quedan (sin costo). El resto se destruye.

---

## Anexo · Comandos de rescate durante la sesión

```bash
# ¿Mi IP actual está permitida en el bastión?
curl -s ifconfig.me
oci bastion bastion get --bastion-id "$BASTION" --query 'data."client-cidr-block-allow-list"'

# Agregar la IP de la sala sin Terraform (30 segundos)
oci bastion bastion update --bastion-id "$BASTION" \
  --client-cidr-block-allow-list '["<ip-anterior>/32","<ip-sala>/32"]' --force

# ¿El WAF está activo?
oci waf web-app-firewall get --web-app-firewall-id "$(terraform output -raw waf_id)" \
  --query 'data."lifecycle-state"'

# Problemas de Cloud Guard en el compartment del módulo 1
oci cloud-guard problem list --compartment-id "$TENANCY" \
  --compartment-id-in-subtree true --access-level ACCESSIBLE --lifecycle-state ACTIVE --all \
  --query 'data.items[].{riesgo:"risk-level",problema:"detector-rule-id",recurso:"resource-name"}' --output table
```
