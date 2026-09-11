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
# Laboratorio de datos del módulo 4.
#
# Es autocontenido a propósito: su propia VCN, su propia subred privada y su
# propio bastión. No depende del laboratorio del módulo 2, para que se pueda
# levantar y destruir sin afectar la demo de seguridad.
#
# La base NO tiene endpoint público (control D-01 del módulo 2). Se llega a ella
# por reenvío de puerto a través del bastión, que es exactamente el patrón que se
# demostró en la preparación.
# -----------------------------------------------------------------------------

locals {
  tags = {
    "Proyecto" = "TallerOCI"
    "Modulo"   = "04-datos-analitica"
    "Owner"    = var.owner
    "Efimero"  = "si"
  }
  prefix   = "lab04"
  vcn_cidr = "10.60.0.0/16"
  subred   = "10.60.1.0/24"
  ad_name  = data.oci_identity_availability_domains.ads.availability_domains[var.ad_index].name
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_services" "todos" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# --- Red mínima: una subred privada y salida solo hacia servicios de OCI ------

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-vcn"
  cidr_blocks    = [local.vcn_cidr]
  dns_label      = "lab04"
  freeform_tags  = local.tags
}

resource "oci_core_default_security_list" "default" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id
  display_name               = "${local.prefix}-sl-default-endurecida"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    source   = local.vcn_cidr
    protocol = "all"
  }

  freeform_tags = local.tags
}

resource "oci_core_service_gateway" "sgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-sgw"

  services {
    service_id = data.oci_core_services.todos.services[0].id
  }

  freeform_tags = local.tags
}

# La base necesita alcanzar Object Storage para importar los datos: eso va por el
# Service Gateway, sin pasar por internet.
resource "oci_core_route_table" "privada" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-rt-privada"

  route_rules {
    destination       = data.oci_core_services.todos.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.sgw.id
  }

  freeform_tags = local.tags
}

resource "oci_core_subnet" "datos" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = local.subred
  display_name               = "${local.prefix}-subnet-privada-datos"
  dns_label                  = "datos"
  route_table_id             = oci_core_route_table.privada.id
  security_list_ids          = [oci_core_security_list.mysql.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.tags
}

# A diferencia de una instancia de cómputo, el sistema de base de datos administrado
# no admite NSGs: su control de acceso de red es la security list de la subred.
#
# El origen permitido es el CIDR de la subred y no la IP exacta del endpoint del
# bastión, porque esa IP solo existe después de crear el bastión, que a su vez vive
# en esta subred: referenciarla aquí crearía un ciclo. En esta subred solo hay dos
# cosas —la base y el endpoint del bastión—, así que el alcance real es el mismo.
resource "oci_core_security_list" "mysql" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-sl-mysql"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # 3306 (protocolo clásico) y 33060 (protocolo X, el que usa mysqlsh).
  dynamic "ingress_security_rules" {
    for_each = toset([3306, 33060])
    content {
      source      = local.subred
      protocol    = "6"
      description = "MySQL solo desde dentro de la subred (endpoint del bastion)"

      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  freeform_tags = local.tags
}

resource "oci_bastion_bastion" "datos" {
  bastion_type                 = "STANDARD"
  compartment_id               = var.compartment_ocid
  target_subnet_id             = oci_core_subnet.datos.id
  name                         = "lab04bastion"
  client_cidr_block_allow_list = var.ips_admin_cidr
  max_session_ttl_in_seconds   = 10800
  freeform_tags                = local.tags
}

# --- Base de datos administrada ----------------------------------------------

resource "oci_mysql_mysql_db_system" "documentos" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_name
  subnet_id           = oci_core_subnet.datos.id
  shape_name          = var.shape_mysql
  display_name        = "${local.prefix}-documentos"
  description         = "Laboratorio de analitica operacional - Taller de arquitectura en OCI"

  admin_username = var.admin_usuario
  admin_password = var.admin_password

  data_storage_size_in_gb = var.almacenamiento_gb
  is_highly_available     = false # un laboratorio no necesita alta disponibilidad

  # Respaldos apagados a propósito: es un laboratorio efímero y el crédito del
  # trial es finito. En cualquier ambiente real esto va al revés — y esa diferencia
  # es justamente la conversación de «administrado vs. VM» del módulo 1.
  backup_policy {
    is_enabled = false
  }

  # Para que `terraform destroy` funcione sin dejar respaldos huérfanos consumiendo
  # crédito. En producción, exactamente al revés: protección de borrado activada y
  # respaldo final obligatorio.
  deletion_policy {
    automatic_backup_retention = "DELETE"
    final_backup               = "SKIP_FINAL_BACKUP"
    is_delete_protected        = false
  }

  freeform_tags = local.tags
}

# --- Acelerador de analítica (opcional y apagado por defecto) -----------------
#
# El clúster de HeatWave es lo que convierte consultas analíticas de minutos en
# segundos, y es un costo aparte del sistema de base de datos. Se crea solo si
# los límites y el crédito del trial lo permiten: revisar ANTES de activarlo.
#
# Sin él, el laboratorio sigue funcionando y la demo también: lo que se pierde es
# la comparación de tiempos, que entonces NO se presenta con cifras inventadas.

resource "oci_mysql_heat_wave_cluster" "acelerador" {
  count = var.crear_cluster_heatwave ? 1 : 0

  db_system_id         = oci_mysql_mysql_db_system.documentos.id
  cluster_size         = var.tamano_cluster_heatwave
  shape_name           = var.shape_heatwave
  is_lakehouse_enabled = false
}
