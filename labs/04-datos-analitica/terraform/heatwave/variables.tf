variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  description = "OCID del compartment lab-04-datos."
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

variable "ad_index" {
  type    = number
  default = 0
}

variable "ips_admin_cidr" {
  description = <<-EOT
    IPs desde las que se permite abrir sesiones de bastión.
    en la preparación en la sala será otra: actualizar y aplicar (el cambio es en caliente).
  EOT
  type        = list(string)
}

# --- Base de datos -----------------------------------------------------------

variable "shape_mysql" {
  description = <<-EOT
    Shape del sistema de base de datos. Verificar cuáles existen en la región ANTES
    del primer apply, porque los nombres cambian entre regiones y con el tiempo:

      oci mysql shape list --compartment-id <compartment> \
        --query 'data[].{nombre:name,ecpus:"is-supported-for"}' --output table

    Si el tenancy tiene disponible el nivel siempre gratuito de MySQL HeatWave,
    ese shape es la opción más barata para el laboratorio. [VALIDAR disponibilidad]
  EOT
  type        = string
  default     = "MySQL.2"
}

variable "almacenamiento_gb" {
  description = "Mínimo 50 GB. Tres millones de documentos ocupan bastante menos."
  type        = number
  default     = 50
}

variable "admin_usuario" {
  type    = string
  default = "admin"
}

variable "admin_password" {
  description = "Contraseña del administrador. Pasarla por variable de entorno TF_VAR_admin_password, no por el archivo tfvars."
  type        = string
  sensitive   = true
}

# --- Acelerador analítico ----------------------------------------------------

variable "crear_cluster_heatwave" {
  description = <<-EOT
    El clúster de HeatWave es un costo aparte del sistema de base de datos y consume
    crédito del trial con rapidez. Se deja apagado por defecto: encenderlo solo
    después de revisar límites y crédito disponible.

    Sin clúster el laboratorio funciona igual; lo que se pierde es la comparación de
    tiempos, que entonces NO se presenta con cifras estimadas.
  EOT
  type        = bool
  default     = false
}

variable "tamano_cluster_heatwave" {
  description = "Nodos del clúster. Uno basta para el volumen del laboratorio."
  type        = number
  default     = 1
}

variable "shape_heatwave" {
  description = <<-EOT
    Shape del nodo de HeatWave. Verificar antes de activarlo:
      oci mysql shape list --compartment-id <compartment> --is-supported-for HEATWAVECLUSTER

    Verificado en us-chicago-1: HeatWave.32GB y HeatWave.512GB. El de 32 GB basta
    de sobra para el volumen del laboratorio y cuesta bastante menos.
  EOT
  type        = string
  default     = "HeatWave.32GB"
}
