---
name: terraform-homelab
description: "Manage homelab Terraform IaC. Use for terraform plan, apply, state checks, drift detection, and VM resource changes. Follows AGENTS.md Terraform guidelines."
---

# Terraform Homelab Skill

## Context

- **Directory:** `HomeLab/terraform/`
- **Provider:** `bpg/proxmox` v0.109.0
- **State:** Local (`terraform/terraform.tfstate`) — no remote backend
- **Token:** `root@pam!terraform` (privsep=0, full admin) — sourced from `.env`
- **Credentials:** in `terraform/terraform.tfvars` (gitignored)

## ABSOLUTE RULES (from AGENTS.md)

1. **NEVER use `-auto-approve`** with `terraform apply`. Always review the plan first.
2. **Always run `terraform plan` before `terraform apply`.** Review every change.
3. **Never remove `lifecycle { ignore_changes = [disk] }`** on the TrueNAS resource. This protects ZFS pool passthrough disks.
4. **State file is local** — do NOT delete `terraform.tfstate` unless re-importing everything.

## Managed resources

| Resource | VMID | What Terraform controls |
|---|---|---|
| TrueNAS | 100 | Config only (disks excluded via ignore_changes) |
| Debian13 | 102 | Full config (cdrom excluded via ignore_changes) |
| ubuntu-docker | 103 | Config + SSH disk import via null_resource |
| Template | 9000 | Ubuntu 24.04 cloud-init template |

## What Terraform does NOT manage

- Passthrough disks (scsi1, scsi2 on VM 100)
- Storage pools (local, local-lvm)
- Network bridges (vmbr0, vmbr1)
- Users, groups, ACLs, firewall rules
- SDN configuration

## Standard workflow

```bash
cd terraform
terraform plan          # Always first — review every change
# Review the output carefully
terraform apply         # Only after confirming plan
# NEVER: terraform apply -auto-approve
```

## Useful commands

### Check state
```bash
terraform state list
terraform show
```

### Drift detection
```bash
terraform plan -detailed-exitcode
```

### Target a single resource
```bash
terraform plan -target=proxmox_vm_qemu.debian13
terraform apply -target=proxmox_vm_qemu.debian13
```

### Validate config
```bash
terraform validate
terraform fmt -check -diff
```

### Import an existing VM
```bash
terraform import 'proxmox_vm_qemu.my_vm' local/<VMID>
```

## Key files

```
terraform/
  main.tf             # Provider config + module call
  variables.tf        # Input variable declarations
  terraform.tfvars    # Variable values (GITIGNORED)
  imports.tf          # Import blocks for existing VMs
  modules/
    vms/              # VM resource definitions (100, 102)
    ubuntu-docker/    # VM 103 cloud-init + SSH disk import
    template/         # VM 9000 cloud-init template
```

## Rules

1. Never run terraform from outside the `terraform/` directory
2. Check `terraform.tfvars` exists and has valid content before planning
3. After applying, verify VM state via Proxmox API
4. If terraform apply fails, read the error carefully — do NOT force or retry blindly
5. For TrueNAS (VM 100), remember disks are excluded from management
6. After any manual Proxmox change, run `terraform plan` to detect drift
7. Never commit `terraform.tfvars` or `terraform.tfstate`
