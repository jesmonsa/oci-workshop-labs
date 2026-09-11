resource "oci_load_balancer_load_balancer" "app" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-lb"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.public.id]
  is_private     = false

  shape_details {
    minimum_bandwidth_in_mbps = var.lb_min_mbps
    maximum_bandwidth_in_mbps = var.lb_max_mbps
  }

  freeform_tags = local.tags
}

resource "oci_load_balancer_backend_set" "app" {
  name             = "${local.prefix}-bset"
  load_balancer_id = oci_load_balancer_load_balancer.app.id
  policy           = "ROUND_ROBIN"

  # El intervalo corto hace que los backends nuevos aparezcan rápido en pantalla
  # durante la demo. En producción se usan valores más conservadores.
  health_checker {
    protocol          = "HTTP"
    port              = 80
    url_path          = "/health"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.app.id
  name                     = "${local.prefix}-listener-http"
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}
