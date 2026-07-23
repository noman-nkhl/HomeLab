# Ubuntu 24.04 Docker VM — deployed via Terraform with cloud-init
# VM ID: 103, Name: ubuntu-docker
#
# Disk import is handled by null_resource.import_disk (SSH remote-exec)
# because the Proxmox API cannot import cloud images as VM disks.

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

resource "proxmox_virtual_environment_vm" "ubuntu_docker" {
  vm_id     = 103
  node_name = var.proxmox_node
  name      = "ubuntu-docker"
  on_boot   = true
  started   = false

  agent {
    enabled = true
  }

  cpu {
    cores = 8
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 12288
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    iothread     = true
  }

  network_device {
    bridge   = "vmbr0"
    firewall = true
  }

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "192.168.1.50/24"
        gateway = "192.168.1.1"
      }
    }

    dns {
      servers = ["192.168.1.1", "8.8.8.8"]
    }

    user_account {
      username = "nkhan3"
      password = var.vm_password
      keys     = [var.vm_ssh_public_key]
    }
  }

  lifecycle {
    ignore_changes = [
      initialization,
      disk,
      started,
    ]
  }
}

# Import the Ubuntu cloud image onto the VM's disk
# Uses SSH remote-exec because Proxmox API cannot import disk images
resource "null_resource" "import_disk" {
  depends_on = [proxmox_virtual_environment_vm.ubuntu_docker]

  connection {
    type     = "ssh"
    host     = "192.168.1.200"
    user     = "root"
    password = var.proxmox_ssh_password
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Importing Ubuntu cloud image to VM 103...'",
      "qm importdisk 103 /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img local-lvm",
      "echo 'Setting up SCSI disk...'",
      "qm set 103 --scsi0 local-lvm:vm-103-disk-1",
      "echo 'Regenerating cloud-init...'",
      "qm cloudinit update 103",
      "echo 'Starting VM...'",
      "qm start 103",
      "echo 'DONE'",
    ]
  }
}

# --- POST-BOOT (after VM is up at 192.168.1.50) ---
# SSH in:
#   ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50
#
# Install Docker + Portainer:
#   sudo apt update && sudo apt install -y docker.io docker-compose-v2
#   sudo systemctl enable docker --now
#   sudo usermod -aG docker nkhan3
#   docker run -d -p 9443:9443 --name portainer --restart=always \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     -v portainer_data:/data portainer/portainer-ce:latest
