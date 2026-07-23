# Ubuntu 24.04 Cloud-Init Template
# VM ID 9000 — reusable template for new cloud-init VMs
# Imported via qm importdisk (SSH remote-exec)

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "template" {
  vm_id     = 9000
  node_name = var.proxmox_node
  name      = "ubuntu-2404-template"
  on_boot   = false
  started   = false

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 8
  }

  network_device {
    bridge  = "vmbr0"
  }

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      disk,
      template,
      initialization,
    ]
  }
}

resource "null_resource" "import_and_template" {
  depends_on = [proxmox_virtual_environment_vm.template]

  connection {
    type     = "ssh"
    host     = "192.168.1.200"
    user     = "root"
    password = var.proxmox_ssh_password
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Importing cloud image...'",
      "qm importdisk 9000 /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img local-lvm",
      "echo 'Setting up SCSI disk...'",
      "qm set 9000 --scsi0 local-lvm:vm-9000-disk-1",
      "echo 'Removing unused disk...'",
      "qm unlink 9000 --idlist unused0 2>/dev/null || true",
      "qm set 9000 --delete unused0 2>/dev/null || true",
      "echo 'Attaching cloud-init drive...'",
      "qm set 9000 --ide2 local-lvm:cloudinit",
      "echo 'Converting to template...'",
      "qm template 9000",
      "echo 'TEMPLATE READY'",
    ]
  }
}
