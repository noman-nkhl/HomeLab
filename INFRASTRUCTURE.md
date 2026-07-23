# Homelab Infrastructure Overview
Last Updated: 2026-07-23

---

## Network Map (192.168.1.0/24)

| IP              | Hostname     | Device / VM       | Role              |
| :-------------- | :----------- | :---------------- | :---------------- |
| 192.168.1.1     | —            | ISP Router        | Gateway, DHCP, NAT|
| 192.168.1.200   | local        | Proxmox Host      | Hypervisor        |
| 192.168.1.218   | truenas      | TrueNAS (VM 100)  | NAS / Storage     |
| 192.168.1.133   | Debian13     | Debian13 (VM 102) | Offline (NFS issue)|
| 192.168.1.50    | ubuntu-docker| ubuntu-docker (103)| Docker, Jellyfin, ARR Stack|
| 192.168.1.238   | —            | Raspberry Pi      | Pi-hole DNS       |

---

## Proxmox VE Cluster

| Property       | Value                                   |
| :------------- | :-------------------------------------- |
| **Version**    | 9.0.3                                   |
| **Node**       | `local` (nodeid: 0)                     |
| **Cluster**    | Single-node                             |
| **Status**     | Online                                  |
| **Uptime**     | ~8.3 hours (29,860s at snapshot)           |
| **API Base**   | `https://192.168.1.200:8006/api2/json`  |
| **Token ID**   | `root@pam!gemini-cli`                   |

---

## Hardware Specifications

| Resource      | Total / Max    | Current Usage        |
| :------------ | :------------- | :------------------- |
| **CPU**       | 24 vCPUs       | ~0% (idle at snapshot)|
| **RAM**       | 31.25 GiB      | ~14 GiB allocated to VMs |
| **Disk**      | —              | ~15.8 GiB (see Storage) |

---

## Storage Resources

### Proxmox Host

#### `local` (Directory)
| Property        | Value                          |
| :-------------- | :----------------------------- |
| **Type**        | `dir`                          |
| **Path**        | `/var/lib/vz` (default)        |
| **Total**       | ~96 GiB (100,861,726,720 B)    |
| **Used**        | ~15.8 GiB (15.67%)             |
| **Available**   | ~76.1 GiB                      |
| **Content**     | `iso`, `vztmpl`                |
| **Shared**      | No                             |
| **API Path**    | `/nodes/local/storage/local`   |

#### `local-lvm` (LVM-Thin)
| Property        | Value                                          |
| :-------------- | :--------------------------------------------- |
| **Type**        | `lvmthin`                                      |
| **VG/LV**       | Standard Proxmox LVM-thin pool                 |
| **Total**       | ~1.75 TiB (1,884,119,105,536 B)                |
| **Used**        | ~16.8 GiB (0.89%)                              |
| **Available**   | ~1.74 TiB                                      |
| **Content**     | `images`, `rootdir`                            |
| **Shared**      | No                                             |
| **API Path**    | `/nodes/local/storage/local-lvm`               |

### TrueNAS (VM 100) — via TrueNAS API

| Property          | Value                                      |
| :---------------- | :----------------------------------------- |
| **Version**       | TrueNAS SCALE 25.10.3.1                    |
| **Hostname**      | `truenas.local`                            |
| **API Base**      | `https://192.168.1.218/api/v2.0`           |
| **API Auth**      | Bearer token in `.env` (line 13)           |

#### ZFS Pool: `WD_10TB`

| Property           | Value                                      |
| :----------------- | :----------------------------------------- |
| **Status**         | ONLINE, healthy                            |
| **Topology**       | MIRROR (RAID-1) — 2x 10TB WD HDDs          |
| **Total Raw**      | ~9.08 TiB (9,981,503,995,904 B)            |
| **Allocated**      | ~0.3 GiB (347 MiB)                        |
| **Free**           | ~8.95 TiB                                  |
| **Compression**    | LZ4 (1.75x ratio on root dataset)          |
| **ashift**         | 12 (4K sector alignment)                   |
| **Recordsize**     | 128K                                       |
| **Checksum**       | ON                                         |
| **Dedup**          | OFF                                        |
| **Encryption**     | OFF                                        |

**Mirror vdev members:**

| Disk ID              | Device | Serial        | Size   |
| :------------------- | :----- | :------------ | :----- |
| `e320a7eb...`        | sdc    | WD-BC0P6KGJ   | ~9.3T  |
| `85e999a6...`        | sdb    | WD-BC0P7D1J   | ~9.3T  |

#### ZFS Datasets

| Dataset            | Mountpoint              | Used     | Avail   | Created            |
| :----------------- | :---------------------- | :------- | :------ | :----------------- |
| `WD_10TB`          | `/mnt/WD_10TB`          | 104 KiB  | 8.95 TiB| May 27, 2026       |
| `WD_10TB/Movies`   | `/mnt/WD_10TB/Movies`   | 96 KiB   | 8.95 TiB| May 31, 2026       |
| `WD_10TB/Anime`    | `/mnt/WD_10TB/Anime`    | 96 KiB   | 8.95 TiB| May 31, 2026       |
| `WD_10TB/Shows`    | `/mnt/WD_10TB/Shows`    | 96 KiB   | 8.95 TiB| May 31, 2026       |
| `WD_10TB/TV`       | `/mnt/WD_10TB/TV`       | 96 KiB   | 8.95 TiB| May 31, 2026       |

> All datasets inherit LZ4 compression, atime=OFF, aclmode=DISCARD, acltype=POSIX.

#### TrueNAS User Accounts (non-builtin)

| Username          | UID  | SMB  | Sudo   | Roles       | Notes              |
| :---------------- | :--- | :--- | :----- | :---------- | :----------------- |
| `tech`            | 1000 | Yes  | ALL    | FULL_ADMIN  | Has API key; NFS maproot |
| `truenas_admin`   | 950  | No   | ALL    | FULL_ADMIN  | Locked             |
| `user1`           | 3000 | Yes  | No     | —           | SMB share access   |
| `user2`           | 2000 | Yes  | No     | —           | SMB share access   |

---

## Networking

### Bridges (Proxmox Host)

| Bridge   | IP / CIDR          | Gateway       | Physical Port | STP   | Autostart | Purpose                  |
| :------- | :----------------- | :------------ | :------------ | :---- | :-------- | :----------------------- |
| `vmbr0`  | 192.168.1.200/24   | 192.168.1.1   | `eno1`        | off   | Yes       | Main LAN                 |
| `vmbr1`  | Manual (no IP)     | —             | `enp3s0`      | off   | Yes       | Orphaned (ex-OpenWRT WAN)|

### Physical Interfaces (Proxmox Host)

| Interface | Alt Names              | Type    | Active | Exists | Notes                  |
| :-------- | :--------------------- | :------ | :----- | :----- | :--------------------- |
| `eno1`    | `enp7s0`, `enx18c04d...` | `eth` | Yes    | Yes    | Main LAN uplink        |
| `enp3s0`  | —                      | unknown | No     | —      | WAN uplink (vmbr1, unused) |
| `enp2s0`  | —                      | unknown | No     | —      | Unused                 |
| `wlp8s0`  | `wlxa4b1c10d052a`      | `eth`   | No     | Yes    | WiFi (unused)          |

### TrueNAS Network

| Property            | Value                    |
| :------------------ | :----------------------- |
| **Hostname**        | `truenas.local`          |
| **Gateway**         | 192.168.1.1              |
| **DNS**             | 8.8.8.8, 1.1.1.1         |

### Software-Defined Networking (SDN)

| SDN Name        | Type   | Status | Node   |
| :-------------- | :----- | :----- | :----- |
| `localnetwork`  | SDN    | ok     | local  |

No SDN Zones or VNets are configured (empty from API).

### Reverse Proxy & Internal DNS

| Property            | Value                    |
| :------------------ | :----------------------- |
| **Reverse Proxy**   | Traefik v3.2 on ubuntu-docker (VM 103) |
| **Ports**           | 80 (HTTP → 443 redirect), 443 (HTTPS) |
| **SSL**             | Let's Encrypt wildcard `*.nkhl.co.uk` via Cloudflare DNS-01 |
| **Internal DNS**    | Cloudflare public DNS — wildcard `*.nkhl.co.uk` A record → `192.168.1.50` |
| **Config Location** | `/opt/traefik/` — docker compose + traefik.yml + config.yml |

---

## Virtual Machines (QEMU)

### VM 100 — TrueNAS (Storage / NAS)
| Field             | Value                                                    |
| :---------------- | :------------------------------------------------------- |
| **Status**        | Running                                                  |
| **IP**            | 192.168.1.218 (DHCP)                                     |
| **OS**            | TrueNAS SCALE 25.10.3.1                                  |
| **vCPU**          | 2 cores (`x86-64-v2-AES`), 1 socket                      |
| **RAM**           | 8 GiB (max 8 GiB)                                        |
| **Boot**          | `order=scsi0;net0`                                       |
| **SCSI H/W**      | `virtio-scsi-single`                                     |
| **VMGenID**       | `cd770b7a-c403-44f1-a39f-506ad3e6f26d`                   |
| **QEMU Agent**    | NOT configured                                            |

#### Disks
| Slot   | Volume / Passthrough                                          | Size      |
| :----- | :------------------------------------------------------------ | :-------- |
| scsi0  | `local-lvm:vm-100-disk-0` (iothread=1)                        | 32 GiB    |
| scsi1  | `/dev/disk/by-id/ata-WDC_WD100EFGX-68CPLN0_WD-BC0P6KGJ`      | ~9.3 TiB  |
|        | serial=`WD-BC0P6KGJ` — see sdc in ZFS mirror                  |           |
| scsi2  | `/dev/disk/by-id/ata-WDC_WD100EFGX-68CPLN0_WD-BC0P7D1J`      | ~9.3 TiB  |
|        | serial=`WD-BC0P7D1J` — see sdb in ZFS mirror                  |           |

> **IMPORTANT:** scsi1 and scsi2 are raw SCSI passthrough disks used by the
> ZFS MIRROR pool `WD_10TB`. Do NOT remove or reallocate without shutting
> down TrueNAS first.

#### Network
| Slot  | MAC               | Bridge  | Firewall |
| :---- | :---------------- | :------ | :------- |
| net0  | BC:24:11:DC:F8:F4 | vmbr0   | Yes      |

---

### VM 102 — Debian13 (Offline)
| Field             | Value                                                    |
| :---------------- | :------------------------------------------------------- |
| **Status**        | Stopped (NFS kernel hang on boot)                        |
| **IP**            | 192.168.1.133 (DHCP)                                     |
| **OS**            | Debian 13                                                |
| **Access**         | SSH: `nkhan` (password in SECRETS.md) — non-functional  |
| **vCPU**          | 2 cores (`x86-64-v2-AES`), 1 socket                      |
| **RAM**           | 2 GiB (max 2 GiB)                                        |
| **Boot**          | `order=scsi0;ide2;net0`                                  |
| **SCSI H/W**      | `virtio-scsi-single`                                     |
| **QEMU Agent**    | Enabled (`agent=1`)                                      |
| **VMGenID**       | `c7419524-0167-4896-abff-11c3f0fe9a79`                   |

> **Status (2026-07-20):** VM is offline due to a hung NFS mount in `/etc/fstab`
> that blocks boot. Jellyfin has been migrated to ubuntu-docker (VM 103).
> To recover: boot into GRUB recovery with `init=/bin/bash`, comment out the NFS
> line in `/etc/fstab`, reboot, then optionally fix the NFS mount.

#### Disks
| Slot   | Volume                            | Size      |
| :----- | :-------------------------------- | :-------- |
| scsi0  | `local-lvm:vm-102-disk-0`         | 32 GiB    |
| ide2   | `none,media=cdrom` (empty)        | —         |

#### Network
| Slot  | MAC               | Bridge  | Firewall |
| :---- | :---------------- | :------ | :------- |
| net0  | BC:24:11:2D:B2:05 | vmbr0   | Yes      |

---

### VM 103 — ubuntu-docker (Docker / Portainer)
| Field             | Value                                                    |
| :---------------- | :------------------------------------------------------- |
| **Status**        | Running                                                  |
| **IP**            | 192.168.1.50 (static)                                    |
| **OS**            | Ubuntu 24.04 LTS (cloud image)                           |
| **vCPU**          | 8 cores (`x86-64-v2-AES`), 1 socket                      |
| **RAM**           | 12 GiB (max 12 GiB)                                      |
| **Boot**          | `order=scsi0`                                            |
| **SCSI H/W**      | `virtio-scsi-single`                                     |
| **QEMU Agent**    | Enabled — running (`agent=1`)                            |
| **VMGenID**       | `b455f2bd-70b0-4a66-9b84-73a4bede755b`                   |

#### Disks
| Slot   | Volume                         | Size      |
| :----- | :----------------------------- | :-------- |
| scsi0  | `local-lvm:vm-103-disk-1`      | 32 GiB    |

> Disk imported from Ubuntu 24.04 cloud image via `qm importdisk` (Terraform
> null_resource remote-exec). Resized from 3.5GB to 32GB post-import.

#### Network
| Slot  | MAC               | Bridge  | Firewall |
| :---- | :---------------- | :------ | :------- |
| net0  | BC:24:11:0D:76:5B | vmbr0   | Yes      |

#### Services
| Service   | Type             | Port  | Status                     |
| :-------- | :--------------- | :---- | :------------------------- |
| Docker    | Container runtime| —     | Running (29.1.3)           |
| Traefik   | Reverse proxy    | 80,443| Running (v3.2)             |
| Portainer | Docker management| 9443  | Running (portainer/ce)     |
| Twingate  | Zero-trust remote| —     | Running (connector:1)      |
| OpenBao   | Secret management| 8200  | KV v2 at /kv, Raft storage|
| code-server| VS Code browser  | 8443  | Running (linuxserver)      |
| SABnzbd   | Usenet download  | 8080  | Running (linuxserver)      |
| Prowlarr  | Indexer manager  | 9696  | Running (linuxserver)      |
| Sonarr    | TV automation    | 8989  | Running (linuxserver)      |
| Radarr    | Movie automation | 7878  | Running (linuxserver)      |
| Jellyseerr| Media request UI | 5055  | Running (fallenbagel)      |
| Bazarr    | Subtitle manager | 6767  | Running (linuxserver)      |
| Jellyfin  | Media server     | 8096  | Running (lscr.io/linuxserver/jellyfin) |
| Glances   | System monitoring| 61208 | Running (nicolargo)        |

#### Credentials
| User   | SSH Key                                     |
| :----- | :------------------------------------------ |
| nkhan3 | `~/.ssh/homelab_ubuntu_docker` (ED25519)    |

> SSH: `ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50`
> Password in `.env` / `SECRETS.md`

---

## Key Notes for AI Agents

1. **Subnet migration** — The Proxmox host was previously on 192.168.0.x with an
   old router. Moved to 192.168.1.x (gateway 192.168.1.1). Cluster status API
   may still report 192.168.0.200 — canonical IP is 192.168.1.200 on vmbr0.

2. **TrueNAS raw disk passthrough** — scsi1/scsi2 are raw SCSI passthrough
   disks backing the ZFS MIRROR `WD_10TB`. Do NOT delete or repurpose without
   shutting down TrueNAS. These contain live ZFS data.

3. **Jellyfin → TrueNAS dependency** — Jellyfin now runs on ubuntu-docker (VM 103)
   as a Docker container, mounting media from TrueNAS via NFS at `/mnt/truenas`.
   The NFS mount is configured in `/etc/fstab` with `nofail` (doesn't block boot).
   Run `sudo mount /mnt/truenas` after reboot if media is unavailable.

4. **Docker NFS mount propagation** — TrueNAS exports each dataset (Movies, Shows,
   Anime, TV) as a separate NFS mount. On VM 103 these appear as sub-mounts under
   `/mnt/truenas`. Docker's default `rprivate` propagation hides sub-mounts from
   containers — they see empty mount-point directories instead of the actual NFS
   data. The ARR stack docker-compose uses `rshared` propagation on the bind mount
   (`/mnt/truenas:/data:rshared`) to correct this. Do NOT change back to default.

4. **No LXC containers** — Only QEMU VMs. LXC API returns empty.

5. **Pi-hole is external** — Runs on Raspberry Pi at 192.168.1.238, not in
   Proxmox. DNS fails if this device goes offline (no fallback DNS configured
   on the router beyond 8.8.8.8/1.1.1.1 on TrueNAS).

6. **SDN is a stub** — `localnetwork` SDN exists but has no VNets or Zones.

7. **CPU type `x86-64-v2-AES`** on all VMs — AES-NI support, good for NAS
   encryption workloads.

8. **SCSI controller `virtio-scsi-single`** on all VMs — single-queue VirtIO
   SCSI. Not ideal for high IOPS; consider `virtio-scsi` for future VMs.

9. **vmbr1 is orphaned** — Was the WAN bridge for the now-removed OpenWRT VM.
   Serves no purpose and can be repurposed or removed.

10. **TrueNAS QEMU agent missing** — VM 100 has no guest agent configured.
    Proxmox cannot query TrueNAS IP, filesystem usage, or shutdown gracefully
    via the agent. Consider installing `qemu-guest-agent` in TrueNAS.

11. **Disk naming pattern:**
    - Virtual disks: `local-lvm:vm-<VMID>-disk-<N>`
    - Physical passthrough: `/dev/disk/by-id/ata-<model>_<serial>`

12. **Terraform managed** — VMs 100 and 102 are imported into Terraform
   state (`terraform/` directory). Use `terraform plan` to preview changes,
   `terraform apply` to apply. Passthrough disks on VM 100 are excluded
   from Terraform management (lifecycle ignore_changes). VM 102 is
   currently offline (see VM section above).

13. **SABnzbd download paths** — SABnzbd downloads to `/data/Movies/.usenet/incomplete`
   and `/data/Movies/.usenet/complete` inside the container (bind-mounted from
   `/mnt/truenas/Movies/.usenet/` on the host). The `.usenet` directory is owned
   by `abc:users` (uid 911 inside linuxserver.io containers, mapped to uid 1000
   on the host via PUID/PGID=1000). ARR stack containers (sonarr, radarr, bazarr,
   jellyfin) all share the same `/mnt/truenas:/data:rshared` bind mount for
   consistent hardlink-compatible paths.

---

## Infrastructure as Code (Terraform)

| Property           | Value                                          |
| :----------------- | :--------------------------------------------- |
| **Provider**       | `bpg/proxmox` v0.109.0                         |
| **State**          | Local (`terraform/terraform.tfstate`)          |
| **Resources**      | VM 100, 102, 103, Template 9000               |
| **Token**          | `root@pam!terraform` (privsep=0, full admin)   |
| **Directory**      | `HomeLab/terraform/`                            |

#### Module: `template`
| Resource          | VMID | Name                   | Purpose                       |
| :---------------- | :--- | :--------------------- | :---------------------------- |
| VM template       | 9000 | `ubuntu-2404-template` | Ubuntu 24.04 cloud-init base  |

> Template is created by importing the Ubuntu 24.04 cloud image as a disk,
> attaching a cloud-init drive, and converting to a Proxmox template.
> Cloning this template for new VMs avoids the `qm importdisk` step.

**Key notes:**
- Import blocks in `imports.tf` — VMs are imported, not created fresh.
- TrueNAS passthrough disks (scsi1, scsi2) are NOT managed by Terraform.
- Run `terraform plan` after any manual Proxmox changes to detect drift.
- `terraform.tfvars` contains secrets and is gitignored.

---

*This file is maintained by AI agents. Query Proxmox at
`https://192.168.1.200:8006/api2/json` and TrueNAS at
`https://192.168.1.218/api/v2.0` using tokens from `.env`.*
