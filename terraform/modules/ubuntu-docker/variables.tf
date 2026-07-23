# Ubuntu Docker VM variables

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "vm_password" {
  description = "Password for the VM user"
  type        = string
  sensitive   = true
}

variable "vm_ssh_public_key" {
  description = "SSH public key for the VM user"
  type        = string
}

variable "proxmox_ssh_password" {
  description = "Proxmox root password for disk import via SSH"
  type        = string
  sensitive   = true
}
