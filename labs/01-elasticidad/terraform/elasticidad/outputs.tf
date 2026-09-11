output "lb_url" {
  description = "URL pública del balanceador. Es la que se proyecta durante la demo."
  value       = "http://${oci_load_balancer_load_balancer.app.ip_address_details[0].ip_address}"
}

output "lb_ip" {
  value = oci_load_balancer_load_balancer.app.ip_address_details[0].ip_address
}

output "instance_pool_id" {
  description = "Lo usan los scripts de observación."
  value       = oci_core_instance_pool.app.id
}

output "load_balancer_id" {
  value = oci_load_balancer_load_balancer.app.id
}

output "backend_set_name" {
  value = oci_load_balancer_backend_set.app.name
}

output "autoscaling_configuration_id" {
  value = oci_autoscaling_auto_scaling_configuration.app.id
}

output "compartment_ocid" {
  value = var.compartment_ocid
}

output "resumen_demo" {
  description = "Recordatorio de la configuración con la que se está demostrando."
  value = format(
    "Pool %d-%d | scale-out CPU>%d%% (+%d) | scale-in CPU<%d%% (-%d) | cooldown %ds | shape %s %d OCPU",
    var.pool_min, var.pool_max,
    var.scale_out_threshold, var.scale_out_step,
    var.scale_in_threshold, var.scale_in_step,
    var.cooldown_seconds, var.shape, var.ocpus
  )
}
