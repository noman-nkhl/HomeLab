# Ubuntu Docker VM outputs

output "vm_id" {
  description = "Ubuntu Docker VM ID"
  value       = proxmox_virtual_environment_vm.ubuntu_docker.vm_id
}

output "ipv4_addresses" {
  description = "VM IPv4 addresses"
  value       = proxmox_virtual_environment_vm.ubuntu_docker.ipv4_addresses
}
