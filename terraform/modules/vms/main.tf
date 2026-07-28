# Proxmox VM resources — imports existing VMs
# Managed by Terraform via bpg/proxmox provider

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
  }
}

resource "proxmox_virtual_environment_vm" "truenas" {
  vm_id     = 100
  node_name = var.proxmox_node
  name      = "TrueNAS"
  started   = true
  on_boot   = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    iothread     = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:DC:F8:F4"
    firewall    = true
  }

  boot_order    = ["scsi0", "net0"]
  scsi_hardware = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  # Passthrough disks (scsi1/scsi2) are raw /dev/disk/by-id/ devices
  # backing the ZFS pool WD_10TB. They are not managed by Terraform.
  lifecycle {
    ignore_changes = [
      disk,
    ]
  }
}

resource "proxmox_virtual_environment_vm" "debian13" {
  vm_id     = 102
  node_name = var.proxmox_node
  name      = "Debian13"
  started   = true
  on_boot   = false

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 6144
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    iothread     = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = "BC:24:11:2D:B2:05"
    firewall    = true
  }

  boot_order    = ["scsi0", "ide2", "net0"]
  scsi_hardware = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  # Empty CD-ROM — exists in Proxmox config (ide2: none,media=cdrom)
  lifecycle {
    ignore_changes = [
      cdrom,
    ]
  }
}
