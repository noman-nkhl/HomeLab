# Main Terraform configuration
# Manages Proxmox VMs 100 (TrueNAS), 102 (Debian13), 103 (ubuntu-docker)

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true

  ssh {
    username = "root"
    password = var.proxmox_ssh_password
  }
}

module "vms" {
  source = "./modules/vms"

  proxmox_node = var.proxmox_node
}

module "ubuntu_docker" {
  source = "./modules/ubuntu-docker"

  proxmox_node          = var.proxmox_node
  vm_password           = var.ubuntu_docker_password
  vm_ssh_public_key     = var.ubuntu_docker_ssh_key
  proxmox_ssh_password  = var.proxmox_ssh_password
}

module "template" {
  source = "./modules/template"

  proxmox_node         = var.proxmox_node
  proxmox_ssh_password = var.proxmox_ssh_password
}
