# AGENTS.md — Homelab Context & Best Practices
Last Updated: 2026-07-23

This file provides full context to AI agents managing this homelab. Read it
before making any changes.

---

## Quick Reference

| Resource          | IP              | Access                        |
| :---------------- | :-------------- | :---------------------------- |
| **Proxmox VE**    | 192.168.1.200   | `https://192.168.1.200:8006` |
| **TrueNAS SCALE** | 192.168.1.218   | `https://192.168.1.218`      |
| **Debian13**      | 192.168.1.133   | Offline — NFS mount hang         |
| **ubuntu-docker** | 192.168.1.50    | `https://192.168.1.50:9443`  |
| **Traefik**       | 192.168.1.50    | `https://traefik.nkhl.co.uk` |
| **Pi-hole**       | 192.168.1.238   | `http://192.168.1.238/admin` |
|                    | Raspberry Pi    | Separate physical device      |
| **Router**        | 192.168.1.1     | `https://192.168.1.1`        |
|                    | Linksys SPNM60  | Cognitive Mesh                |

---

## Credential Sources

- **OpenBao** — `http://192.168.1.50:8200` — KV v2 secrets at `/kv`. **Authoritative.**
  All API keys, tokens, and passwords are stored here. Root token in `SECRETS.md`.
- **`.env`** — machine-readable fallback for scripts. Mirrors OpenBao secrets.
- **`SECRETS.md`** — gitignored cold backup. OpenBao root token + unseal keys.

  When credentials change: update OpenBao first, then sync `.env` and `SECRETS.md`.

### OpenBao Quick Access
```powershell
$token = "<root-token from SECRETS.md>"
$headers = @{ "X-Vault-Token" = $token }

# Read all Proxmox secrets
(Invoke-RestMethod -Uri "http://192.168.1.50:8200/v1/kv/data/proxmox" -Headers $headers).data.data

# Read a VM password
(Invoke-RestMethod -Uri "http://192.168.1.50:8200/v1/kv/data/vms/ubuntu-docker" -Headers $headers).data.data
```

---

## Session Guidelines

1. **Ask questions first.** Before making changes, ask as many questions as
   needed to fully understand the scope and intent of the task. Do not assume.
2. **Keep docs in sync.** Any time infrastructure or services change, update
   `INFRASTRUCTURE.md` and `SERVICES.md` immediately. Outdated docs are worse
   than no docs.
3. **Use skills proactively.** Before any significant action, check whether a
   pre-installed skill covers the task. Use `skill_find "<keywords>"` to
   discover relevant skills, then `skill_use "<name>"` to load them. This
   prevents mistakes by ensuring you follow homelab-specific rules, IPs,
   credentials patterns, and dependency orders.

---

## Available Skills

Skills are loaded via `skill_use "<name>"`. Load the relevant skill **before**
working on a task — each contains homelab-specific context and safety rules.
Use `skill_find "*"` to list all available skills.

| Skill | Load when... |
| :---- | :----------- |
| **ssh-operations** | Connecting to any homelab host via SSH, troubleshooting SSH, setting up keys, or hardening |
| **agent-ssh-access** | Using the plan/go protocol for safe remote execution on Debian13 or ubuntu-docker |
| **docker-management** | Checking containers, restarting services, viewing logs, or managing Docker on ubuntu-docker (192.168.1.50) |
| **linux-admin** | Running updates, checking disk/ram, managing systemd services on Debian13 or ubuntu-docker |
| **homelab-docs** | After any infra/service change — prompts you to sync INFRASTRUCTURE.md, SERVICES.md, and AGENTS.md |
| **proxmox-api** | Querying VM status, starting/stopping VMs, checking storage, cloning from template via Proxmox REST API |
| **terraform-homelab** | Running `terraform plan`, `terraform apply`, detecting drift, modifying VM resources via IaC |

### Skill usage pattern
```
skill_find "docker logs traefik"     # 1. Find relevant skill
skill_use "docker-management"        # 2. Load it before taking action
# now the skill's rules guide your approach
```

### When to skip skills
- Simple file reads or edits in the HomeLab repo itself (e.g., editing AGENTS.md)
- General knowledge questions not specific to this homelab
- Tasks already fully covered by instructions in this AGENTS.md

---

## File Structure

```
HomeLab/
  .env                  # All API keys & secrets (GITIGNORED)
  .env.example          # Template for .env (safe to commit)
  .gitignore            # Excludes secrets, state, logs
  AGENTS.md             # This file
  INFRASTRUCTURE.md     # Detailed hardware/VM/network specs
  SERVICES.md           # Service catalog, shares, users, ports
  SECRETS.md            # All credentials in one place (GITIGNORED)
  terraform/            # Terraform IaC for Proxmox
    main.tf             # Provider config + module call
    variables.tf        # Input variable declarations
    terraform.tfvars    # Variable values (GITIGNORED)
    imports.tf          # Import blocks for existing VMs
    modules/vms/        # VM resource definitions (100, 102)
    modules/ubuntu-docker/ # VM 103 cloud-init + SSH disk import
    modules/template/     # VM 9000 Ubuntu 24.04 cloud-init template
```

---

## Infrastructure Summary

### Hypervisor: Proxmox VE 9.0.3
- Single node `local` — 24 vCPUs, 32 GiB RAM
- API: `https://192.168.1.200:8006/api2/json`
- Two API tokens in `.env`:
  - `PROXMOX_TOKEN_*` — general use (`root@pam!gemini-cli`)
  - `PROXMOX_TF_TOKEN_*` — Terraform (`root@pam!terraform`, privsep=0)

### VMs

| VMID | Name     | OS              | vCPU | RAM  | IP              | Role            |
| :--- | :------- | :-------------- | :--- | :--- | :-------------- | :-------------- |
| 100  | TrueNAS  | SCALE 25.10.3.1 | 2    | 8GB  | 192.168.1.218   | NAS / Storage   |
| 102  | Debian13 | Debian 13       | 2    | 2GB  | 192.168.1.133   | OFFLINE (NFS hang)        |
| 103  | ubuntu-docker | Ubuntu 24.04 | 8 | 12GB | 192.168.1.50    | Docker, Jellyfin, ARR, Portainer |

**VM 101 (OpenWRT) has been removed** — routing is via ISP gateway at 192.168.1.1.

### Storage
- **`local-lvm`** (LVM-Thin): ~1.75 TiB — VM boot disks
- **TrueNAS `WD_10TB`** (ZFS MIRROR): ~9.08 TiB — 2x 10TB WD HDDs (raw passthrough)
  - Datasets: `Movies`, `Anime`, `Shows`, `TV`
  - Exported via SMB + NFS to `192.168.1.0/24`

### Networking
- **vmbr0:** `192.168.1.200/24` → eno1 → main LAN
- **vmbr1:** Unused/orphaned (ex-OpenWRT WAN). Safe to remove via Proxmox UI
  or API: `DELETE /api2/json/nodes/local/network/vmbr1`.
- **Gateway:** 192.168.1.1 (ISP router — DHCP, DNS, NAT)
- **WiFi:** wlp8s0 (unused)
- **SDN:** `localnetwork` exists but has no VNets/Zones (placeholder)

---

## Services

| Service   | Host            | Port  | Notes                              |
| :-------- | :-------------- | :---- | :--------------------------------- |
| Traefik   | 192.168.1.50    | 80,443| Reverse proxy — all `*.nkhl.co.uk` |
| Proxmox   | 192.168.1.200   | 8006  | Hypervisor management              |
| TrueNAS   | 192.168.1.218   | 443   | Web UI + REST API (`/api/v2.0`)   |
| Jellyfin  | 192.168.1.50    | 8096  | Docker container, ARR stack. Library config ref: SERVICES.md; recovery: TROUBLESHOOTING.md §8 |
| Docker    | 192.168.1.50    | —     | Container runtime                  |
| Portainer | 192.168.1.50    | 9443  | Docker management UI               |
| Twingate  | 192.168.1.50    | —     | Zero-trust remote access connector |
| OpenBao   | 192.168.1.50    | 8200  | Secret management (KV v2 at /kv)   |
| Pi-hole   | 192.168.1.238   | 53,80 | Raspberry Pi — ad blocking + DNS   |
| SMB       | 192.168.1.218   | 445   | `movies`, `anime`, `shows`, `tv`  |
| NFS       | 192.168.1.218   | 2049  | Same 4 datasets, maproot `tech`   |

### Critical Dependency
**Jellyfin (VM 103) → TrueNAS (VM 100):** Jellyfin mounts media from TrueNAS
via NFS at `/mnt/truenas`. The ARR stack containers bind-mount the same path
as `/data:rshared` (rshared required for NFS sub-mount visibility). After reboot,
run `sudo mount /mnt/truenas` on VM 103.

---

## API Access Pattern

When querying APIs, always source credentials from `.env`:

```powershell
# Proxmox
$env:PROXMOX_URL="https://192.168.1.200:8006/api2/json"
$env:TOKEN_ID="root@pam!gemini-cli"
$env:TOKEN_SECRET="<from .env>"
$headers = @{ Authorization = "PVEAPIToken=$env:TOKEN_ID=$env:TOKEN_SECRET" }

# TrueNAS
$headers = @{ Authorization = "Bearer <from .env line 13>" }

# Pi-hole v6 API
$pw = "<admin password from SECRETS.md>"
$auth = Invoke-RestMethod -Uri "http://192.168.1.238/api/auth" -Method Post `
  -Body "{`"password`":`"$pw`"}" -ContentType "application/json"
$sid = [System.Web.HttpUtility]::UrlEncode($auth.session.sid)
Invoke-RestMethod -Uri "http://192.168.1.238/api/endpoint?sid=$sid"

# Cloudflare API Token (for Traefik DNS-01)
$cfToken = (Invoke-RestMethod -Uri "http://192.168.1.50:8200/v1/kv/data/CloudFlare" `
  -Headers $headers).data.data.CF_API_TOKEN

---

## Terraform Guidelines

### ABSOLUTE RULES
1. **NEVER use `-auto-approve`** with `terraform apply`. Always review the plan first.
2. **Always run `terraform plan` before `terraform apply`.** Review every change.
3. **Never remove the `lifecycle { ignore_changes = [disk] }` block** on the TrueNAS
   resource. This protects the ZFS pool passthrough disks from accidental destruction.
4. **State file is local** — `terraform/terraform.tfstate`. No remote backend.
   Do NOT delete this file unless you intend to re-import everything.

### Workflow
```bash
cd terraform
terraform plan          # Always first — review changes
terraform apply         # Only after confirming plan
# NEVER: terraform apply -auto-approve
```

### What Terraform Manages
- VM 100 (TrueNAS) — config only (disks excluded via ignore_changes)
- VM 102 (Debian13) — full config (cdrom excluded via ignore_changes)
- VM 103 (ubuntu-docker) — config + SSH disk import via null_resource remote-exec
- VM 9000 (ubuntu-2404-template) — reusable cloud-init template

### How to Deploy a New VM from the Template

```bash
# Clone from template, resize disk, apply cloud-init
qm clone 9000 <NEW_VMID> --name <NAME> --full
qm resize <NEW_VMID> scsi0 <SIZE>G
qm set <NEW_VMID> --ipconfig0 ip=<IP>/24,gw=192.168.1.1
qm set <NEW_VMID> --ciuser <USERNAME> --cipassword <PASSWORD>
qm set <NEW_VMID> --sshkeys /path/to/key.pub
qm set <NEW_VMID> --onboot 1
qm start <NEW_VMID>
```

### What Terraform Does NOT Manage
- Passthrough disks (scsi1, scsi2 on VM 100)
- Storage pools (local, local-lvm)
- Network bridges (vmbr0, vmbr1)
- Users, groups, ACLs, firewall rules

---

## Critical Warnings

1. **DO NOT delete/reallocate TrueNAS passthrough disks** (scsi1/scsi2 on VM 100).
   These are live ZFS pool members. Removal = total data loss.
2. **Both VM 100 and VM 102 IPs are DHCP** — they could change on router/DHCP reboot.
   VM 102 is currently offline (NFS mount hang on boot). VM 103 has a static IP
   (192.168.1.50). No static reservations exist on the router.
3. **No backups anywhere** — no ZFS snapshots, no replication, no PBS.
   Any destructive action on TrueNAS is irreversible.
4. **Pi-hole is single point of failure** — if 192.168.1.238 goes down,
   LAN DNS breaks. No secondary DNS configured.
5. **TrueNAS has no QEMU guest agent** — Proxmox cannot gracefully shut
   it down or query its IP from the hypervisor.
6. **Docker NFS mount propagation** — TrueNAS exports each dataset as a separate
   NFS mount. Docker's default `rprivate` propagation hides these sub-mounts from
   containers. The ARR stack at `/opt/arr-stack/docker-compose.yml` uses
   `/mnt/truenas:/data:rshared` to propagate sub-mounts. Never remove `:rshared`
   or change back to default — it will break all media access in containers.
7. **VM 103 disk import** — the Ubuntu cloud image was imported via a
   null_resource remote-exec over SSH. Terraform ignores disk changes.
   The disk was resized from 3.5GB to 32GB post-creation.

---

## Proxmox-Specific Notes

- All VMs use `x86-64-v2-AES` CPU type (AES-NI support)
- All VMs use `virtio-scsi-single` SCSI controller
- VM 102 and VM 103 have QEMU guest agent enabled (`agent=1`)
- VM 100 has NO guest agent — IP detection requires ARP table or TrueNAS API
- **VM 102 is offline** — Jellyfin migrated to VM 103 as Docker container (2026-07-20)
- **VM 103 media mount** — NFS at `/mnt/truenas`, requires manual mount after reboot: `sudo mount /mnt/truenas`
- **VM 103 docker compose** — ARR stack at `/opt/arr-stack/docker-compose.yml` uses `:rshared` bind propagation
- **VM 103 SABnzbd downloads** — `/data/Movies/.usenet/incomplete` and `/data/Movies/.usenet/complete` (inside container)
- **VM 103 Jellyseerr config** — Auto-approve enabled (perm=127). Sonarr: isDefault=true, root=/data/Shows, profile=6 (HD-720p/1080p). Radarr: isDefault=true, root=/data/Movies, profile=4 (HD-1080p). Jellyfin host: 192.168.1.50. Both Sonarr/Radarr quality profiles set upgradeAllowed=true, cutoff=WEB-1080p. Jellyseerr config at `/opt/arr-stack/config/jellyseerr/settings.json`.
- The node's cluster API may report `192.168.0.200` (leftover from old subnet);
  the canonical IP is `192.168.1.200` on vmbr0
- Storage `local-sata` is defunct — ignore any stale references

---

## Traefik Reverse Proxy

- **Host:** ubuntu-docker (VM 103) — `/opt/traefik/` (docker compose)
- **Dashboard:** `https://traefik.nkhl.co.uk` — basic auth (admin / see OpenBao)
- **SSL:** Let's Encrypt wildcard (`*.nkhl.co.uk`) via Cloudflare DNS-01 challenge
- **Config:** Static (`traefik.yml`) + dynamic (`config.yml`) — file provider only
- **DNS:** Cloudflare manages `nkhl.co.uk` zone. Wildcard A record `*.nkhl.co.uk` → `192.168.1.50` + root `nkhl.co.uk` → `192.168.1.50`. All clients should use public DNS (1.1.1.1, 8.8.8.8) — Pi-hole local records are no longer used for subdomains.
- **Architecture:** All 15 services proxied via File provider using `host.docker.internal:PORT` (for Docker containers) or direct IP (for external hosts)
- **Direct IP access:** Still works — all ports remain exposed on the host
- **Cert renew:** Automatic — Traefik handles Let's Encrypt renewal (every 60 days)

### Subdomain Map
| Subdomain | Backend |
|---|---|
| `traefik.nkhl.co.uk` | Traefik Dashboard |
| `portainer.nkhl.co.uk` | 192.168.1.50:9443 |
| `openbao.nkhl.co.uk` | 192.168.1.50:8200 |
| `code.nkhl.co.uk` | 192.168.1.50:8443 |
| `sabnzbd.nkhl.co.uk` | 192.168.1.50:8080 |
| `prowlarr.nkhl.co.uk` | 192.168.1.50:9696 |
| `sonarr.nkhl.co.uk` | 192.168.1.50:8989 |
| `radarr.nkhl.co.uk` | 192.168.1.50:7878 |
| `jellyseerr.nkhl.co.uk` | 192.168.1.50:5055 |
| `bazarr.nkhl.co.uk` | 192.168.1.50:6767 |
| `jellyfin.nkhl.co.uk` | 192.168.1.50:8096 |
| `truenas.nkhl.co.uk` | 192.168.1.218:443 |
| `proxmox.nkhl.co.uk` | 192.168.1.200:8006 |
| `pihole.nkhl.co.uk` | 192.168.1.238:80 |

### Pi-hole API (v6)
- **Base URL:** `http://192.168.1.238/api`
- **Auth:** Post password to `/api/auth` → get SID → use `?sid=` or `X-FTL-SID` header
- **App passwords:** Generate in Pi-hole web UI for static API keys (recommended)
- **DNS records endpoint:** `PATCH /api/config` → `config.dns.hosts` array (strings: `"IP HOSTNAME"`)
- **App password needs:** `webserver.api.app_sudo=true` for config writes. Admin password (`0000`) works for sudo. App passwords stored in OpenBao at `/kv/pihole`.

---

## Adding New Resources

1. Update `INFRASTRUCTURE.md` with hardware/VM details
2. Update `SERVICES.md` if it's a new service
3. Update `SECRETS.md` if new credentials are created
4. If it's a Proxmox resource, consider adding to Terraform
5. Update this file (`AGENTS.md`) if the addition changes the overall picture

---

*This file is read by AI agents on each session. Keep it current.*
