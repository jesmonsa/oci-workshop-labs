terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

# Autenticación:
#   - Local:       usa el perfil de ~/.oci/config indicado en var.config_file_profile.
#   - Cloud Shell: exportar TF_VAR_use_delegation_token=true, o correr con
#                  `export OCI_CLI_AUTH=instance_principal` según el caso.
provider "oci" {
  region              = var.region
  config_file_profile = var.config_file_profile != "" ? var.config_file_profile : null
}

locals {
  tags = {
    "Proyecto" = "TallerOCI"
    "Modulo"   = "01-elasticidad"
    "Owner"    = var.owner
    "Efimero"  = "si"
  }

  prefix   = "lab01"
  ad_name  = data.oci_identity_availability_domains.ads.availability_domains[var.ad_index].name
  image_id = data.oci_core_images.ol9.images[0].id
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Imagen más reciente de Oracle Linux 9 compatible con el shape elegido.
data "oci_core_images" "ol9" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
