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

locals {
  tags = {
    "Proyecto" = "TallerOCI"
    "Modulo"   = "02-seguridad"
    "Owner"    = var.owner
    "Efimero"  = "si"
  }

  prefix   = "lab02"
  ad_name  = data.oci_identity_availability_domains.ads.availability_domains[var.ad_index].name
  image_id = data.oci_core_images.ol9.images[0].id

  vcn_cidr     = "10.40.0.0/16"
  cidr_publica = "10.40.1.0/24" # solo el balanceador
  cidr_app     = "10.40.2.0/24" # aplicación, sin IP pública
  cidr_datos   = "10.40.3.0/24" # datos, sin IP pública y sin salida a internet
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ol9" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Todos los servicios de la región vía Service Gateway: el agente de cómputo y el
# plugin de Bastion hablan con OCI sin pasar por internet.
data "oci_core_services" "todos" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}
