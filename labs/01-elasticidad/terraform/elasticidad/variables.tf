variable "tenancy_ocid" {
  description = "OCID del tenancy del SE Trial."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID del compartment lab-01-elasticidad. No usar el compartment raíz."
  type        = string
}

variable "region" {
  description = "Región OCI. Usar la misma en la que opera la organización si está disponible."
  type        = string
}

variable "config_file_profile" {
  description = "Perfil de ~/.oci/config a usar."
  type        = string
  default     = ""
}

variable "owner" {
  description = "Valor del tag Owner. Se usa para el showback de costo."
  type        = string
  default     = "equipo-cloud"
}

variable "ssh_public_key" {
  description = "Contenido de la llave pública SSH (no la ruta al archivo)."
  type        = string
}

variable "mi_ip_cidr" {
  description = <<-EOT
    CIDR desde el que se permite SSH (puerto 22) a las instancias del pool.

    Pon tu IP pública en /32 (`curl -s ifconfig.me`) y nada más.

    En el tenancy de demostración del taller está en 0.0.0.0/0 a propósito, para
    que el laboratorio no dependa de la red desde la que se muestre. Lo que hace
    aceptable esa decisión es el ambiente, no el criterio: un tenancy desechable,
    sin datos y con fecha de destrucción. Copiarla a un ambiente con datos es
    exactamente el hallazgo alto que el módulo de seguridad enseña a detectar.
  EOT
  type        = string
}

variable "ad_index" {
  description = "Índice del dominio de disponibilidad (0 si la región tiene uno solo)."
  type        = number
  default     = 0
}

# --- Cómputo -----------------------------------------------------------------

variable "shape" {
  description = "Shape flexible de cómputo."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "ocpus" {
  description = "OCPUs por instancia. 1 es suficiente y hace que la CPU suba rápido en la demo."
  type        = number
  default     = 1
}

variable "memory_in_gbs" {
  description = "Memoria por instancia en GB."
  type        = number
  default     = 8
}

# --- Elasticidad -------------------------------------------------------------

variable "pool_min" {
  description = "Tamaño mínimo del pool."
  type        = number
  default     = 2
}

variable "pool_max" {
  description = "Tamaño máximo del pool. Revisar límites del trial antes de subirlo."
  type        = number
  default     = 6
}

variable "scale_out_threshold" {
  description = "% de CPU por encima del cual se agrega capacidad."
  type        = number
  default     = 55
}

variable "scale_in_threshold" {
  description = "% de CPU por debajo del cual se retira capacidad."
  type        = number
  default     = 20
}

variable "scale_out_step" {
  description = "Instancias a agregar por disparo. 2 hace la demo más visible que 1."
  type        = number
  default     = 2
}

variable "scale_in_step" {
  description = "Instancias a retirar por disparo."
  type        = number
  default     = 1
}

variable "cooldown_seconds" {
  description = "Enfriamiento entre acciones de escalamiento. 300 s es el mínimo práctico."
  type        = number
  default     = 300
}

# --- Balanceador -------------------------------------------------------------

variable "lb_min_mbps" {
  description = "Ancho de banda mínimo del balanceador flexible."
  type        = number
  default     = 10
}

variable "lb_max_mbps" {
  description = "Ancho de banda máximo del balanceador flexible."
  type        = number
  default     = 100
}
