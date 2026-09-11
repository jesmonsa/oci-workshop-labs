# -----------------------------------------------------------------------------
# Acceso administrativo (Bastion) y registro (flow logs + alertas de cambios).
# -----------------------------------------------------------------------------

# Bastion administrado. Sin costo adicional. El nombre solo admite alfanuméricos.
resource "oci_bastion_bastion" "admin" {
  bastion_type                 = "STANDARD"
  compartment_id               = var.compartment_ocid
  target_subnet_id             = oci_core_subnet.app.id
  name                         = "lab02bastion"
  client_cidr_block_allow_list = var.ips_admin_cidr
  max_session_ttl_in_seconds   = 10800 # 3 h: la sesión den la preparación se crea a las 15:40 y dura todo el bloque
  freeform_tags                = local.tags
}

# --- Flow logs de la subred de aplicación -----------------------------------

resource "oci_logging_log_group" "seguridad" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-logs-seguridad"
  freeform_tags  = local.tags
}

resource "oci_logging_log" "flow_app" {
  display_name       = "${local.prefix}-flowlogs-app"
  log_group_id       = oci_logging_log_group.seguridad.id
  log_type           = "SERVICE"
  is_enabled         = true
  retention_duration = 30

  configuration {
    compartment_id = var.compartment_ocid

    source {
      category    = "all"
      resource    = oci_core_subnet.app.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }

  freeform_tags = local.tags
}

# --- Alertas ante cambios críticos (control L-03) ---------------------------
#
# Si alguien modifica una security list o una política de IAM, llega un correo en
# ~1 minuto. Es la demo alternativa si Security Zones no está lista en la preparación: se
# edita una regla en vivo y se muestra el correo llegando.

resource "oci_ons_notification_topic" "alertas" {
  compartment_id = var.compartment_ocid
  name           = "${local.prefix}-alertas-seguridad"
  description    = "Cambios criticos de red e IAM - laboratorio módulo 2"
  freeform_tags  = local.tags
}

resource "oci_ons_subscription" "email" {
  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.alertas.id
  protocol       = "EMAIL"
  endpoint       = var.email_alertas
  # La suscripción queda PENDING hasta hacer clic en el correo de confirmación.
}

resource "oci_events_rule" "cambios_criticos" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.prefix}-cambios-criticos"
  description    = "Cambios en security lists, NSGs y politicas IAM"
  is_enabled     = true

  condition = jsonencode({
    eventType = [
      "com.oraclecloud.virtualnetwork.updatesecuritylist",
      "com.oraclecloud.virtualnetwork.updatenetworksecuritygroupsecurityrules",
      "com.oraclecloud.virtualnetwork.addnetworksecuritygroupsecurityrules",
      "com.oraclecloud.identitycontrolplane.createpolicy",
      "com.oraclecloud.identitycontrolplane.updatepolicy",
      "com.oraclecloud.identitycontrolplane.deletepolicy",
    ]
  })

  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = oci_ons_notification_topic.alertas.id
      description = "Correo al equipo de seguridad"
    }
  }

  freeform_tags = local.tags
}
