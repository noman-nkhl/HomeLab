# Homelab Services
Last Updated: 2026-07-23

---

## Service Map

```
┌─────────────────────────────────────────────────────────────────┐
│                       192.168.1.0/24                             │
│                                                                  │
│  ┌─────────────────┐   ┌──────────────────┐   ┌──────────────┐ │
│  │ TrueNAS (VM 100) │   │ Debian13 (VM 102)│   │ Raspberry Pi │ │
│  │ 192.168.1.218    │   │ 192.168.1.133    │   │ 192.168.1.238│ │
│  │                  │   │                  │   │              │ │
│  │ ZFS Pool: WD_10TB│   │                  │   │ Pi-hole DNS  │ │
│  │  (MIRROR, ~9TB)  │   │ (OFFLINE)        │   │   :53, :80   │ │
│  │                  │   │ NFS mount hung   │   │              │ │
│  │ SMB Shares ──────┼───┤                  │   │              │ │
│  │ NFS Shares ──────┼───┼──────────────────┼───┤              │ │
│  └────────┬─────────┘   └────────┬─────────┘   └──────┬───────┘ │
│           │                       │                     │         │
│           ▼                       ▼                     ▼         │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              Router / Gateway (192.168.1.1)                 │  │
│  │              DHCP · NAT · Internet Uplink                   │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Services by Host

### Proxmox VE — `192.168.1.200`

| Service      | Port  | Protocol     | Details                          |
| :----------- | :---- | :----------- | :------------------------------- |
| Proxmox VE   | 8006  | HTTPS (API)  | v9.0.3, single-node              |
| SSH          | 22    | SSH          | Root access                      |

---

### TrueNAS SCALE (VM 100) — `192.168.1.218`

| Service      | Port  | Protocol     | Details                          |
| :----------- | :---- | :----------- | :------------------------------- |
| TrueNAS Web  | 443   | HTTPS        | Management UI                    |
| TrueNAS API  | 443   | HTTPS (REST) | `/api/v2.0/`, Bearer token       |
| SMB/CIFS     | 445   | SMB          | File shares (see below)          |
| NFS          | 2049  | NFS v3/v4    | File shares (see below)          |

#### ZFS Pool: `WD_10TB`

| Property       | Value                     |
| :------------- | :----------------------- |
| **Topology**   | MIRROR (RAID-1)          |
| **Raw Size**   | ~9.08 TiB                |
| **Used**       | ~0.3 GiB                 |
| **Free**       | ~8.95 TiB                |
| **Compression**| LZ4 (1.75x effective)    |
| **ashift**     | 12                       |
| **Members**    | sdb (WD-BC0P7D1J), sdc (WD-BC0P6KGJ) |

#### Dataset Layout

| Dataset            | Mountpoint              | Share Type        |
| :----------------- | :---------------------- | :---------------- |
| `WD_10TB`          | `/mnt/WD_10TB`          | (root)            |
| `WD_10TB/Movies`   | `/mnt/WD_10TB/Movies`   | SMB + NFS         |
| `WD_10TB/Anime`    | `/mnt/WD_10TB/Anime`    | SMB + NFS         |
| `WD_10TB/Shows`    | `/mnt/WD_10TB/Shows`    | SMB + NFS         |
| `WD_10TB/TV`       | `/mnt/WD_10TB/TV`       | SMB + NFS         |

#### SMB Shares

| Share Name  | Path                    | Access          |
| :---------- | :---------------------- | :-------------- |
| `movies`    | `/mnt/WD_10TB/Movies`   | user1, user2    |
| `anime`     | `/mnt/WD_10TB/Anime`    | user1, user2    |
| `shows`     | `/mnt/WD_10TB/Shows`    | user1, user2    |
| `tv`        | `/mnt/WD_10TB/TV`       | user1, user2    |

#### NFS Shares

| Path                         | Network         | Maproot User | Maproot Group |
| :--------------------------- | :-------------- | :----------- | :------------ |
| `/mnt/WD_10TB/Movies`        | 192.168.1.0/24  | `tech`       | `tech`        |
| `/mnt/WD_10TB/Anime`         | 192.168.1.0/24  | `tech`       | `tech`        |
| `/mnt/WD_10TB/Shows`         | 192.168.1.0/24  | `tech`       | `tech`        |
| `/mnt/WD_10TB/TV`            | 192.168.1.0/24  | `tech`       | `tech`        |

> **Note:** Both SMB and NFS expose the same 4 datasets. Jellyfin likely uses
> one protocol (probably NFS given the `tech` maproot user matches the admin
> account). SMB is for client access (user1/user2).

#### Snapshots & Backups

- **Snapshots:** None configured
- **Replication:** None configured
- **Backup:** No backup strategy detected

---

### ubuntu-docker (VM 103) — `192.168.1.50`

| Service      | Port  | Type         | Details                              |
| :----------- | :---- | :----------- | :----------------------------------- |
| Docker Engine| —     | Container runtime | Docker 29.1.3 (apt package)    |
| Traefik      | 80,443| HTTPS        | Reverse proxy + SSL for all services |
| Portainer CE | 9443  | HTTPS        | Docker management UI                 |
| Twingate     | —     | Connector    | Zero-trust remote access to LAN     |
| OpenBao      | 8200  | HTTP (API)   | Secret management (KV v2 at /kv)   |
| code-server  | 8443  | HTTP         | VS Code in browser (linuxserver/code-server) |

#### Running Containers
| Container                  | Image                           | Port   | Status  |
| :------------------------- | :------------------------------ | :----- | :------ |
| traefik                    | traefik:3.2                     | 80,443 | Running |
| portainer                  | portainer/portainer-ce          | 9443   | Running |
| twingate-precious-agouti   | twingate/connector:1            | —      | Healthy |
| openbao                    | openbao/openbao:latest          | 8200   | Running |
| code-server                | lscr.io/linuxserver/code-server | 8443   | Running |
| jellyfin                   | lscr.io/linuxserver/jellyfin    | 8096   | Running |
| sonarr                     | lscr.io/linuxserver/sonarr      | 8989   | Running |
| radarr                     | lscr.io/linuxserver/radarr      | 7878   | Running |
| sabnzbd                    | lscr.io/linuxserver/sabnzbd     | 8080   | Running |
| prowlarr                   | lscr.io/linuxserver/prowlarr    | 9696   | Running |
| jellyseerr                 | fallenbagel/jellyseerr          | 5055   | Running |
| bazarr                     | lscr.io/linuxserver/bazarr      | 6767   | Running |
| glances                    | nicolargo/glances               | 61208  | Running |

> **OpenBao note:** Auto-unseal configured via systemd timer (`openbao-unseal.timer`).
> Single unseal key (1-of-1) stored at `/opt/openbao/config/unseal-key` on VM 103.
> Timer checks every 30s and auto-unseals if sealed. No manual intervention needed.

#### Access
- **SSH:** `ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50`
- **Traefik:** Internal-only, runs at `/opt/traefik/` (docker compose)
  - Dashboard: `https://traefik.nkhl.co.uk` (basic auth: admin / see SECRETS.md)
  - DNS: All `*.nkhl.co.uk` records managed via Cloudflare (wildcard A record → `192.168.1.50`)
  - Certificates: Let's Encrypt wildcard via Cloudflare DNS-01 challenge
- **Portainer:** `https://portainer.nkhl.co.uk` or `https://192.168.1.50:9443`
- **code-server:** `https://code.nkhl.co.uk` or `http://192.168.1.50:8443`
  - Password: see SECRETS.md
- **QEMU Guest Agent:** Installed and running
- **DNS:** Uses Pi-hole (192.168.1.238) as primary — configured in systemd-resolved

#### Disk
- **32 GB** on `local-lvm` (Ubuntu 24.04 cloud image, resized post-import)
- Imported via `qm importdisk` (Terraform null_resource remote-exec)

#### Media Mount
- **NFS:** `192.168.1.218:/mnt/WD_10TB` → `/mnt/truenas` (nfs4)
- Configured in `/etc/fstab` with `nofail,hard,intr`
- Each dataset (`Movies`, `Anime`, `Shows`, `TV`) is a **separate NFS sub-mount** under `/mnt/truenas`
- Mapped to containers via `/mnt/truenas:/data:rshared` — **must use `rshared`** propagation so sub-mounts are visible inside containers (default `rprivate` hides them)
- Manual mount after reboot: `sudo mount /mnt/truenas`
- Library paths inside containers: `/data/Movies`, `/data/Anime`, `/data/Shows`, `/data/TV`
- **SABnzbd download paths:** `/data/Movies/.usenet/incomplete` (temp) → `/data/Movies/.usenet/complete` (finished). Sonarr/Radarr then hardlink from complete → library folder.

#### Docker Compose Locations
- **ARR Stack:** `/opt/arr-stack/docker-compose.yml` (sabnzbd, prowlarr, sonarr, radarr, jellyseerr, bazarr, jellyfin)
- **Traefik:** `/opt/traefik/docker-compose.yml`
- **Config data:** `/opt/arr-stack/config/<service>/`

#### Jellyseerr Configuration (authoritative)
- **Auto-approve:** Enabled (defaultPermissions=127 — TV + Movies)
- **Sonarr:** isDefault=true, root=/data/Shows, quality=HD-720p/1080p (id=6)
- **Radarr:** isDefault=true, root=/data/Movies, quality=HD-1080p (id=4)
- **Jellyfin:** host=192.168.1.50:8096 (not container hostname)
- **Quality profiles:** Both Sonarr (id=6) and Radarr (id=4) have upgradeAllowed=true with cutoff=WEB-1080p — accepts 720p/1080p initially, upgrades to WEB-1080p minimum

---

### Debian13 (VM 102) — `192.168.1.133` *(Offline)*

| Service      | Port  | Type         | Details                              |
| :----------- | :---- | :----------- | :----------------------------------- |
| —            | —     | —            | VM is offline due to NFS kernel hang |
|              |       |              | Jellyfin migrated to ubuntu-docker   |

> **Status (2026-07-20):** VM boots but hangs on NFS mount in `/etc/fstab`.
> All services previously on this host (Jellyfin, Docker) are now on VM 103.
> See INFRASTRUCTURE.md for recovery steps.

~~Jellyfin~~ — migrated to ubuntu-docker (VM 103) as Docker container.

#### Media Mounts (no longer active)
Jellyfin accesses media via **NFS** (confirmed):
- `192.168.1.218:/mnt/WD_10TB/Movies`
- `192.168.1.218:/mnt/WD_10TB/Anime`
- `192.168.1.218:/mnt/WD_10TB/Shows`
- `192.168.1.218:/mnt/WD_10TB/TV`
- Maproot user: `tech`, network: `192.168.1.0/24`

#### Jellyfin Library Configuration (authoritative)

This is the correct, working configuration as of 2026-07-21. If libraries break
or are recreated, restore to this exact setup.

| Library | Jellyfin Type | Container Path | TrueNAS Dataset | Expected File Structure |
| :------ | :------------ | :------------- | :-------------- | :---------------------- |
| Movies  | `movies`      | `/data/Movies` | `WD_10TB/Movies` | `Movies/<MovieFile>.mkv` |
| Anime   | `tvshows`     | `/data/Anime`  | `WD_10TB/Anime` | `Anime/<Series>/Season X/<Series> - SXXEYY.mkv` |
| Shows   | `tvshows`     | `/data/Shows`  | `WD_10TB/Shows` | `Shows/<Series>/<Series> SXXEYY.mkv` (flat or season folders) |

**Key settings required for all libraries:**
- `EnableInternetProviders: true` — allows metadata/poster fetch from TheMovieDB
- `EnableRealtimeMonitor: true` — enables automatic filesystem change detection
- `EnableLUFSScan: true` — enables LUFS audio analysis during scans
- Metadata fetchers: TheMovieDb + The Open Movie Database (series/seasons/episodes)

**Container mount:** `/mnt/truenas` → `/data` (single-root mount for hardlink support)

**Database verification** — confirm items are correctly typed:
```bash
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50
docker exec jellyfin sqlite3 /config/data/data/jellyfin.db \
  "SELECT SUBSTR(Type, INSTR(Type, '.')+1) as T, COUNT(*) FROM BaseItems \
   WHERE Path LIKE '/data/<library>/%' AND Type != 'MediaBrowser.Controller.Entities.Folder' \
   GROUP BY Type;"
```
Expected: Anime/Shows should show mostly `TV.Episode`/`TV.Season`/`TV.Series` items.
Movies should show only `Movies.Movie` items. If Anime or Shows show `Movies.Movie`,
the library was created as wrong content type — delete and recreate as `tvshows`.

**Recovery procedure** for broken libraries: see TROUBLESHOOTING.md §8.

---

### Raspberry Pi — `192.168.1.238` *(separate physical device, not a VM)*

| Service      | Port  | Protocol     | Details                          |
| :----------- | :---- | :----------- | :------------------------------- |
| Pi-hole      | 53    | DNS          | Network-wide ad blocking         |
| Pi-hole Admin| 80    | HTTP         | `https://pihole.nkhl.co.uk/admin` |
| Pi-hole API  | 80    | REST (v6)    | `/api` — session-based auth or app password |

> **Note:** Pi-hole local DNS records are no longer used for `nkhl.co.uk` subdomains.
> DNS is managed via **Cloudflare** (wildcard `*.nkhl.co.uk` → `192.168.1.50`).

> **Critical:** This is a standalone Raspberry Pi, not managed by Proxmox.
> If it goes offline, DNS fails for all LAN clients.

---

## Dependency Chain (Boot Order)

```
Power On
  └─► Router (192.168.1.1)           — ISP gateway, DHCP, always on
       ├─► Proxmox Host (1.200)       — boots VMs
       │    ├─► TrueNAS (1.218) VM100 — ZFS pool online, shares exported
       │    ├─► Debian13 (1.133) VM102— OFFLINE (NFS hang, services migrated to VM 103)
       │    └─► ubuntu-docker (1.50) VM103 — Docker + Jellyfin + ARR Stack
       │         └─► Mount /mnt/truenas from TrueNAS (manual: sudo mount /mnt/truenas)
       └─► Raspberry Pi (1.238)       — Pi-hole DNS / ad blocking
```

**Critical path:** TrueNAS must be running before ubuntu-docker mounts NFS media.
After reboot, run `sudo mount /mnt/truenas` on VM 103 if media library is empty.

---

## Port Reference

| Port   | Host              | Service         | External? |
| :----- | :---------------- | :-------------- | :-------- |
| 8006   | Proxmox (1.200)   | Proxmox VE      | LAN only  |
| 443    | TrueNAS (1.218)   | Web UI / API    | LAN only  |
| 445    | TrueNAS (1.218)   | SMB             | LAN only  |
| 2049   | TrueNAS (1.218)   | NFS             | LAN only  |
| 8096   | ubuntu-docker (1.50)| Jellyfin        | LAN only  |
| 8200   | ubuntu-docker (1.50)| OpenBao API    | LAN only  |
| 9443   | ubuntu-docker (1.50)| Portainer CE  | LAN only  |
| 8080   | ubuntu-docker (1.50)| SABnzbd       | LAN only  |
| 9696   | ubuntu-docker (1.50)| Prowlarr      | LAN only  |
| 8989   | ubuntu-docker (1.50)| Sonarr        | LAN only  |
| 7878   | ubuntu-docker (1.50)| Radarr        | LAN only  |
| 5055   | ubuntu-docker (1.50)| Jellyseerr    | LAN only  |
| 6767   | ubuntu-docker (1.50)| Bazarr        | LAN only  |
| 61208  | ubuntu-docker (1.50)| Glances       | LAN only  |
| 80,443 | ubuntu-docker (1.50)| Traefik       | LAN only  |
| 53     | Pi (1.238)        | Pi-hole DNS     | LAN only  |
| 80     | Pi (1.238)        | Pi-hole Admin   | LAN only  |

---

## User Accounts

### TrueNAS (non-builtin)

| Username      | UID  | SMB | Sudo | Roles       | Status  |
| :------------ | :--- | :-- | :--- | :---------- | :------ |
| `tech`        | 1000 | Yes | ALL  | FULL_ADMIN  | Active  |
| `truenas_admin`| 950 | No  | ALL  | FULL_ADMIN  | Locked  |
| `user1`       | 3000 | Yes | No   | —           | Active  |
| `user2`       | 2000 | Yes | No   | —           | Active  |

---

## Known Gaps

- [x] **Jellyfin mount method unconfirmed** — NFS or SMB? Which credentials?
  → **Resolved: NFS**, maproot user `tech`, network `192.168.1.0/24`
- [ ] **No static DHCP reservations** — VM IPs (1.218, 1.133) are dynamic and
      could change on reboot. Reserve on the router.
- [x] **No reverse proxy** — Traefik deployed on ubuntu-docker (VM 103).
      All services accessible via `*.nkhl.co.uk` subdomains with Let's Encrypt SSL.
      DNS via Cloudflare (wildcard `*.nkhl.co.uk` A record). Direct IP:port access still works.
- [ ] **No backup strategy** — No ZFS snapshots, no replication, no off-site
      backup for TrueNAS data or Proxmox VM configs
- [ ] **No QEMU guest agent on TrueNAS** — Proxmox can't query IP, FS, or
      graceful-shutdown VM 100
- [ ] **Single Pi-hole** — No secondary DNS. If 192.168.1.238 fails, LAN DNS
      resolution breaks
- [ ] **vmbr1 orphaned** — The WAN bridge used by the removed OpenWRT VM is
      still configured and serves no purpose
- [ ] **No monitoring/alerting** — No Grafana, Prometheus, Uptime Kuma, or
      similar found on any host

## Twingate Remote Access

Twingate connector runs on ubuntu-docker (VM 103), connected to the
`khanhomelab` network. Once Resources are configured, all services below are
accessible from any device (phone, laptop) with the Twingate client installed.

### Twingate Resources (Add via Admin Console)

These should be defined in the Twingate admin console at
`https://khanhomelab.twingate.com`:

| Resource Name          | Address         | Port(s) | Purpose                    |
| :--------------------- | :-------------- | :------ | :------------------------- |
| code-server            | 192.168.1.50    | 8443    | VS Code IDE with opencode  |
| Portainer              | 192.168.1.50    | 9443    | Docker container management|
| Sonarr                 | 192.168.1.50    | 8989    | TV show automation         |
| Radarr                 | 192.168.1.50    | 7878    | Movie automation           |
| Prowlarr               | 192.168.1.50    | 9696    | Indexer management         |
| Jellyseerr             | 192.168.1.50    | 5055    | Media request UI           |
| SABnzbd                | 192.168.1.50    | 8080    | Download client            |
| OpenBao                | 192.168.1.50    | 8200    | Secret management          |
| SSH (ubuntu-docker)    | 192.168.1.50    | 22      | Direct SSH access          |
| Proxmox VE             | 192.168.1.200   | 8006    | Hypervisor management      |
| Jellyfin               | 192.168.1.50    | 8096    | Media server               |
| TrueNAS                | 192.168.1.218   | 443     | Storage management         |
| Pi-hole Admin          | 192.168.1.238   | 80      | DNS / ad blocking admin    |

### Phone Setup
1. Install **Twingate** app (iOS/Android)
2. Sign into the `khanhomelab` network
3. Tap Connect — all Resources above are now reachable
4. For code-server: open phone browser → `http://192.168.1.50:8443`

### code-server Access
- **URL:** `http://192.168.1.50:8443`
- **Password:** `HomeLab2026!` (change on first login)
- **Pre-installed:** opencode CLI, Docker CLI, Git, curl
- **Workspace:** `/home/nkhan3` (your home directory)
- **Config persisted:** `/home/nkhan3/code-server-config` (survives container rebuilds)

---

## Infrastructure as Code

Proxmox VMs 100 and 102 are managed via **Terraform** using the `bpg/proxmox`
provider. The configuration is in `HomeLab/terraform/`.

| Resource          | Terraform Module               | Status                |
| :---------------- | :----------------------------- | :-------------------- |
| VM 100 (TrueNAS)  | `module.vms.truenas`           | Imported (ignore_changes on passthrough disks) |
| VM 102 (Debian13) | `module.vms.debian13`          | Imported (ignore_changes on cdrom) |

**Important:** Terraform PASSTHROUGH disks on TrueNAS (scsi1/scsi2 —
WD_10TB ZFS pool) are excluded from management via `lifecycle { ignore_changes = [disk] }`.
These disks must never be removed by Terraform.

---

*This file is maintained by AI agents. Update when services are added, removed,
or reconfigured. API keys are stored in `.env`.*
