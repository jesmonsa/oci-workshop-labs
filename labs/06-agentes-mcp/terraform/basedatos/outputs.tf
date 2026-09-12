output "adb_ocid" {
  description = "Identificador de la base. Lo usan los scripts para descargar el wallet."
  value       = oci_database_autonomous_database.lab.id
}

output "db_name" {
  value = oci_database_autonomous_database.lab.db_name
}

output "estado" {
  value = oci_database_autonomous_database.lab.state
}

output "nivel_gratuito" {
  value = oci_database_autonomous_database.lab.is_free_tier
}

output "consola_del_servicio" {
  description = "Consola de la base, para administrarla desde el navegador."
  value       = oci_database_autonomous_database.lab.service_console_url
}

output "servicios_de_conexion" {
  description = <<-EOT
    Nombres de servicio disponibles. Para el laboratorio se usa el terminado en
    _low: el agente hace consultas cortas, no cargas analíticas.
  EOT
  value       = [for c in oci_database_autonomous_database.lab.connection_strings[0].profiles : c.display_name]
}

output "siguiente_paso" {
  value = <<-EOT
    1. Descargar el wallet y guardar la conexión:  ./scripts/10-preparar-conexion.sh
    2. Cargar el esquema de ejemplo:               ./scripts/20-cargar-esquema.sh
    3. Ver qué expone el servidor MCP:             ./scripts/30-inspeccionar-mcp.sh
  EOT
}
