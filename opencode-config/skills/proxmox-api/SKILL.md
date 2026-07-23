---
name: proxmox-api
description: "Manage Proxmox VE (192.168.1.200:8006) via REST API. Use for VM status, start/stop, resource checks, config queries, and storage info. Credentials sourced from .env."
---

# Proxmox API Skill

## Connection details

- **URL:** `https://192.168.1.200:8006/api2/json`
- **Node:** `local`
- **Auth:** PVEAPIToken from `.env` (root@pam!gemini-cli)
- **TLS:** Self-signed cert — always use `-k` with curl or bypass validation

## Quick connection pattern

```powershell
# Read credentials from .env
$tokenId = "root@pam!gemini-cli"
$tokenSecret = "<from .env line 5>"
$headers = @{ Authorization = "PVEAPIToken=$tokenId=$tokenSecret" }

# Bypass SSL for self-signed cert
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Query API
Invoke-RestMethod -Uri "https://192.168.1.200:8006/api2/json/<endpoint>" -Headers $headers
```

Or with curl:
```bash
curl -k -s -H "Authorization: PVEAPIToken=root@pam!gemini-cli=<secret>" "https://192.168.1.200:8006/api2/json/<endpoint>"
```

## Common endpoints

### Node status
```
GET /api2/json/nodes/local/status
```

### List all VMs
```
GET /api2/json/nodes/local/qemu
```

### VM config
```
GET /api2/json/nodes/local/qemu/<VMID>/config
```

### VM status
```
GET /api2/json/nodes/local/qemu/<VMID>/status/current
```

### Storage info
```
GET /api2/json/nodes/local/storage

GET /api2/json/nodes/local/disks/list
```

### Start/stop VM
```
POST /api2/json/nodes/local/qemu/<VMID>/status/start
POST /api2/json/nodes/local/qemu/<VMID>/status/stop
POST /api2/json/nodes/local/qemu/<VMID>/status/shutdown
POST /api2/json/nodes/local/qemu/<VMID>/status/reset
```

## Known VMs

| VMID | Name | IP | Boot order |
|---|---|---|---|
| 100 | TrueNAS | 192.168.1.218 (DHCP) | order=1, up=120s |
| 102 | Debian13 | 192.168.1.133 (DHCP) | order=3, up=30s |
| 103 | ubuntu-docker | 192.168.1.50 (static) | order=2, up=30s |
| 9000 | ubuntu-2404-template | - | template (stopped) |

## Boot dependencies

- VM 100 must boot before VM 102 (Jellyfin → TrueNAS dependency)
- VM 103 boots after TrueNAS, before Debian13 (reverse proxy + secrets needed early)

## Critical warnings

1. **VM 100 passthrough disks (scsi1, scsi2)** — raw SCSI passthrough for ZFS pool. NEVER delete, reallocate, or modify without shutting down TrueNAS first. Total data loss risk.
2. **VM 100 has NO QEMU guest agent** — Proxmox cannot query IP or filesystem from hypervisor. Shutdown may require ACPI or manual.
3. **No backups** — no PBS, no snapshots, no replication. Every destructive action is irreversible.

## Useful queries

### Quick health check (all VMs)
```
GET /api2/json/nodes/local/qemu
```

### Check which VMs are running
Filter `status=running` from the /qemu response.

### Clone VM from template
```bash
qm clone 9000 <NEW_VMID> --name <NAME> --full
qm resize <NEW_VMID> scsi0 <SIZE>G
qm set <NEW_VMID> --ipconfig0 ip=<IP>/24,gw=192.168.1.1
qm set <NEW_VMID> --ciuser <USERNAME> --cipassword <PASSWORD>
qm start <NEW_VMID>
```

## Rules

1. Always source credentials from `.env` — never hardcode
2. Use `curl -k` or `ServerCertificateValidationCallback` for self-signed cert
3. Always check VM dependencies before stopping VMs (TrueNAS before Jellyfin)
4. Never touch passthrough disks (scsi1/scsi2 on VM 100) without explicit user confirmation
5. For VM creation, prefer `qm clone 9000` from the template
6. The Terraform token (`root@pam!terraform`, privsep=0) should only be used for Terraform operations
