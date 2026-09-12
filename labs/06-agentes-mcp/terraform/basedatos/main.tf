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
# Módulo 6 · Base de datos para el laboratorio de agentes.
#
# AUTOCONTENIDO: no depende de ningún otro módulo. Una sola Autonomous Database
# con endpoint público protegido por mTLS — sin VCN, sin bastión, sin red que
# mantener. El objetivo del módulo no es la infraestructura: es lo que un agente
# puede y no puede hacer contra ella.
#
# Con el nivel siempre gratuito activado (por defecto), esta base no consume
# crédito. Es el laboratorio más barato de toda la serie.
# -----------------------------------------------------------------------------

locals {
  tags = {
    "Proyecto" = "TallerOCI"
    "Modulo"   = "06-agentes-mcp"
    "Owner"    = var.owner
    "Efimero"  = "si"
  }
}

resource "oci_database_autonomous_database" "lab" {
  compartment_id = var.compartment_ocid
  db_name        = var.db_name
  display_name   = "lab06-agentes"
  db_workload    = "OLTP"
  admin_password = var.admin_password

  # El nivel siempre gratuito fija el tamaño: 1 OCPU y 20 GB. Por eso, cuando
  # está activo, no se envían compute_count ni data_storage_size_in_tbs — el
  # servicio los ignora o rechaza.
  is_free_tier   = var.usar_nivel_gratuito
  compute_model  = var.usar_nivel_gratuito ? null : "ECPU"
  compute_count  = var.usar_nivel_gratuito ? null : var.ecpus
  cpu_core_count = var.usar_nivel_gratuito ? 1 : null

  data_storage_size_in_tbs = var.usar_nivel_gratuito ? 1 : var.almacenamiento_tb
  is_auto_scaling_enabled  = false
  license_model            = var.usar_nivel_gratuito ? null : "LICENSE_INCLUDED"

  # mTLS obligatorio: para conectarse hace falta el wallet, no basta con la
  # contraseña. Es lo que permite dejar el endpoint público sin que eso sea una
  # imprudencia — y es la primera decisión de seguridad que se explica en el módulo.
  is_mtls_connection_required = true

  # Lista de IPs permitidas. Vacía = se acepta desde cualquier origen (siempre
  # con mTLS). Restringirla es el control adicional recomendado.
  whitelisted_ips = length(var.ips_permitidas) > 0 ? var.ips_permitidas : null

  freeform_tags = local.tags

  lifecycle {
    ignore_changes = [db_version]
  }
}
