resource "oci_autoscaling_auto_scaling_configuration" "app" {
  compartment_id       = var.compartment_ocid
  display_name         = "${local.prefix}-autoscaling"
  cool_down_in_seconds = var.cooldown_seconds
  is_enabled           = true
  freeform_tags        = local.tags

  auto_scaling_resources {
    id   = oci_core_instance_pool.app.id
    type = "instancePool"
  }

  policies {
    display_name = "${local.prefix}-policy-cpu"
    policy_type  = "threshold"

    capacity {
      initial = var.pool_min
      min     = var.pool_min
      max     = var.pool_max
    }

    # Escalar hacia afuera: la mitad que todo el mundo configura.
    rules {
      display_name = "scale-out-cpu"

      action {
        type  = "CHANGE_COUNT_BY"
        value = var.scale_out_step
      }

      metric {
        metric_type = "CPU_UTILIZATION"

        threshold {
          operator = "GT"
          value    = var.scale_out_threshold
        }
      }
    }

    # Escalar hacia adentro: la mitad que casi nadie configura, y la que baja la factura.
    # El paso es más pequeño que el de salida a propósito: se baja con más cautela de la
    # que se sube, para no recortar capacidad justo antes de un nuevo pico.
    rules {
      display_name = "scale-in-cpu"

      action {
        type  = "CHANGE_COUNT_BY"
        value = -var.scale_in_step
      }

      metric {
        metric_type = "CPU_UTILIZATION"

        threshold {
          operator = "LT"
          value    = var.scale_in_threshold
        }
      }
    }
  }
}
