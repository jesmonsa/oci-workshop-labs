terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  region              = var.region
  config_file_profile = var.config_file_profile != "" ? var.config_file_profile : null
}

# -----------------------------------------------------------------------------
# Observabilidad sobre el laboratorio del módulo 1.
#
# No crea infraestructura nueva: se monta encima del pool de instancias y del
# balanceador que ya existen. Por eso recibe sus OCIDs como variables en lugar de
# leer el estado del otro laboratorio — así los dos se pueden levantar, destruir y
# volver a levantar sin arrastrarse el uno al otro.
#
# La idea que se demuestra: la MISMA métrica que en la preparación disparó el autoescalamiento
# es la que aquí se convierte en alarma con umbral, destinatario y acción. Una señal
# no es una alarma hasta que alguien decide qué hacer cuando suena.
# -----------------------------------------------------------------------------

locals {
  tags = {
    "Proyecto" = "TallerOCI"
    "Modulo"   = "05-observabilidad"
    "Owner"    = var.owner
    "Efimero"  = "si"
  }
  prefix = "lab05"
}

# --- A quién le llega -------------------------------------------------------

resource "oci_ons_notification_topic" "operacion" {
  compartment_id = var.compartment_ocid
  name           = "${local.prefix}-alarmas-operacion"
  description    = "Alarmas de plataforma - Taller de arquitectura en OCI módulo 5"
  freeform_tags  = local.tags
}

# La suscripción queda PENDING hasta hacer clic en el correo de confirmación.
# Sin ese clic no llega ninguna alarma, y es el error más común de la primera vez.
resource "oci_ons_subscription" "correo" {
  for_each = toset(var.correos_destino)

  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.operacion.id
  protocol       = "EMAIL"
  endpoint       = each.value
}

# --- Alarma 1: saturación de cómputo ----------------------------------------
#
# Es la alarma de la demo. El generador de carga del módulo 1 la hace sonar en
# unos minutos... y el autoescalamiento la apaga sola poco después.
#
# Ese ciclo completo —suena, la plataforma reacciona, se cierra— es justamente lo
# que hay que saber distinguir: si se resuelve sola, no despierta a nadie, pero sí
# queda registrada. Ver docs/01-GUION-40MIN.md, minuto 12.

resource "oci_monitoring_alarm" "cpu_saturacion" {
  compartment_id        = var.compartment_ocid
  display_name          = "${local.prefix}-saturacion-cpu"
  destinations          = [oci_ons_notification_topic.operacion.id]
  is_enabled            = true
  metric_compartment_id = var.compartment_laboratorio
  namespace             = "oci_computeagent"
  query                 = "CpuUtilization[1m].mean() > ${var.umbral_cpu}"
  severity              = "WARNING"
  resolution            = "1m"

  # Cuánto tiene que sostenerse antes de sonar. Sin esto, cualquier pico de treinta
  # segundos genera un correo, y en dos semanas nadie los lee.
  pending_duration = var.duracion_pendiente

  # Recordatorio cada 30 minutos mientras siga activa. Más frecuente cansa; menos,
  # deja que algo se olvide durante un turno entero.
  repeat_notification_duration = "PT30M"

  message_format = "ONS_OPTIMIZED"
  body           = <<-EOT
    La CPU del servicio superó el ${var.umbral_cpu} % durante ${var.duracion_pendiente}.

    QUE HACER (runbook): ${var.url_runbook_cpu}

    Antes de escalar manualmente, mirar DOS cosas:

    1. Si los backends responden. Si el servicio no se degrado, esto no es una
       urgencia: la plataforma esta absorbiendo la rafaga.
    2. Si el grupo llego a su tamano maximo. Esa es la senal que importa, porque
       significa que ya no queda margen para crecer.

    Esta alarma NO se cierra porque entre capacidad: medido, con la carga puesta
    el grupo crecio hasta su maximo y siguio sonando 35 minutos. Se cierra cuando
    baja la demanda. Mas capacidad no baja la utilizacion, sube el rendimiento.
  EOT

  freeform_tags = local.tags
}

# --- Alarma 2: el usuario lo está sintiendo ---------------------------------
#
# La anterior es una causa; esta es un síntoma. Si hay backends caídos, el usuario
# ya lo está notando. Por eso su severidad es mayor aunque el número sea más chico:
# la severidad la define el impacto, no la magnitud de la métrica.

resource "oci_monitoring_alarm" "backends_caidos" {
  compartment_id        = var.compartment_ocid
  display_name          = "${local.prefix}-backends-no-saludables"
  destinations          = [oci_ons_notification_topic.operacion.id]
  is_enabled            = true
  metric_compartment_id = var.compartment_laboratorio
  namespace             = "oci_lbaas"
  query                 = "UnHealthyBackendServers[1m].max() > 0"
  severity              = "CRITICAL"
  resolution            = "1m"
  pending_duration      = "PT2M"

  message_format = "ONS_OPTIMIZED"
  body           = <<-EOT
    Hay servidores detras del balanceador que no pasan la verificacion de salud.
    El usuario final puede estar viendo errores o lentitud.

    QUE HACER (runbook): ${var.url_runbook_backends}
  EOT

  freeform_tags = local.tags
}

# -----------------------------------------------------------------------------
# Verificar los nombres de métrica ANTES del primer apply: cambian entre servicios
# y una alarma sobre una métrica inexistente se crea sin error y nunca suena — que
# es la peor forma de fallar, porque parece que funciona.
#
#   oci monitoring metric list --compartment-id <comp> --namespace oci_computeagent \
#     --query 'data[].name' --output table
#   oci monitoring metric list --compartment-id <comp> --namespace oci_lbaas \
#     --query 'data[].name' --output table
#
# La comprobación real es scripts/20-estado-alarmas.sh, que muestra si cada alarma
# está recibiendo datos o si está "sin datos" — que no es lo mismo que "todo bien".
# -----------------------------------------------------------------------------
