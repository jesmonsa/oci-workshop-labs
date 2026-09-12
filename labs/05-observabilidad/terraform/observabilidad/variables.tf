variable "compartment_ocid" {
  description = "Compartment donde viven las alarmas y el tema de notificación (lab-05-observabilidad)."
  type        = string
}

variable "compartment_laboratorio" {
  description = <<-EOT
    Compartment donde están las métricas que se vigilan: el del laboratorio del
    módulo 1 (lab-01-elasticidad). Las alarmas pueden vivir en un compartment distinto
    del de los recursos observados, y en la práctica conviene: la operación mira
    todo desde un solo lugar.
  EOT
  type        = string
}

variable "region" {
  type = string
}

variable "config_file_profile" {
  type    = string
  default = ""
}

variable "owner" {
  type    = string
  default = "equipo-cloud"
}

variable "correos_destino" {
  description = <<-EOT
    Correos que reciben las alarmas. Cada uno debe confirmar la suscripción desde
    el correo que llega: sin ese clic, no recibe nada.

    Para la demo den la preparación conviene incluir un segundo correo tuyo al que puedas
    entrar desde el teléfono: proyectar la bandeja de entrada principal en una sala
    llena de gente rara vez es buena idea.
  EOT
  type        = list(string)
}

variable "umbral_cpu" {
  description = <<-EOT
    Porcentaje de CPU a partir del cual suena. Debe quedar POR DEBAJO del umbral de
    autoescalamiento del módulo 1 (55 % por defecto) para que en la demo la alarma
    suene primero y el autoescalamiento la apague después. Ese orden es el que hace
    entendible la conversación sobre alarmas que se resuelven solas.
  EOT
  type        = number
  default     = 45
}

variable "duracion_pendiente" {
  description = <<-EOT
    Cuánto debe sostenerse la condición antes de sonar, en formato ISO-8601.
    PT3M es un buen valor para la demo: suena rápido sin ser histérico.
    En producción, para señales ruidosas, PT5M o PT10M.
  EOT
  type        = string
  default     = "PT3M"
}

variable "url_runbook_cpu" {
  description = <<-EOT
    Enlace al runbook que viaja DENTRO del correo de la alarma.

    Apunta al repositorio PÚBLICO a propósito: quien recibe el correo tiene que
    poder abrirlo sin pedir acceso a nada. Un enlace con marcador de posición o
    hacia un repositorio privado convierte el momento central del bloque en un
    404 delante del cliente.
  EOT
  type        = string
  default     = "https://github.com/jesmonsa/oci-workshop-labs/blob/main/labs/05-observabilidad/runbooks/RUNBOOK-saturacion-cpu.md"
}

variable "url_runbook_backends" {
  type    = string
  default = "https://github.com/jesmonsa/oci-workshop-labs/blob/main/labs/05-observabilidad/runbooks/RUNBOOK-backends-caidos.md"
}
