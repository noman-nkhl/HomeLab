variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "proxmox_ssh_password" {
  description = "Proxmox root password for SSH"
  type        = string
  sensitive   = true
}
