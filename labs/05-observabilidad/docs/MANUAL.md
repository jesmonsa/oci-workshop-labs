# Manual paso a paso — alarmas y runbooks

No hay infraestructura nueva. Todo se monta encima del laboratorio del módulo 1.

---

## Paso 1 · Verificar los nombres de métrica (viernes)

```bash
COMP03="<ocid-lab-01-elasticidad>"

oci monitoring metric list --compartment-id "$COMP03" --namespace oci_computeagent \
  --query 'data[].name' --output table
oci monitoring metric list --compartment-id "$COMP03" --namespace oci_lbaas \
  --query 'data[].name' --output table
```

Deben aparecer `CpuUtilization` y `UnHealthyBackendServers`. Si alguna se llama
distinto en esta región, se ajusta la consulta en `main.tf`.

> **Por qué este paso primero.** Una alarma sobre una métrica que no existe se crea sin
> ningún error y nunca suena. En la consola se ve perfecta. Es la peor forma de fallar,
> porque parece que funciona.

Si el laboratorio del módulo 1 lleva poco tiempo arriba, puede que las métricas todavía
no estén publicadas. Esperar 10 minutos antes de concluir que algo está mal.

---

## Paso 2 · Aplicar

```bash
cd talleres/05-observabilidad/terraform/observabilidad
cp terraform.tfvars.example terraform.tfvars    # completar los dos compartments
terraform init && terraform apply
```

Tarda menos de un minuto: son tres recursos.

---

## Paso 3 · Confirmar la suscripción — *el paso que no se puede saltar*

Llega un correo de OCI Notifications con un enlace de confirmación. **Hacer clic.**

Verificación:

```bash
oci ons subscription list --compartment-id "$COMP07" \
  --query 'data[].{correo:endpoint,estado:"lifecycle-state"}' --output table
```

| Estado | Qué significa |
|---|---|
| `ACTIVE` | Listo, van a llegar las alarmas |
| `PENDING` | **No va a llegar nada.** Falta el clic |

Si el correo no aparece, revisar la carpeta de no deseados. Y si se va a proyectar la
bandeja de entrada en la preparación, vale la pena usar una cuenta pensada para eso.

---

## Paso 4 · Verificar que las alarmas ven datos

```bash
cd ../../scripts
./20-estado-alarmas.sh "$COMP07"
```

Tres estados posibles, y el tercero es el importante:

| Estado | Significa |
|---|---|
| `tranquila` | Recibe datos y la condición no se cumple |
| `DISPARADA` | La condición se cumple |
| **`SIN DATOS`** | **No está viendo nada.** No es calma: es ceguera |

Si aparece `SIN DATOS` después de diez minutos con el laboratorio arriba, revisar el
namespace, el nombre de la métrica y que `metric_compartment_id` apunte al compartment
del módulo 1 (no al del módulo 5).

---

## Paso 5 · Medir el ciclo completo (domingo)

Es el paso que define el guion den la preparación:

```bash
./10-probar-alarma.sh "$COMP07" "$(cd ../../01-elasticidad/terraform/elasticidad && terraform output -raw lb_ip)"
```

El script arranca la carga, vigila la alarma y anota en
`evidencias/tiempos-alarma.md`:

| Evento | Qué hacer con el número |
|---|---|
| La alarma dispara | Define en qué minuto del guion arrancar la carga |
| Llega el correo | Debe ser menos de un minuto después del disparo |
| La alarma se cierra sola | Es el momento didáctico del bloque |

**Ajustes si hace falta:**

| Síntoma | Ajuste |
|---|---|
| Tarda demasiado en sonar | Bajar `umbral_cpu` a 35, o `duracion_pendiente` a `PT2M` |
| Suena antes de que termines de explicar | Subir `umbral_cpu`, o arrancar la carga más tarde |
| Se cierra tan rápido que no se ve | Subir `repeat_notification_duration` no sirve; lo que sirve es arrancar la carga un poco antes y mostrar el correo primero |
| No se cierra nunca | El pool llegó a su tope: es otra conversación válida, y está en el runbook |

**Capturar el correo** con el enlace al runbook visible. Es la imagen del bloque.

---

## Paso 6 · Los runbooks

Los dos del repositorio están escritos para este laboratorio, pero la estructura es
lo que se lleva la organización:

- [`RUNBOOK-saturacion-cpu.md`](../runbooks/RUNBOOK-saturacion-cpu.md) — incluye la rama
  «esto se resuelve solo, regístralo y vuelve a dormir», que es la que casi nunca se
  escribe y la más valiosa.
- [`RUNBOOK-backends-caidos.md`](../runbooks/RUNBOOK-backends-caidos.md)
- [`PLANTILLA-RUNBOOK.md`](../runbooks/PLANTILLA-RUNBOOK.md) — con los seis criterios
  de un runbook que sirve.

Si el repositorio va a ser privado en la preparación, los enlaces del correo no van a abrir
frente al cliente. Dos opciones: subirlos a un lugar accesible, o proyectar el archivo
local y decir que en producción el enlace apunta al repositorio de ellos.

---

## Paso 7 · Teardown

```bash
cd ../terraform/observabilidad && terraform destroy
```

Las alarmas y el tema de notificación no tienen costo relevante, pero conviene borrarlos
igual: una alarma huérfana apuntando a un laboratorio que ya no existe queda en estado
«sin datos» para siempre, y es exactamente el antipatrón del que habla el bloque.

---

## Anexo · Qué falta para que esto sea un modelo completo

Lo que se demuestra es la cadena mínima: señal → umbral → destinatario → acción. Un
modelo completo de observabilidad para producción añade al menos:

| Pieza | Para qué |
|---|---|
| Registros centralizados y consultables | Bajar del síntoma al detalle sin entrar a cada máquina |
| Trazas distribuidas | Saber cuál de los servicios de una cadena es el lento |
| Prueba sintética desde fuera | Enterarse antes que el cliente (señal S-01) |
| Tablero ejecutivo | Un resumen que un directivo mire sin traducción |
| Revisión periódica de alarmas | Que la matriz no se vuelva obsoleta en seis meses |

Conviene decir esto en la sala, sin drama: lo que se muestra es el mínimo viable, y el
mínimo viable es justamente lo que se puede tener funcionando en dos semanas.
