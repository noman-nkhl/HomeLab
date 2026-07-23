# VM module outputs

output "truenas_id" {
  description = "TrueNAS VM ID"
  value       = proxmox_virtual_environment_vm.truenas.vm_id
}

output "truenas_ipv4" {
  description = "TrueNAS VM IPv4 address"
  value       = proxmox_virtual_environment_vm.truenas.ipv4_addresses
}

output "debian13_id" {
  description = "Debian13 VM ID"
  value       = proxmox_virtual_environment_vm.debian13.vm_id
}

output "debian13_ipv4" {
  description = "Debian13 VM IPv4 address"
  value       = proxmox_virtual_environment_vm.debian13.ipv4_addresses
}
