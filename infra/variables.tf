# Variables = los "parámetros" de la infraestructura.
# Se pueden cambiar sin tocar el código: tofu apply -var="region=us-west-2"

variable "region" {
  description = "Región de AWS a simular"
  type        = string
  default     = "us-east-1"
}

variable "endpoint" {
  description = "Dónde está 'AWS'. LocalStack (en mini) escucha en el 4566"
  type        = string
  default     = "http://localhost:4566"
}

variable "proyecto" {
  description = "Prefijo para nombrar todo lo que creamos"
  type        = string
  default     = "p1"
}
