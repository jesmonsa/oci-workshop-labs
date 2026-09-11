output "mysql_ip_privada" {
  description = "La base no tiene endpoint público. Se llega por el bastión."
  value       = oci_mysql_mysql_db_system.documentos.ip_address
}

output "mysql_db_system_id" {
  value = oci_mysql_mysql_db_system.documentos.id
}

output "bastion_id" {
  value = oci_bastion_bastion.datos.id
}

output "bastion_endpoint_ip" {
  value = oci_bastion_bastion.datos.private_endpoint_ip_address
}

output "acelerador_activo" {
  value = var.crear_cluster_heatwave
}

output "compartment_ocid" {
  value = var.compartment_ocid
}

output "comando_tunel" {
  description = "Recordatorio del túnel: crear la sesión con scripts/10-tunel-mysql.sh."
  value = format(
    "./scripts/10-tunel-mysql.sh  # abre 127.0.0.1:3306 -> %s:3306 vía bastión",
    oci_mysql_mysql_db_system.documentos.ip_address
  )
}
