output "lb_ip" {
  description = "IP del balanceador CON WAF. Es la segunda de la demo del borde."
  value       = oci_load_balancer_load_balancer.app.ip_address_details[0].ip_address
}

output "lb_url" {
  value = "http://${oci_load_balancer_load_balancer.app.ip_address_details[0].ip_address}"
}

output "bastion_id" {
  value = oci_bastion_bastion.admin.id
}

output "bastion_endpoint_ip" {
  description = "IP privada del endpoint del bastión: la única fuente permitida hacia el 22."
  value       = oci_bastion_bastion.admin.private_endpoint_ip_address
}

output "instancia_ids" {
  value = oci_core_instance.app[*].id
}

output "instancia_ips_privadas" {
  description = "Sin IP pública, por diseño."
  value       = oci_core_instance.app[*].private_ip
}

output "waf_id" {
  value = oci_waf_web_app_firewall.app.id
}

output "compartment_ocid" {
  value = var.compartment_ocid
}

output "topic_alertas_id" {
  value = oci_ons_notification_topic.alertas.id
}
