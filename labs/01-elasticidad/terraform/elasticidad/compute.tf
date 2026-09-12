resource "oci_core_instance_configuration" "app" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-instance-config"
  freeform_tags  = local.tags

  # Cambiar la aplicación (cloud-init) obliga a reemplazar esta configuración, y el
  # grupo de instancias la tiene referenciada: sin esto, Terraform intenta borrarla
  # primero y el borrado falla porque está en uso. Con create_before_destroy crea la
  # nueva, actualiza el grupo, y solo entonces borra la vieja.
  lifecycle {
    create_before_destroy = true
  }

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id      = var.compartment_ocid
      availability_domain = local.ad_name
      display_name        = "${local.prefix}-app"
      shape               = var.shape

      shape_config {
        ocpus         = var.ocpus
        memory_in_gbs = var.memory_in_gbs
      }

      source_details {
        source_type             = "image"
        image_id                = local.image_id
        boot_volume_size_in_gbs = 50
      }

      create_vnic_details {
        subnet_id        = oci_core_subnet.public.id
        assign_public_ip = true
      }

      # El plugin de monitoreo debe estar habilitado: sin él no hay métrica de CPU
      # y el autoescalamiento nunca dispara. Es el error más común de este laboratorio.
      agent_config {
        is_monitoring_disabled = false
        is_management_disabled = false
      }

      metadata = {
        ssh_authorized_keys = var.ssh_public_key
        user_data           = base64encode(file("${path.module}/cloud-init.yaml"))
      }

      freeform_tags = local.tags
    }
  }
}

resource "oci_core_instance_pool" "app" {
  compartment_id            = var.compartment_ocid
  instance_configuration_id = oci_core_instance_configuration.app.id
  display_name              = "${local.prefix}-pool"
  size                      = var.pool_min
  freeform_tags             = local.tags

  placement_configurations {
    availability_domain = local.ad_name
    primary_subnet_id   = oci_core_subnet.public.id
  }

  load_balancers {
    load_balancer_id = oci_load_balancer_load_balancer.app.id
    backend_set_name = oci_load_balancer_backend_set.app.name
    port             = 80
    vnic_selection   = "PrimaryVnic"
  }

  # A partir del apply inicial, el tamaño lo gobierna el autoescalamiento.
  # Sin esto, cada `terraform plan` durante la demo querría devolver el pool a 2.
  lifecycle {
    ignore_changes = [size]
  }

  depends_on = [oci_load_balancer_listener.http]
}
