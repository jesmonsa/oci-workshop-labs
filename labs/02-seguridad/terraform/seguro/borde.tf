# -----------------------------------------------------------------------------
# Borde: balanceador público + WAF.
#
# La demo es un contraste de dos comandos: el mismo payload malicioso contra el
# balanceador del módulo 1 (sin WAF) devuelve 200; contra este devuelve 403.
# -----------------------------------------------------------------------------

resource "oci_load_balancer_load_balancer" "app" {
  compartment_id             = var.compartment_ocid
  display_name               = "${local.prefix}-lb"
  shape                      = "flexible"
  subnet_ids                 = [oci_core_subnet.publica.id]
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.lb.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }

  freeform_tags = local.tags
}

resource "oci_load_balancer_backend_set" "app" {
  name             = "${local.prefix}-bset"
  load_balancer_id = oci_load_balancer_load_balancer.app.id
  policy           = "ROUND_ROBIN"

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

resource "oci_load_balancer_backend" "app" {
  count = var.num_instancias

  load_balancer_id = oci_load_balancer_load_balancer.app.id
  backendset_name  = oci_load_balancer_backend_set.app.name
  ip_address       = oci_core_instance.app[count.index].private_ip
  port             = 80
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.app.id
  name                     = "${local.prefix}-listener-http"
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = 80
  protocol                 = "HTTP"
}

# Nota para la sesión: aquí el listener es HTTP para no depender de un certificado
# en el laboratorio. En producción el listener es 443 con certificado gestionado y el
# 80 solo redirige. Es el control B-03 del checklist: decirlo antes de que lo pregunten.

# --- WAF ---------------------------------------------------------------------

resource "oci_waf_web_app_firewall_policy" "app" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-waf-policy"

  actions {
    name = "permitir"
    type = "ALLOW"
  }

  actions {
    name = "bloquear-403"
    type = "RETURN_HTTP_RESPONSE"
    code = 403

    headers {
      name  = "Content-Type"
      value = "text/plain; charset=utf-8"
    }

    body {
      type = "STATIC_TEXT"
      text = "403 - Solicitud bloqueada por el WAF (Taller de arquitectura en OCI, módulo 2)\n"
    }
  }

  # Control de acceso por ruta: evaluado antes que la protección.
  dynamic "request_access_control" {
    for_each = var.waf_bloquear_admin ? [1] : []
    content {
      default_action_name = "permitir"

      rules {
        type               = "ACCESS_CONTROL"
        name               = "bloquear-admin"
        action_name        = "bloquear-403"
        condition_language = "JMESPATH"
        condition          = "starts_with(http.request.url.path, '/admin')"
      }
    }
  }

  # Protección OWASP: XSS e inyección SQL.
  request_protection {
    rules {
      type                       = "PROTECTION"
      name                       = "owasp-xss-sqli"
      action_name                = "bloquear-403"
      is_body_inspection_enabled = false

      # Cada capacidad lleva su propia versión: no todas van en la misma, y una
      # versión equivocada hace fallar el apply entero.
      dynamic "protection_capabilities" {
        for_each = var.waf_capacidades
        content {
          key     = protection_capabilities.key
          version = protection_capabilities.value
        }
      }
    }
  }

  freeform_tags = local.tags
}

resource "oci_waf_web_app_firewall" "app" {
  compartment_id             = var.compartment_ocid
  display_name               = "${local.prefix}-waf"
  backend_type               = "LOAD_BALANCER"
  load_balancer_id           = oci_load_balancer_load_balancer.app.id
  web_app_firewall_policy_id = oci_waf_web_app_firewall_policy.app.id
  freeform_tags              = local.tags
}
