# variables for minio backend configuration
variable "minio_access_key" {
  description = "MinIO access key"
  type        = string
}

variable "minio_secret_key" {
  description = "MinIO secret key"
  type        = string
}

variable "minio_endpoint" {
  description = "MinIO API endpoint"
  type        = string
}

variable "portfolio_host" {
  description = "Host for the portfolio application"
  type        = string
}

variable "docker_registry_host" {
  description = "Host for the Docker registry"
  type        = string
}

variable "docker_username" {
  description = "Docker registry username"
  type        = string
}

variable "docker_password" {
  description = "Docker registry password"
  type        = string
}