# Terraform variables

variable "proxmox_url" {
  description = "Proxmox VE API endpoint"
  type        = string
  default     = "https://192.168.1.200:8006/api2/json"
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID (e.g., root@pam!terraform)"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "local"
}

variable "ubuntu_docker_password" {
  description = "Password for the ubuntu-docker VM user (nkhan3)"
  type        = string
  sensitive   = true
}

variable "ubuntu_docker_ssh_key" {
  description = "SSH public key for the ubuntu-docker VM"
  type        = string
}

variable "proxmox_ssh_password" {
  description = "Proxmox root password for SSH (required for file operations)"
  type        = string
  sensitive   = true
}
