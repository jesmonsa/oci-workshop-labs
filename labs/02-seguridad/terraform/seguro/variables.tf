variable "tenancy_ocid" {
  description = "OCID del tenancy del SE Trial."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID del compartment lab-02-seguridad."
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

variable "ssh_public_key" {
  description = "Contenido de la llave pública SSH. Solo se usa a través de Bastion."
  type        = string
}

variable "ips_admin_cidr" {
  description = <<-EOT
    IPs desde las que se permite abrir sesiones de Bastion, en CIDR.
    OJO: en la preparación en la sala de la organización tu IP pública será otra. Actualizar a las 13:45
    con `curl -s ifconfig.me` y `terraform apply` (el cambio es en caliente, no recrea nada).
  EOT
  type        = list(string)
}

variable "ad_index" {
  type    = number
  default = 0
}

variable "shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "ocpus" {
  type    = number
  default = 1
}

variable "memory_in_gbs" {
  type    = number
  default = 8
}

variable "num_instancias" {
  description = "Instancias de aplicación. Dos bastan para mostrar balanceo; aquí no hay autoescalamiento."
  type        = number
  default     = 2
}

# --- WAF ---------------------------------------------------------------------

variable "waf_capacidades" {
  description = <<-EOT
    Llaves de capacidades de protección del WAF (reglas OWASP CRS).
    941100 = XSS detectado vía libinjection · 942100 = SQL injection vía libinjection.
    Verificar antes del primer apply:
      oci waf protection-capability list --compartment-id <tenancy> --key 941100 --all
  EOT
  type        = list(string)
  default     = ["941100", "942100"]
}

variable "waf_version_capacidad" {
  type    = number
  default = 1
}

variable "waf_bloquear_admin" {
  description = "Regla de control de acceso: /admin responde 403 desde cualquier origen."
  type        = bool
  default     = true
}

# --- Alertas -----------------------------------------------------------------

variable "email_alertas" {
  description = "Correo que recibe las alertas de cambios críticos. Hay que confirmar la suscripción desde el correo."
  type        = string
}
