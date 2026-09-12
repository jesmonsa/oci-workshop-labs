variable "compartment_ocid" {
  description = "OCID del compartment donde se crea la base."
  type        = string
}

variable "region" {
  type = string
}

variable "config_file_profile" {
  description = "Perfil de ~/.oci/config. Vacío en Resource Manager, donde no existe ese archivo."
  type        = string
  default     = ""
}

variable "owner" {
  type    = string
  default = "equipo-cloud"
}

variable "db_name" {
  description = <<-EOT
    Nombre de la base: solo letras y números, máximo 14 caracteres, sin espacios
    ni guiones. Debe ser único dentro del tenancy y la región.
  EOT
  type        = string
  default     = "lab06agentes"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]{0,13}$", var.db_name))
    error_message = "Solo letras y números, empezando por letra, máximo 14 caracteres."
  }
}

variable "admin_password" {
  description = <<-EOT
    Contraseña del usuario ADMIN. Entre 12 y 30 caracteres, con mayúscula,
    minúscula y número, sin comillas dobles ni la palabra «admin».
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12 && length(var.admin_password) <= 30
    error_message = "La contraseña debe tener entre 12 y 30 caracteres."
  }
}

variable "usar_nivel_gratuito" {
  description = <<-EOT
    Nivel siempre gratuito: 1 OCPU y 20 GB, sin consumo de crédito. Suficiente de
    sobra para este laboratorio.

    El tenancy admite un número limitado de bases siempre gratuitas; si ya se
    alcanzó, este despliegue falla y hay que poner el valor en false.
  EOT
  type        = bool
  default     = true
}

variable "ecpus" {
  description = "ECPUs cuando NO se usa el nivel gratuito."
  type        = number
  default     = 2
}

variable "almacenamiento_tb" {
  description = "Almacenamiento en TB cuando NO se usa el nivel gratuito."
  type        = number
  default     = 1
}

variable "ips_permitidas" {
  description = <<-EOT
    IPs o CIDR desde los que se acepta conexión. Lista vacía = cualquier origen,
    siempre exigiendo el wallet de mTLS.

    Para un laboratorio corto, dejarla vacía es aceptable porque mTLS ya protege
    el acceso. Restringirla es el control adicional, y en la sesión conviene
    explicar por qué son dos capas distintas: una autentica, la otra reduce
    quién puede siquiera intentarlo.
  EOT
  type        = list(string)
  default     = []
}
