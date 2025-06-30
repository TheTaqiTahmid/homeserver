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

# Variables for Proxmox configuration
variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "pm_api_token" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "pm_insecure" {
  description = "Allow insecure connections to Proxmox API"
  type        = bool
  default     = true
}

variable "pm_user" {
  description = "Proxmox user"
  type        = string
  sensitive   = true
}

variable "pm_ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
}

variable "pm_ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
}

variable "vms" {
  description = "List of VMs to create"
  type = list(object({
    name      = string
    node_name = string
    vm_id     = number
    ip_address = string
    dns_servers = list(string)
    gateway   = string
    cores     = number
    memory    = number
    disk_size = number
  }))
}

variable "nodes" {
  type    = list(string)
  default = ["homeserver1", "homeserver2"]
}

variable "vm_user_name" {
  description = "Username for the VM"
  type        = string
}

variable "vm_user_password" {
  description = "Password for the VM user"
  type        = string
  sensitive   = true
}