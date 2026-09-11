# Instancias de aplicación en subred privada. Sin IP pública: la subred lo prohíbe,
# y además se declara explícito aquí para que se lea en el código.

resource "oci_core_instance" "app" {
  count = var.num_instancias

  compartment_id      = var.compartment_ocid
  availability_domain = local.ad_name
  display_name        = "${local.prefix}-app-${count.index + 1}"
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.app.id
    assign_public_ip = false
    hostname_label   = "app${count.index + 1}"
    nsg_ids          = [oci_core_network_security_group.app.id]
  }

  # El plugin de Bastion es lo que permite sesiones SSH administradas sin exponer
  # la máquina. Tarda unos minutos en quedar activo después del arranque: por eso el
  # lunes la sesión se crea en la pausa café y no en vivo.
  agent_config {
    is_monitoring_disabled = false
    is_management_disabled = false

    plugins_config {
      name          = "Bastion"
      desired_state = "ENABLED"
    }
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init.yaml"))
  }

  freeform_tags = local.tags
}
