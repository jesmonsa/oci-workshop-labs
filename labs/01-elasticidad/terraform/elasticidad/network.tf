resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-vcn"
  cidr_blocks    = ["10.30.0.0/16"]
  dns_label      = "lab01"
  freeform_tags  = local.tags
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-igw"
  enabled        = true
  freeform_tags  = local.tags
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-rt-public"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }

  freeform_tags = local.tags
}

# Subred pública única. En una arquitectura real la capa de aplicación va en subred
# privada detrás del balanceador; aquí se simplifica para que el laboratorio quepa en
# el tiempo de la demo. Ese contraste se menciona explícitamente en el módulo 2 (Seguridad).
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.30.1.0/24"
  display_name               = "${local.prefix}-subnet-public"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.app.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = local.tags
}

resource "oci_core_security_list" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.prefix}-sl-app"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # HTTP público hacia el balanceador.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # SSH restringido a tu IP. Si aquí aparece 0.0.0.0/0, el laboratorio no se levanta.
  ingress_security_rules {
    source   = var.mi_ip_cidr
    protocol = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Tráfico interno de la subred (balanceador → instancias).
  ingress_security_rules {
    source   = "10.30.1.0/24"
    protocol = "all"
  }

  freeform_tags = local.tags
}
