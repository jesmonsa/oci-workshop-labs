# -----------------------------------------------------------------------------
# Red segmentada en tres capas. Es la versión "después" del laboratorio del módulo 1:
#
#   pública  10.40.1.0/24  -> solo el balanceador. Nada más tiene IP pública.
#   app      10.40.2.0/24  -> aplicación. Sale a internet por NAT, a OCI por Service Gateway.
#   datos    10.40.3.0/24  -> datos. Sin salida a internet en absoluto.
#
# Las reglas de tráfico viven en NSGs por función, no en security lists por subred.
# -----------------------------------------------------------------------------

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-vcn"
  cidr_blocks    = [local.vcn_cidr]
  dns_label      = "lab02"
  freeform_tags  = local.tags
}

# La security list por defecto que OCI crea con cada VCN trae el puerto 22 abierto a
# 0.0.0.0/0. Casi nadie lo revisa porque "no está asociada a nada" — hasta que alguien
# crea una subred sin especificar security list y la hereda. Aquí se toma control de
# ella y se deja solo lo imprescindible. Es el control R-02 del checklist.
resource "oci_core_default_security_list" "default" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id
  display_name               = "${local.prefix}-sl-default-endurecida"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Path MTU discovery. Quitarlo rompe conexiones de forma difícil de diagnosticar.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    source   = local.vcn_cidr
    protocol = "1"
    icmp_options {
      type = 3
    }
  }

  freeform_tags = local.tags
}

# --- Gateways ----------------------------------------------------------------

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-igw"
  enabled        = true
  freeform_tags  = local.tags
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-nat"
  freeform_tags  = local.tags
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

# --- Tablas de ruteo ---------------------------------------------------------

resource "oci_core_route_table" "publica" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-rt-publica"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }

  freeform_tags = local.tags
}

resource "oci_core_route_table" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-rt-app"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.nat.id
  }

  route_rules {
    destination       = data.oci_core_services.todos.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.sgw.id
  }

  freeform_tags = local.tags
}

# La capa de datos solo alcanza servicios de OCI (respaldos a Object Storage, etc.).
# No hay ruta a internet: una base de datos no necesita salir a navegar.
resource "oci_core_route_table" "datos" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-rt-datos"

  route_rules {
    destination       = data.oci_core_services.todos.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.sgw.id
  }

  freeform_tags = local.tags
}

# --- Subredes ----------------------------------------------------------------
# Ninguna declara security_list_ids: heredan la default ya endurecida. El filtrado
# real lo hacen los NSGs.

resource "oci_core_subnet" "publica" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = local.cidr_publica
  display_name               = "${local.prefix}-subnet-publica-lb"
  dns_label                  = "publica"
  route_table_id             = oci_core_route_table.publica.id
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.tags
}

resource "oci_core_subnet" "app" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = local.cidr_app
  display_name               = "${local.prefix}-subnet-privada-app"
  dns_label                  = "app"
  route_table_id             = oci_core_route_table.app.id
  prohibit_public_ip_on_vnic = true # la plataforma impide asignar IP pública aquí
  freeform_tags              = local.tags
}

resource "oci_core_subnet" "datos" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = local.cidr_datos
  display_name               = "${local.prefix}-subnet-privada-datos"
  dns_label                  = "datos"
  route_table_id             = oci_core_route_table.datos.id
  prohibit_public_ip_on_vnic = true
  freeform_tags              = local.tags
}

# --- NSGs por función --------------------------------------------------------
#
#   internet --80/443--> [nsg-lb] --80--> [nsg-app] --3306--> [nsg-datos]
#                                            ^
#                          bastión --22------'   (solo desde la IP del endpoint del bastión)

resource "oci_core_network_security_group" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-nsg-lb"
  freeform_tags  = local.tags
}

resource "oci_core_network_security_group" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-nsg-app"
  freeform_tags  = local.tags
}

resource "oci_core_network_security_group" "datos" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-nsg-datos"
  freeform_tags  = local.tags
}

# Balanceador: recibe de internet solo en 80 y 443.
resource "oci_core_network_security_group_security_rule" "lb_in_http" {
  for_each = toset(["80", "443"])

  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  description               = "HTTP/HTTPS publico hacia el balanceador"

  tcp_options {
    destination_port_range {
      min = tonumber(each.value)
      max = tonumber(each.value)
    }
  }
}

# Balanceador: solo puede hablar con la capa de aplicación, en el 80.
resource "oci_core_network_security_group_security_rule" "lb_out_app" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination_type          = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.app.id
  description               = "Balanceador hacia la app"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# App: recibe el 80 SOLO del NSG del balanceador. No de la subred, no de internet.
resource "oci_core_network_security_group_security_rule" "app_in_lb" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.lb.id
  description               = "Solo el balanceador llega a la app"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# App: el 22 existe, pero solo desde la IP privada del endpoint del bastión.
# Este es el mensaje del acceso administrativo: no se trata de cerrar el 22, sino
# de que solo exista un camino hacia él, con identidad, TTL y registro de auditoría.
resource "oci_core_network_security_group_security_rule" "app_in_bastion" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source_type               = "CIDR_BLOCK"
  source                    = "${oci_bastion_bastion.admin.private_endpoint_ip_address}/32"
  description               = "SSH solo desde el endpoint del bastion"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# Datos: el puerto de la base solo desde la app. En este laboratorio no se despliega
# base de datos; la regla está para que el diagrama de tres capas quede completo y
# se pueda mostrar en consola.
resource "oci_core_network_security_group_security_rule" "datos_in_app" {
  network_security_group_id = oci_core_network_security_group.datos.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.app.id
  description               = "MySQL solo desde la app"

  tcp_options {
    destination_port_range {
      min = 3306
      max = 3306
    }
  }
}
