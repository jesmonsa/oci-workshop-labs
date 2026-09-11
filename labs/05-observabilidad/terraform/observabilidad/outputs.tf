output "topic_id" {
  value = oci_ons_notification_topic.operacion.id
}

output "alarma_cpu_id" {
  value = oci_monitoring_alarm.cpu_saturacion.id
}

output "alarma_backends_id" {
  value = oci_monitoring_alarm.backends_caidos.id
}

output "compartment_ocid" {
  value = var.compartment_ocid
}

output "suscripciones_pendientes" {
  description = "Recordatorio: hasta que no se confirme cada correo, no llega ninguna alarma."
  value = format(
    "%d suscripcion(es) creada(s). Confirmar desde el correo ANTES de la sesion.",
    length(var.correos_destino)
  )
}

output "resumen" {
  value = format(
    "CPU > %d%% sostenido %s (WARNING) · backends no saludables > 0 en PT2M (CRITICAL)",
    var.umbral_cpu, var.duracion_pendiente
  )
}
