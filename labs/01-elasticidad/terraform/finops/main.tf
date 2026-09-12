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

# ---------------------------------------------------------------------------
# Guardarraíles de costo del SE Trial.
#
# Se aplica ANTES de crear cualquier recurso, por dos razones:
#   1. Vigila el crédito del trial, que es finito y se acaba solo.
#   2. El propio presupuesto es material de demostración: en el bloque se muestra
#      esta pantalla como el primer control de FinOps que cualquiera puede activar
#      el mismo día, sin proyecto y sin herramienta adicional.
#
# Alcance, para no prometer de más: un presupuesto de OCI AVISA, no corta. Es un
# límite informativo; nada se apaga al cruzar un umbral, y las reglas de alerta se
# evalúan cada 24 horas. El teardown diario sigue siendo el control que de verdad
# frena el gasto.
# ---------------------------------------------------------------------------

variable "tenancy_ocid" { type = string }
variable "compartment_ocid" {
  description = "Compartment a vigilar (lab-01-elasticidad)."
  type        = string
}
variable "region" { type = string }
variable "config_file_profile" {
  type    = string
  default = ""
}
variable "monto_presupuesto" {
  description = "Presupuesto mensual en USD para el laboratorio."
  type        = number
  default     = 150
}
variable "email_alertas" {
  description = "Correo que recibe las alertas de presupuesto."
  type        = string
}

resource "oci_budget_budget" "lab" {
  compartment_id = var.tenancy_ocid # los presupuestos viven en el tenancy raíz
  amount         = var.monto_presupuesto
  reset_period   = "MONTHLY"
  display_name   = "lab01-presupuesto-laboratorio"
  description    = "Laboratorio Taller de arquitectura en OCI - módulo 1"

  targets     = [var.compartment_ocid]
  target_type = "COMPARTMENT"

  freeform_tags = {
    "Proyecto" = "TallerOCI"
    "Modulo"   = "01-elasticidad"
  }
}

# Tres avisos escalonados. El de 50% es el útil: llega cuando todavía hay margen
# para corregir. El de 90% ya solo sirve para apagar cosas.
locals {
  umbrales = {
    "50" = 50
    "75" = 75
    "90" = 90
  }
}

resource "oci_budget_alert_rule" "umbral" {
  for_each = local.umbrales

  budget_id      = oci_budget_budget.lab.id
  display_name   = "lab01-alerta-${each.key}pct"
  type           = "ACTUAL"
  threshold      = each.value
  threshold_type = "PERCENTAGE"
  recipients     = var.email_alertas
  message        = "Laboratorio Taller de arquitectura en OCI: consumo por encima del ${each.key}% del presupuesto."
}

# Alerta adicional sobre gasto proyectado: avisa antes de que ocurra, no después.
resource "oci_budget_alert_rule" "forecast" {
  budget_id      = oci_budget_budget.lab.id
  display_name   = "lab01-alerta-proyeccion"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = var.email_alertas
  message        = "Laboratorio Taller de arquitectura en OCI: la proyección del mes supera el presupuesto."
}

output "budget_id" {
  value = oci_budget_budget.lab.id
}
