# Import existing Proxmox resources into Terraform state
# Run: terraform plan -generate-config-out=generated.tf

import {
  to = module.vms.proxmox_virtual_environment_vm.truenas
  id = "local/100"
}

import {
  to = module.vms.proxmox_virtual_environment_vm.debian13
  id = "local/102"
}
