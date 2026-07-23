# ARR Stack Setup Guide — Usenet Edition

Last Updated: 2026-07-12

This guide walks you through setting up a complete media automation stack using
Usenet as the download source. By the end, you'll be able to request a movie or
TV show from a friendly web UI, have it automatically downloaded, organized,
and appear in Jellyfin — with zero manual intervention.

---

> **Reverse Proxy Access:** All ARR services are accessible via Traefik at
> `*.nkhl.co.uk` subdomains with HTTPS:
> `sabnzbd.nkhl.co.uk`, `prowlarr.nkhl.co.uk`, `sonarr.nkhl.co.uk`,
> `radarr.nkhl.co.uk`, `jellyseerr.nkhl.co.uk`, `bazarr.nkhl.co.uk`.
> Direct IP:port access still works on all services.

## Table of Contents

1. [Background: What Is Usenet?](#1-background-what-is-usenet)
2. [How the ARR Stack Works](#2-how-the-arr-stack-works)
3. [Our Architecture](#3-our-architecture)
4. [Phase 1: Usenet Accounts](#4-phase-1-usenet-accounts)
5. [Phase 2: TrueNAS Setup](#5-phase-2-truenas-setup)
6. [Phase 3: VM 103 Setup](#6-phase-3-vm-103-setup)
7. [Phase 4: SABnzbd Configuration](#7-phase-4-sabnzbd-configuration)
8. [Phase 5: Prowlarr Configuration](#8-phase-5-prowlarr-configuration)
9. [Phase 6: Sonarr Configuration](#9-phase-6-sonarr-configuration)
10. [Phase 7: Radarr Configuration](#10-phase-7-radarr-configuration)
11. [Phase 8: Jellyseerr Configuration](#11-phase-8-jellyseerr-configuration)
12. [Phase 9: End-to-End Testing](#12-phase-9-end-to-end-testing)
13. [Phase 10: Maintenance and Best Practices](#13-phase-10-maintenance-and-best-practices)
14. [Troubleshooting](#14-troubleshooting)
15. [Quick Reference](#15-quick-reference)

---

## 1. Background: What Is Usenet?

### The Short Version

Usenet is a decentralized discussion and file-sharing network that predates the
World Wide Web (created in 1980). Think of it as a massive, global bulletin board
where people post messages (called *articles*) organized into *newsgroups*. Over
time, people figured out how to encode binary files (images, software, video)
into these text-based articles, turning Usenet into a file distribution network.

Today, Usenet is one of the best sources for media because:
- **Speed**: Downloads saturate your internet connection (no peer-to-peer seeding)
- **Retention**: Major providers keep files for 5,700+ days (over 15 years!)
- **Reliability**: No seeders, no ratio requirements, no dead torrents
- **Privacy**: You connect directly to a server via SSL — no peers see your IP

### The Three-Layer Model

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 3 — INDEXER (finds the NZB)                               │
│  Services like NZBGeek, NZBPlanet index newsgroups and provide   │
│  searchable NZB files. They tell your download client exactly    │
│  where to find the articles on Usenet servers.                    │
│                                                                   │
│  Cost: ~$1-5/month or one-time lifetime deals                    │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 2 — PROVIDER (serves the data)                            │
│  Companies like Newshosting, Eweka maintain massive server farms │
│  that store all Usenet articles. This is who you actually         │
│  download from.                                                   │
│                                                                   │
│  Cost: ~$3-8/month or block accounts (pay per GB, no expiry)     │
├─────────────────────────────────────────────────────────────────┤
│  LAYER 1 — NEWSGROUPS (the content itself)                        │
│  Thousands of topic-based groups like alt.binaries.movies,        │
│  alt.binaries.tvseries, etc. Uploaders post encoded files here.   │
│                                                                   │
│  Cost: Free (but you need a provider to access them)              │
└─────────────────────────────────────────────────────────────────┘
```

### How a Download Actually Works

1. You search for "The Matrix 1999" in Sonarr/Radarr (or Jellyseerr)
2. Sonarr/Radarr asks **Prowlarr** to search connected **indexers**
3. An indexer returns an **NZB file** — this is a tiny XML file containing a list
   of Message-IDs that point to articles on Usenet servers
4. Sonarr sends this NZB to **SABnzbd** (the download client)
5. SABnzbd connects to your **Usenet provider** (e.g., Newshosting) via SSL
6. SABnzbd requests each article by its Message-ID, downloads them all
7. SABnzbd uses **par2 recovery files** to repair any missing/corrupt articles
8. SABnzbd **unpacks** (unrars) the files into the complete folder
9. Sonarr/Radarr detects the completed download and **imports** (hardlinks) the
   media file into your media library
10. Jellyfin scans the library and the media appears

```
You → Jellyseerr → Sonarr/Radarr → Prowlarr → (indexer) → NZB file
                                                    ↓
You ← Jellyfin ← Sonarr/Radarr ← SABnzbd ← (provider) ← articles
```

## What You Need to Buy

| Layer | What | Recommended | Cost |
|-------|------|-------------|------|
| Provider | Access to Usenet servers | **Newshosting** (US, Highwinds backbone, 5,800+ days retention) | ~$3-6/month (watch for yearly deals at $25-30) |
| Indexer #1 | Searchable NZB database | **NZBGeek** | ~$12/year or ~$80 lifetime |
| Indexer #2 | Backup indexer | **NZBPlanet** or **DrunkenSlug** | ~$10/year or ~$50 lifetime |

**Why two indexers?** No single indexer indexes everything. Having a backup
ensures you find what you're looking for. Some releases only appear on specific
indexers due to how uploaders distribute content.

### Provider Recommendations Explained

#### Primary Provider

**Newshosting** is the go-to recommendation because:
- It's on the **Highwinds/Omicron backbone** — the largest Usenet backbone,
  which also powers UsenetServer, Easynews, and many resellers
- **5,800+ days retention** — content from 2009+ is still available
- **US-based servers** — low latency for North America
- **Good speeds** — saturates gigabit connections
- **Frequent deals** — Reddit's r/usenet often has $25-30/year promo links

**Eweka** is the alternative if you prefer a European backbone:
- Independent backbone (not Highwinds) — different article coverage
- **5,700+ days retention**
- **NL-based servers** — good for Europe, slightly higher latency from US
- Slightly more expensive but often has deals

#### Block Accounts (Optional Advanced)

A **block account** is a fixed amount of data (e.g., 500 GB) that never expires.
You buy it once and use it as a *backup* for articles your primary provider
doesn't have.

How they work in SABnzbd:
1. Primary server: Highest priority (0) — downloads all articles it can
2. Block server: Lower priority (1) — only used when primary fails specific articles

**Good block providers** (different backbone than Highwinds):
- **UsenetFarm** — 500 GB for ~$15, independent backbone
- **ViperNews** — various block sizes, different backbone

> **Don't buy a block account yet.** Set everything up with just Newshosting
> first. Only add a block if you notice frequent download failures (missing
> articles). Many people never need one.

---

## 2. How the ARR Stack Works

### Each Component Explained

#### SABnzbd — The Download Client
SABnzbd is the workhorse. It:
- Connects to your Usenet provider(s)
- Downloads articles by Message-ID (from the NZB file)
- Assembles the articles into the original files
- Uses par2 files to repair any missing data
- Unpacks (unrars) the final media files
- Notifies Sonarr/Radarr via API when downloads complete

Think of SABnzbd like a torrent client (qBittorrent, Transmission) — it's the
piece that actually downloads data. The key difference is it downloads from
central servers rather than peers.

#### Prowlarr — The Indexer Manager
Prowlarr is the "middleman" between indexers and the *arr apps. It:
- Stores all your indexer API keys in one place
- Pushes those indexer configurations to Sonarr and Radarr automatically
- Provides a unified search interface
- Manages proxy/VPN configurations if you ever need them

Before Prowlarr, you had to add each indexer to Sonarr, Radarr, Lidarr, etc.
separately — a tedious and error-prone process. Prowlarr is a massive quality-of-life
improvement. It replaced the older Jackett with a modern UI and *arr integration.

#### Sonarr — TV & Anime Automation
Sonarr is a TV show manager. It:
- Tracks TV shows you've added (which episodes you have, which are missing)
- Monitors RSS feeds from your indexers for new releases
- Automatically searches for missing episodes
- Sends NZBs to SABnzbd for downloading
- Renames and organizes files into your folder structure
- Notifies Plex/Emby/Jellyfin to rescan

For **anime**, Sonarr supports:
- Absolute episode numbering (common in anime)
- Season-based numbering (common in Western TV)
- Custom formats for anime-specific release groups

#### Radarr — Movie Automation
Radarr is the movie equivalent of Sonarr. It:
- Tracks movies you've added (monitored vs. unmonitored)
- Searches for releases matching your quality profiles
- Handles movie collections (sequels, series)
- Downloads, renames, and organizes movies

Radarr shares the same codebase DNA as Sonarr, so the UI and configuration
patterns are nearly identical.

#### Jellyseerr — The Request UI
Jellyseerr is the user-facing "front door." Instead of opening Sonarr or Radarr
and navigating their technical UIs, you (or family/friends) use a Netflix-like
interface to:
- Browse trending, popular, and upcoming media
- Search for movies and TV shows
- Request media with a single click
- Track request status (pending, downloading, available)
- See what's already in your library

Jellyseerr talks to both Sonarr and Radarr to submit requests, and reads your
Jellyfin library to know what you already have.

### How They Communicate

```
                  ┌──────────┐
                  │Jellyseerr│  "User requests The Matrix"
                  └────┬─────┘
                       │ API call: POST /api/v3/movie
        ┌──────────────┼──────────────┐
        ▼              ▼              │
   ┌─────────┐   ┌─────────┐         │
   │ Radarr  │   │ Sonarr  │         │  "Find The Matrix"
   └────┬────┘   └────┬────┘         │
        │              │              │
        │  "Search indexers for      │
        │   The.Matrix.1999.1080p"   │
        ▼              ▼              │
   ┌─────────┐        │              │
   │ Prowlarr│◄───────┘              │
   └────┬────┘                       │
        │  "Query NZBGeek, NZBPlanet"
        ▼
   ┌─────────┐  Returns NZB file     │
   │Indexers │  with Message-IDs     │
   └─────────┘                       │
        │                            │
        ▼                            │
   ┌─────────┐                       │
   │ SABnzbd │  "Download articles   │
   └────┬────┘   from Newshosting"   │
        │                            │
        ▼                            │
   ┌─────────┐  Download → Unpack    │
   │Provider │  to /data/usenet/     │
   └─────────┘  complete/            │
        │                            │
        ▼                            │
   ┌─────────┐  Import (hardlink)    │
   │ Radarr  │  to /data/Movies/     │
   └────┬────┘                       │
        │  Notify Jellyfin to scan   │
        ▼              │
   ┌─────────┐        │
   │Jellyfin │  "New movie available"│
   └─────────┘                       │
                                     │
   Done! Movie appears in library.   │
```

---

## 3. Our Architecture

### Why This Design

The key design decision is where data lives:

- **All media and downloads are on TrueNAS** (ZFS pool, 8.95 TB free)
- **VM 103** runs only Docker containers and the OS (uses ~3 GB of its 32 GB disk)
- **VM 102** runs Jellyfin (existing, unchanged)

This separation means:
- If VM 103 dies, your media is safe on TrueNAS
- ZFS provides bit-rot protection for your media
- Docker containers are disposable — you can recreate the stack in minutes
- Jellyfin on VM 102 continues working independently

### Storage Path Mapping

Here's the critical path mapping that makes everything work:

```
TRUE NAS ZFS POOL                    VM 103 MOUNT             DOCKER CONTAINER VIEW
─────────────────────────────────    ─────────────────        ──────────────────────
/mnt/WD_10TB/                    →   /mnt/truenas/       →   /data/
  ├── Movies/                    (Radarr imports here)    │     ├── Movies/
  │   └── .usenet/                                       │     │   └── .usenet/
  │       ├── incomplete/  (SABnzbd downloads here)      │     │       ├── incomplete/
  │       └── complete/    (SABnzbd unpacks here)        │     │       └── complete/
  ├── TV/                        (Sonarr imports here)    │     ├── TV/
  ├── Shows/                     (existing content)       │     ├── Shows/
  └── Anime/                     (Sonarr/Radarr anime)    │     └── Anime/
```

### Why We Mount `/mnt/WD_10TB` as a Single NFS Share

This is the **most important architectural decision** in the entire setup.

**What are hardlinks?**
A hardlink is like giving a file two (or more) names. Both names point to the
exact same data on disk. If you delete one name, the data still exists under the
other name. Hardlinks consume zero additional disk space and are instant (no
data copy).

**Why hardlinks matter for the ARR stack:**
When SABnzbd finishes downloading `The.Matrix.1999.mkv`, it sits in
`/data/usenet/complete/The.Matrix.1999/`. Radarr wants it in
`/data/Movies/The Matrix (1999)/The Matrix (1999) Bluray-1080p.mkv`.

Without hardlinks, Radarr must **copy** the entire file (minutes to hours for
large files) and consume **double the disk space** during the copy. With
hardlinks, Radarr creates a second name for the same data — instant, zero disk
overhead.

**The catch**: Hardlinks only work if both paths are on the **same filesystem**.

Since `/mnt/WD_10TB/Movies/.usenet` and `/mnt/WD_10TB/Movies` are under the same ZFS dataset
under the same pool, they are the same filesystem. BUT — if we mount them as
*separate* NFS exports, the Linux kernel sees them as different mount points
(different filesystems), and hardlinks fail.

**The solution**: Mount the root dataset (`/mnt/WD_10TB`) as a single NFS export
on VM 103. Docker containers see everything under one `/data` volume. Hardlinks
work perfectly between `Downloads` and `Movies`/`TV`/`Anime`.

### Docker Compose Network Design

All 5 containers share a custom bridge network called `arr_network`. This means:

- Containers communicate by **container name**, not IP (e.g., `http://sabnzbd:8080`)
- The network is isolated from other Docker containers (Portainer, OpenBao, etc.)
- Container names don't change, so configurations remain stable across restarts

```
arr_network (bridge)
  ├── sabnzbd
  ├── prowlarr
  ├── sonarr
  ├── radarr
  └── jellyseerr
```

### Port Map (No Conflicts)

| Port | Service | URL | Notes |
|------|---------|-----|-------|
| 8080 | SABnzbd | `http://192.168.1.50:8080` | No conflict — Portainer uses 9443 |
| 8989 | Sonarr | `http://192.168.1.50:8989` | Unused on this network |
| 7878 | Radarr | `http://192.168.1.50:7878` | Unused on this network |
| 9696 | Prowlarr | `http://192.168.1.50:9696` | Unused on this network |
| 5055 | Jellyseerr | `http://192.168.1.50:5055` | Unused on this network |

---

## 4. Phase 1: Usenet Accounts

### 4.1 Sign Up for a Provider — Newshosting

1. Go to **[newshosting.com](https://www.newshosting.com)**

2. **Look for the best deal.** Newshosting's front-page price is usually higher
   than their promotional deals. Try these:
   - Go directly to `newshosting.com/special-offers` or
     `newshosting.com/deals`
   - Search Reddit: `newshosting deal site:reddit.com/r/usenet`
   - Look for yearly plans around **$25-30/year** (not monthly)

3. **What you're buying:**
   - Unlimited downloads (some plans have caps — avoid those)
   - 30-60 simultaneous connections
   - SSL encryption included
   - 5,800+ days retention

4. **After purchase**, you'll receive (via email or account dashboard):
   - **Server hostname**: e.g., `news.newshosting.com`
   - **Port**: typically `563` (SSL) or `119` (non-SSL) — **use 563**
   - **Username**: usually your email address
   - **Password**: auto-generated or set by you
   - **Max connections**: typically 30 or 60

   **Save these credentials.** You'll enter them into SABnzbd in Phase 4.

### 4.2 Sign Up for an Indexer — NZBGeek

1. Go to **[nzbgeek.info](https://nzbgeek.info)**

2. Click **Register** (top-right) and create an account

3. Choose a plan:
   - **Free**: 15 API hits + 5 NZB downloads per day (good for testing)
   - **Geek** (~$12/year): Unlimited API + 200 NZB downloads/day
   - **Geek VIP** (~$80 lifetime): Unlimited everything, one-time payment

   If you plan to use this long-term, the lifetime VIP pays for itself in under
   7 years. It's one of the best deals in the Usenet ecosystem.

4. **After purchase**, find your API key:
   - Click your **username** (top-right) → **Profile**
   - Your API key is displayed prominently
   - Note the **API endpoint**: `https://api.nzbgeek.info`

5. **Save the API key.** You'll enter it into Prowlarr in Phase 5.

### 4.3 Optional: Backup Indexer — NZBPlanet

1. Go to **[nzbplanet.net](https://nzbplanet.net)**
2. Register and choose a plan (they often have $10/year or $50 lifetime deals)
3. Get your API key from your profile
4. You'll add this as a second indexer in Prowlarr

### 4.4 What NOT to Buy Yet

- **VPN**: Not needed for Usenet. You connect directly to a server via SSL.
  There is no peer-to-peer component, so your IP is not exposed to anyone
  except your provider (who already has your payment info).
- **Block accounts**: Start without one. If you see "missing articles" errors
  in SABnzbd for more than ~5% of downloads, then consider a block account
  from a different backbone.
- **Multiple providers**: One good provider is enough for 95% of content.

---

## 5. Phase 2: TrueNAS Setup

We need to make two changes on TrueNAS:
1. Add an NFS export for the **root** dataset (so hardlinks work across all
   subdirectories)
2. The download staging directory will be created under Movies (which is 777)

### 5.1 Log Into TrueNAS

Open `https://192.168.1.218` and log in with the `tech` account (or your
admin account).

### 5.2 Add NFS Export for the Root Dataset

> **Note**: The download staging directory will be created later under Movies
> (which has open permissions). No separate ZFS dataset is needed — it's just a
> subdirectory that inherits Movies' 777 permissions.

> **Why this is critical**: Currently, TrueNAS exports each dataset individually
> (`/mnt/WD_10TB/Movies`, `/mnt/WD_10TB/TV`, etc.). For hardlinks to work
> between the download staging area and `Movies`/`TV`/`Anime`, we need Docker to see them all
> under a **single mount point**. We add an NFS export for the root dataset
> (`/mnt/WD_10TB`) that covers everything.

1. In the left sidebar, click **Shares**

2. Click the **NFS** tab (or "Unix Shares (NFS)")

3. Click **Add NFS Share**

4. Configure the NFS share:
   - **Path**: Click browse and select `/mnt/WD_10TB` (the root dataset)
   - **Maproot User**: Select `tech`
   - **Maproot Group**: Select `tech`
   - **Networks**: Add `192.168.1.0/24`
   - **Description**: `Root dataset for ARR stack hardlinks`
   - Leave other settings at defaults

   > **What "maproot" means**: Any user accessing this NFS share (including
   > root on the client) is treated as the `tech` user on TrueNAS. This is
   > safe because the share is restricted to our LAN.

5. Click **Save**

6. Verify the NFS service is running:
   - Click the **Services** icon (top-right, looks like a toggle switch)
   - Find **NFS** in the list
   - If it shows a play icon, click it to start the service
   - Enable **Start Automatically** if not already enabled

   Or via the top bar: **System Settings → Services → NFS → Start**

7. The existing individual dataset exports (`/mnt/WD_10TB/Movies`, etc.) can
   stay in place. Jellyfin on VM 102 continues to use them. Having both the root
   and individual exports active simultaneously is perfectly fine — NFS clients
   can mount whichever they need.

### 5.3 Verify the Setup

On the TrueNAS shell (or via SSH to `tech@192.168.1.218`):

```bash
# Check the dataset was created
zfs list -r WD_10TB

# Check NFS exports
showmount -e
# Should show both the root and individual datasets:
# /mnt/WD_10TB            192.168.1.0/24
# /mnt/WD_10TB/Movies     192.168.1.0/24
# /mnt/WD_10TB/TV         192.168.1.0/24
# /mnt/WD_10TB/Anime      192.168.1.0/24
# /mnt/WD_10TB/Shows      192.168.1.0/24
```

---

## 6. Phase 3: VM 103 Setup

Now we shift to VM 103 (`ubuntu-docker`, 192.168.1.50). All commands below are
run on this VM.

### 6.1 SSH Into VM 103

```powershell
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50
```

### 6.2 Install the NFS Client

Ubuntu cloud images don't include NFS client packages by default:

```bash
sudo apt update
sudo apt install -y nfs-common
```

Verify the installation:
```bash
dpkg -l | grep nfs-common
# Should show: ii  nfs-common  ...
```

### 6.3 Test the NFS Mount

First, test that the export is reachable:

```bash
# Check what NFS exports are available from TrueNAS
showmount -e 192.168.1.218
```

You should see the root dataset among the exports:
```
/mnt/WD_10TB            192.168.1.0/24
/mnt/WD_10TB/Movies     192.168.1.0/24
/mnt/WD_10TB/TV         192.168.1.0/24
/mnt/WD_10TB/Anime      192.168.1.0/24
/mnt/WD_10TB/Shows      192.168.1.0/24
```

Now test mounting:

```bash
# Create the mount point
sudo mkdir -p /mnt/truenas

# Test mount (temporary, will disappear on reboot)
sudo mount -t nfs 192.168.1.218:/mnt/WD_10TB /mnt/truenas

# Verify
ls /mnt/truenas
# Should show: Anime Movies Shows TV

# Check we can write
touch /mnt/truenas/Movies/.usenet/test.txt
ls -la /mnt/truenas/Movies/.usenet/test.txt
rm /mnt/truenas/Movies/.usenet/test.txt
```

If `ls` shows the datasets and the write test succeeds, the NFS mount is working.

### 6.4 Make the Mount Permanent (fstab)

Add an entry to `/etc/fstab` so the mount persists across reboots:

```bash
# Add to fstab
echo "192.168.1.218:/mnt/WD_10TB /mnt/truenas nfs defaults,hard,intr,nfsvers=3 0 0" | sudo tee -a /etc/fstab
```

**What the fstab options mean:**
| Option | Meaning |
|--------|---------|
| `defaults` | Standard mount options (rw, suid, dev, exec, auto, nouser) |
| `hard` | If NFS server is unreachable, retry indefinitely (vs. `soft` which gives up) |
| `intr` | Allow interrupts (Ctrl+C) during hung NFS operations |
| `nfsvers=3` | Use NFSv3 (simpler, more compatible than v4 for Docker volumes) |
| `0 0` | Don't dump (backup) and check last (fsck doesn't apply to NFS) |

### 6.5 Create the Download Subdirectories

```bash
# Create the directory structure for SABnzbd
sudo mkdir -p /mnt/truenas/Movies/.usenet/{incomplete,complete}
```

Since the NFS maproot is `tech` (UID 1000), these directories should already be
owned by `tech:tech`. Verify:

```bash
ls -la /mnt/truenas/Movies/.usenet/
# drwxr-xr-x  tech tech  incomplete/
# drwxr-xr-x  tech tech  complete/
```

If the owner is different (e.g., `root`), fix it:
```bash
sudo chown 1000:1000 /mnt/truenas/Movies/.usenet/{incomplete,complete}
```

### 6.6 Reload systemd and Verify

```bash
# Reload systemd to pick up the new fstab entry
sudo systemctl daemon-reload

# Verify the fstab entry is valid
sudo mount -a
# (No output means success)

# Check the mount is listed
mount | grep truenas
# Should show: 192.168.1.218:/mnt/WD_10TB on /mnt/truenas type nfs (...)

# Verify all datasets are visible
ls -la /mnt/truenas/
# Should show: Anime/ Movies/ Shows/ TV/
```

### 6.7 Deploy the Docker Compose Stack

Create the directory structure for our compose file and persistent configs:

```bash
sudo mkdir -p /opt/arr-stack/config/{sabnzbd,prowlarr,sonarr,radarr,jellyseerr}
```

Create the `docker-compose.yml` file:

```bash
sudo nano /opt/arr-stack/docker-compose.yml
```

Paste the following (adjust `TZ` to your timezone):

```yaml
---
services:
  # ────────────────────────────────────────────────────────────
  # SABnzbd — Usenet Download Client
  # Downloads articles from Usenet providers, assembles +
  # repairs + unpacks files, notifies *arr apps when complete.
  # ────────────────────────────────────────────────────────────
  sabnzbd:
    image: lscr.io/linuxserver/sabnzbd:latest
    container_name: sabnzbd
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Chicago
    volumes:
      - ./config/sabnzbd:/config
      - /mnt/truenas:/data
    ports:
      - "8080:8080"
    networks:
      - arr_network

  # ────────────────────────────────────────────────────────────
  # Prowlarr — Indexer Manager
  # Centralized indexer configuration, pushed to Sonarr/Radarr
  # automatically. Search + RSS feeds for new releases.
  # ────────────────────────────────────────────────────────────
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Chicago
    volumes:
      - ./config/prowlarr:/config
    ports:
      - "9696:9696"
    networks:
      - arr_network

  # ────────────────────────────────────────────────────────────
  # Sonarr — TV Show & Anime Automation
  # Monitors for new episodes, sends NZBs to SABnzbd,
  # imports + renames + organizes into /data/TV and /data/Anime.
  # ────────────────────────────────────────────────────────────
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Chicago
    volumes:
      - ./config/sonarr:/config
      - /mnt/truenas:/data
      - /mnt/truenas/Movies/.usenet:/data/usenet
    ports:
      - "8989:8989"
    networks:
      - arr_network
    depends_on:
      - sabnzbd
      - prowlarr

  # ────────────────────────────────────────────────────────────
  # Radarr — Movie Automation
  # Same as Sonarr but for movies. Imports into /data/Movies
  # and /data/Anime for anime films.
  # ────────────────────────────────────────────────────────────
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Chicago
    volumes:
      - ./config/radarr:/config
      - /mnt/truenas:/data
      - /mnt/truenas/Movies/.usenet:/data/usenet
    ports:
      - "7878:7878"
    networks:
      - arr_network
    depends_on:
      - sabnzbd
      - prowlarr

  # ────────────────────────────────────────────────────────────
  # Jellyseerr — Media Request UI
  # Netflix-like interface for requesting movies and TV shows.
  # Integrates with Jellyfin to show what's already available.
  # ────────────────────────────────────────────────────────────
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    restart: unless-stopped
    environment:
      - TZ=America/Chicago
    volumes:
      - ./config/jellyseerr:/app/config
    ports:
      - "5055:5055"
    networks:
      - arr_network

networks:
  arr_network:
    driver: bridge
```

### 6.8 Understanding the Compose File

Let's break down the important parts:

#### PUID and PGID

```yaml
environment:
  - PUID=1000
  - PGID=1000
```

- **1000** is the UID/GID of the `tech` user on TrueNAS
- The NFS export is configured with `maproot=tech`, so any user accessing the
  share gets mapped to `tech` (UID 1000) on TrueNAS
- By setting the containers to run as UID 1000, files they create on the NFS
  share will be owned by `tech:tech` — matching Jellyfin's access
- This avoids permission problems where containers create files as root and
  Jellyfin can't read them

#### Volume Mounts — The Key Difference

```yaml
# All containers share the SAME mount — this ensures SABnzbd reports
# paths that Sonarr/Radarr can actually see for imports.
sabnzbd: & radarr: & sonarr:
  volumes:
    - /mnt/truenas:/data

# Sonarr and Radarr need the ENTIRE pool — for hardlinks!
sonarr: & radarr:
  volumes:
    - /mnt/truenas:/data
```

**Why Sonarr/Radarr mount the entire pool**: When SABnzbd finishes a download,
it's at `/data/Movies/.usenet/complete/Some.Release/`. Sonarr needs to import it to
`/data/TV/Show Name/Season 01/Episode.mkv`. Since both paths are under the same
`/mnt/truenas` mount, the Linux kernel sees them as the same filesystem, and
hardlinks work.

If Sonarr only mounted `/mnt/truenas/TV` and SABnzbd mounted
`/mnt/truenas/Movies/.usenet`, the cross-volume hardlink would fail — Sonarr would
fall back to a slow file copy.

#### Network Isolation

```yaml
networks:
  arr_network:
    driver: bridge
```

All containers share `arr_network`. This means:
- Containers reach each other by name: `http://sonarr:8989`, `http://sabnzbd:8080`
- These internal URLs are stable and never change
- The ports exposed to the host (`8080:8080`, etc.) are for your browser access

### 6.9 Start the Stack

```bash
cd /opt/arr-stack

# Pull images and start containers in detached mode
sudo docker compose up -d
```

You'll see output like:
```
[+] Running 6/6
 ✔ Network arr-stack_arr_network  Created
 ✔ Container sabnzbd              Started
 ✔ Container prowlarr             Started
 ✔ Container sonarr               Started
 ✔ Container radarr               Started
 ✔ Container jellyseerr           Started
```

Wait about 30 seconds for all apps to initialize, then verify:

```bash
sudo docker compose ps
```

All 5 containers should show `Up` status:

```
NAME          IMAGE                                STATUS
sabnzbd       lscr.io/linuxserver/sabnzbd:latest   Up 30 seconds
prowlarr      lscr.io/linuxserver/prowlarr:latest   Up 30 seconds
sonarr        lscr.io/linuxserver/sonarr:latest     Up 30 seconds
radarr        lscr.io/linuxserver/radarr:latest     Up 30 seconds
jellyseerr    fallenbagel/jellyseerr:latest          Up 30 seconds
```

You can also check from Portainer: `https://192.168.1.50:9443`

---

## 7. Phase 4: SABnzbd Configuration

Open `http://192.168.1.50:8080` in your browser.

### 7.1 Initial Setup Wizard

SABnzbd has a first-run wizard that walks you through the basics:

**Step 1 — Language**
- Select your preferred language
- Click **Start Wizard**

**Step 2 — Server Details**
This is where you enter your Newshosting credentials:

| Field | Value | Notes |
|-------|-------|-------|
| **Host** | `news.newshosting.com` | Or whatever your provider gave you |
| **Port** | `563` | SSL port — always use this |
| **Username** | Your Newshosting username | Usually your email |
| **Password** | Your Newshosting password | |
| **Connections** | `15` | Start conservative. You can increase later. |
| **SSL** | ✅ Checked | **Always enable SSL** |
| **Server Priority** | `0` | Primary server |

After filling in, click **Test Server**. You should see:
```
Connection Successful!
```

If it fails:
- Check your username/password (try logging into Newshosting's website to
  verify)
- Try port `443` or `8080` (some ISPs block port 563, though rare)
- Make sure SSL is checked
- Check VM 103 can reach the internet: `curl -I https://news.newshosting.com`

**Step 3 — General Settings**
- **Web Interface**: Set to whatever you prefer. The default is fine.
  - Access: `Full Web Interface`
  - Listening port: `8080` (pre-filled)
- Click through

**Step 4 — Restart**
- SABnzbd restarts to apply settings
- You may need to reload the page

### 7.2 Configure Download Folders

After the wizard, you're on the main SABnzbd dashboard. Configure the folders:

1. Click the **gear icon** (⚙) in the top-right → **Folders** tab

2. Set the following paths (these are paths **inside the container**):

| Field | Value |
|-------|-------|
| **Temporary Download Folder** | `/data/Movies/.usenet/incomplete` |
| **Completed Download Folder** | `/data/Movies/.usenet/complete` |
| **Watched Folder** | Leave blank (we don't use watch folders) |

3. Scroll down and set:

| Field | Value |
|-------|-------|
| **Permissions for completed downloads** | `777` |

> Setting permissions to 777 (with the NFS maproot) ensures the *arr apps can
> read and move files regardless of the original permissions from the download.

4. Click **Save Changes** at the bottom

### 7.3 Tuning Performance

Go to **Config → General** (the lightbulb icon) → **Tuning** tab:

**Maximum line speed:**
Set this to about 80% of your internet download speed, in **bytes per second**.

| Your Internet Speed | Value to Set |
|---------------------|--------------|
| 100 Mbps | `10000000` (10 MB/s) |
| 200 Mbps | `20000000` (20 MB/s) |
| 500 Mbps | `50000000` (50 MB/s) |
| 1 Gbps | `100000000` (100 MB/s) |

> **Why 80%?** SABnzbd also needs bandwidth for article assembly, par2 repair,
> and unpacking. Leaving headroom prevents it from saturating your connection
> and impacting other LAN traffic.

**Article Cache Limit:**
Set to `1G` (1 GB). This determines how much RAM SABnzbd uses to buffer
downloaded articles before writing to disk. More cache = fewer disk writes,
which matters since we're writing to NFS.

**Save** when done.

### 7.4 Categories (Important!)

Categories tell Sonarr and Radarr where to look for their downloads:

1. Go to **Config → Categories**

2. The default categories should already exist. Verify (or add) these:

| Category | Priority | Processing | Folder/Path | Indexer Categories |
|----------|----------|------------|-------------|--------------------|
| `tv` | Normal | Default | (empty — uses root complete folder) | `TV` |
| `movies` | Normal | Default | (empty — uses root complete folder) | `Movies` |
| `anime` | Normal | Default | (empty — uses root complete folder) | `TV > Anime` |

> **What this means**: When Sonarr sends an NZB tagged as `tv`, SABnzbd puts
> the completed download in `/data/usenet/complete/tv/Show.Name.S01E01/`.
> Sonarr then looks in that category folder to find the download.

3. Click **Save**

### 7.5 Get the API Key

You'll need SABnzbd's API key for Sonarr and Radarr:

1. Go to **Config → General** → **Security** tab
2. Under **API Key**, you'll see a long string
3. Copy this API key
4. You can also find it by clicking the **key icon** (🔑) in the top bar

Keep this API key handy — you'll paste it into Sonarr and Radarr.

### 7.6 Test a Download (Optional, Recommended)

To verify everything works end-to-end:

1. In SABnzbd, click **+ Add NZB** (top-left)
2. Click **Browse** or paste a URL (if you have a test NZB file)
3. If you have no NZB to test with, skip this — we'll test via Sonarr in Phase 9

---

## 8. Phase 5: Prowlarr Configuration

Open `http://192.168.1.50:9696` in your browser.

### 8.1 Initial Setup

1. Prowlarr will prompt you to create a login. Set a username and password.
2. Skip the proxy setup unless you use one.

### 8.2 Add Your Indexers

1. Click **Indexers** in the left sidebar
2. Click **Add Indexer** (the big **+** button)
3. In the search box, type `NZBGeek`
4. Select **NZBGeek** from the dropdown

5. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `NZBGeek` |
| **API Key** | Your NZBGeek API key |
| **API URL** | `https://api.nzbgeek.info` |
| **Base URL** | `https://api.nzbgeek.info` |

6. Click **Test** at the bottom. You should see a green checkmark.

7. Click **Save**

8. (Optional) Repeat for NZBPlanet or any other indexer:
   - Click **Add Indexer** → search for `NZBPlanet` → enter API key

### 8.3 Configure Indexer Sync to Sonarr/Radarr

> **Important**: You need Sonarr and Radarr API keys first. At this point,
> those apps are running but unconfigured. You have two options:
>
> **Option A**: Set up a password in Sonarr/Radarr first (open each, go to
> Settings → General, set a password, copy the API key), then come back here.
>
> **Option B**: Continue reading, set up Sonarr/Radarr in Phases 6-7, then
> return here to connect them. This guide follows Option B.

1. Go to **Settings → Apps**

2. Click the **+** button to add an application

3. **Add Sonarr**:
   - **Application**: `Sonarr`
   - **Sync Level**: `Full Sync` (pushes all indexers to Sonarr)
   - **Tags**: Leave empty
   - **Prowlarr Server**: `http://prowlarr:9696` (pre-filled)
   - **Sonarr Server**: `http://sonarr:8989`
   - **API Key**: (Get from Sonarr Phase 6 — leave blank for now)
   - Click **Test** (will fail without API key) → **Save** anyway

4. **Add Radarr**:
   - Same as above but **Application**: `Radarr`
   - **Radarr Server**: `http://radarr:7878`
   - **API Key**: (Get from Radarr Phase 7)

5. After both are configured with their API keys, go to **Indexers** and click
   the **Sync All Indexers** button (circular arrows icon). This pushes all
   indexers to Sonarr and Radarr.

### 8.4 How Prowlarr Helps (Even Without Search)

Even before you connect Sonarr/Radarr, Prowlarr provides:
- A unified search interface to check if NZBGeek has a particular release
- RSS feed monitoring (configurable intervals)
- A central place to manage all indexers

---

## 9. Phase 6: Sonarr Configuration

Open `http://192.168.1.50:8989` in your browser.

### 9.1 Initial Setup

1. Sonarr will prompt you to create a login username and password.
2. After logging in, you'll see the main dashboard (empty, no shows yet).

### 9.2 Media Management

1. Go to **Settings → Media Management** (left sidebar)

2. **Episode Naming**:
   - Check: ✅ **Rename Episodes**
   - This ensures downloaded episodes follow a consistent naming pattern

3. **Importing** (scroll down):
   - ✅ **Use Hardlinks instead of Copy**
   - This is critical — we designed the entire storage layout around it

4. **Root Folders** (at the very top of the page):
   - Click **Add Root Folder**
   - Browse to `/data/TV`
   - Click **OK**
   - Add a second root folder: `/data/Anime`
   - Result: Two root folders listed

   > **Root folders explained**: When you add a TV show to Sonarr, you choose
   > which root folder it belongs to. All episodes for that show go into
   > `RootFolder/Show Name/Season XX/Episode.mkv`.
   >
   > `/data/TV` — for regular TV shows
   > `/data/Anime` — for anime series

### 9.3 Download Client — Connect to SABnzbd

1. Go to **Settings → Download Clients**

2. Click the **+** button → Select **SABnzbd**

3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `SABnzbd` |
| **Host** | `sabnzbd` |
| **Port** | `8080` |
| **API Key** | Paste SABnzbd API key (from Phase 4.5) |
| **Category** | `tv` |

4. Click **Test** — a green checkmark should appear with a SABnzbd version number

5. Click **Save**

### 9.4 Quality Profiles

Quality profiles define what release qualities Sonarr should accept:

1. Go to **Settings → Profiles**

2. The default profiles (Any, HD-720p/1080p, etc.) are a good start.

3. **Recommended initial profile** — edit the "HD-720p/1080p" profile:
   - Enable: `WEBDL-1080p`, `WEBDL-720p`, `Bluray-1080p`, `Bluray-720p`
   - Disable: `HDTV`, `SDTV`, `DVD` (lower quality than needed for 2025+)
   - Set **Upgrade Until**: `Bluray-1080p` (Sonarr will keep upgrading until it
     has a Bluray-1080p copy)

   > **What "Upgrade Until" means**: Sonarr first downloads whatever quality
   > is available. If it downloads a WEBDL-720p, but later a Bluray-1080p
   > appears, Sonarr automatically downloads the upgrade. Set the ceiling to
   > your preferred max quality.

4. Create a second profile for "Ultra-HD" if you want 4K content:
   - Add: `WEBDL-2160p`, `Bluray-2160p`
   - Upgrade until `Bluray-2160p`

### 9.5 Get Sonarr API Key

1. Go to **Settings → General**
2. Copy the **API Key**
3. **Return to Prowlarr** (Phase 5.3) to finish the Prowlarr-Sonarr connection

### 9.6 Indexers (After Prowlarr Sync)

Once Prowlarr has synced:
1. Go to **Settings → Indexers**
2. You should see your indexers listed (synced from Prowlarr)
3. No manual configuration needed here — Prowlarr manages everything

### 9.7 Configure Anime Settings (Optional but Recommended)

If you plan to download anime, enable some anime-specific features:

1. Go to **Settings → Media Management → Show Advanced** (top-right toggle)
2. Scroll down to **Importing**:
   - **Anime Episode Format**: `Absolute Episode Number` (anime uses absolute
     numbering, e.g., "Episode 245" instead of "S05E02")
   - This is per-show and can be changed when adding each show

When adding an anime show to the `/data/Anime` root folder, you'll set the
series type to **Anime** in the add dialog, which enables proper anime episode
parsing.

---

## 10. Phase 7: Radarr Configuration

Open `http://192.168.1.50:7878` in your browser.

Radarr's interface is nearly identical to Sonarr. The steps mirror Phase 6
with movie-specific differences.

### 10.1 Initial Setup

1. Set a username and password.

### 10.2 Media Management

1. **Settings → Media Management**

2. **Movie Naming**:
   - ✅ **Rename Movies**
   - Standard Movie Format: `{Movie Title} ({Release Year}) {Quality Full}`

3. **Importing**:
   - ✅ **Use Hardlinks instead of Copy**

4. **Root Folders**:
   - Add `/data/Movies`
   - Add `/data/Anime` (for anime movies specifically)

### 10.3 Download Client

1. **Settings → Download Clients → + → SABnzbd**

| Field | Value |
|-------|-------|
| **Name** | `SABnzbd` |
| **Host** | `sabnzbd` |
| **Port** | `8080` |
| **API Key** | Same SABnzbd API key |
| **Category** | `movies` |

2. **Test** → **Save**

### 10.4 Quality Profiles

1. **Settings → Profiles**

2. Edit "HD-720p/1080p" or create a new profile:

| Quality | Min Size (MB) | Max Size (MB) |
|---------|---------------|---------------|
| WEBDL-1080p | 0 | Unlimited |
| WEBDL-720p | 0 | Unlimited |
| Bluray-1080p | 0 | Unlimited |
| Bluray-720p | 0 | Unlimited |
| HDTV-1080p | 0 | Unlimited |

3. Set **Upgrade Until**: `Bluray-1080p`

4. Create an "Ultra-HD" profile for 4K movies if desired:
   - WEBDL-2160p, Bluray-2160p
   - Upgrade until `Bluray-2160p`
   - Max sizes adjusted upward (movies are bigger than TV episodes)

### 10.5 Get Radarr API Key

1. **Settings → General** → Copy **API Key**
2. Return to Prowlarr (Phase 5.3) to finish the connection

---

## 11. Phase 8: Jellyseerr Configuration

Open `http://192.168.1.50:5055` in your browser.

Jellyseerr has a first-run setup wizard. Walk through it carefully.

### 11.1 Sign In with Jellyfin

1. **Application Title**: "Homelab" (or whatever you want to call it)

2. **Media Server**: Select **Jellyfin**

3. **Jellyfin Server**:
   - **Hostname or IP Address**: `192.168.1.133`
   - **Port**: `8096`
   - **Use SSL**: Unchecked
   - **URL Base**: Leave blank (unless you have a reverse proxy)

4. Click **Sign In** — you'll be redirected to your Jellyfin login page
   - Enter your Jellyfin credentials
   - Approve the Jellyseerr application

5. After signing in, Jellyseerr will scan your Jellyfin libraries. This may
   take a minute as it catalogs what media you already have.

### 11.2 Add Sonarr

1. **Server type**: `Sonarr`

2. Configure the Sonarr connection:

| Field | Value |
|-------|-------|
| **Hostname or IP Address** | `sonarr` |
| **Port** | `8989` |
| **Use SSL** | Unchecked |
| **API Key** | Sonarr API key (from Phase 6.5) |
| **URL Base** | Leave blank |
| **Quality Profile** | Select your primary TV profile (e.g., "HD-720p/1080p") |
| **Root Folder** | `/data/TV` |
| **Anime Root Folder** | `/data/Anime` |
| **Anime Quality Profile** | Same as above (or a dedicated anime profile) |
| **Language Profile** | (Deprecated in v4 — leave default) |
| **External URL** | `http://192.168.1.50:8989` |
| **Enable Scan** | ✅ Enabled |
| **Enable Automatic Search** | ✅ Enabled |

3. Click **Test** — should succeed

### 11.3 Add Radarr

1. **Server type**: `Radarr`

| Field | Value |
|-------|-------|
| **Hostname or IP Address** | `radarr` |
| **Port** | `7878` |
| **Use SSL** | Unchecked |
| **API Key** | Radarr API key (from Phase 7.5) |
| **Quality Profile** | Select your primary movie profile |
| **Root Folder** | `/data/Movies` |
| **Anime Root Folder** | `/data/Anime` |
| **Anime Quality Profile** | Same as above |
| **Minimum Availability** | `Released` (only request movies that are out) |
| **External URL** | `http://192.168.1.50:7878` |
| **Enable Scan** | ✅ Enabled |
| **Enable Automatic Search** | ✅ Enabled |

2. Click **Test** → should succeed

3. Click **Finish Setup**

### 11.4 Finish Prowlarr Sync

Now that Sonarr and Radarr are fully configured with API keys:

1. Go back to **Prowlarr** (`http://192.168.1.50:9696`)
2. **Settings → Apps**
3. Edit the Sonarr entry → paste the API key → **Test** → **Save**
4. Edit the Radarr entry → paste the API key → **Test** → **Save**
5. Go to **Indexers** → click **Sync All Indexers** (circular arrows icon)
6. Verify: Open Sonarr → Settings → Indexers → indexers should be listed
7. Verify: Open Radarr → Settings → Indexers → indexers should be listed

---

## 12. Phase 9: End-to-End Testing

Time to verify the entire pipeline works.

### 12.1 Test a TV Show Download

**Method A — Via Jellyseerr (recommended):**

1. Open **Jellyseerr** (`http://192.168.1.50:5055`)
2. Search for a TV show you don't have but want (e.g., "The Bear")
3. Click on the show → click **Request**
4. Select seasons (e.g., "Season 1")
5. Click **Submit**

What happens:
1. Jellyseerr tells Sonarr "user requested The Bear, all seasons"
2. Sonarr adds the show to the `/data/TV` root folder, monitors all episodes
3. Sonarr asks Prowlarr/Prowlarr-imported indexers "find episodes of The Bear"
4. An indexer returns NZB files for matching episodes
5. Sonarr sends NZBs to SABnzbd
6. SABnzbd downloads from Newshosting → unpacks to `/data/usenet/complete/tv/`
7. Sonarr detects completion → imports (hardlinks) to `/data/TV/The Bear/Season 01/`
8. Jellyfin scans → new episodes appear

To watch the magic happen:
- **Jellyseerr**: Shows "Requested" → "Processing" → "Available"
- **Sonarr** (`http://192.168.1.50:8989`): Go to **Activity** → see download queue
- **SABnzbd** (`http://192.168.1.50:8080`): Watch the download speed graph and progress
- **Jellyfin** (`http://192.168.1.133:8096`): Episode appears after library scan

**Method B — Directly in Sonarr:**

1. Open Sonarr → **Add New** (top-left)
2. Search for a show → click it → **Add**
3. Choose root folder (`/data/TV` or `/data/Anime`)
4. Choose quality profile, series type, monitoring options
5. Click **Add** (green button)
6. Check **Activity** tab to monitor progress

### 12.2 Test a Movie Download

1. Open **Jellyseerr** → search for a movie
2. Click **Request** → choose quality profile
3. Monitor progress in Radarr (`http://192.168.1.50:7878`) → **Activity**

### 12.3 Verify File Placement

After a successful download, verify the files are in the right place:

```bash
# On VM 103
ls -la /mnt/truenas/TV/
# Should show your downloaded show directories

ls -la /mnt/truenas/Movies/
# Should show your downloaded movie directories

# Verify the download still exists (hardlinked, not moved)
ls -la /mnt/truenas/Movies/.usenet/complete/tv/
# The original file is still here — both paths point to the same data
```

You can confirm it's a hardlink by checking the inode number and link count:

```bash
stat /mnt/truenas/Movies/Some\ Movie/Some\ Movie.mkv
# Look at "Links:" — should be 2 (one in staging, one in Movies)
# Look at "Inode:" — same number for both paths
```

### 12.4 Test Anime (Sonarr with Anime Root Folder)

1. In Sonarr → **Add New** → search for an anime (e.g., "Jujutsu Kaisen")
2. Select **Root Folder**: `/data/Anime`
3. Set **Series Type**: `Anime`
4. Add and monitor

Anime episodes should land in `/mnt/truenas/Anime/Jujutsu Kaisen/` with
absolute episode numbering.

---

## 13. Phase 10: Maintenance and Best Practices

### 13.1 Updating Containers

The linuxserver.io images update frequently. To update:

```bash
cd /opt/arr-stack
sudo docker compose pull          # Pull latest images
sudo docker compose up -d         # Recreate containers with new images
```

You can automate this via a cron job or use **Watchtower** (a Docker container
that auto-updates other containers). However, I recommend manual updates so
you can review changelogs and catch breaking changes.

To check for updates manually:
```bash
sudo docker compose pull --dry-run 2>&1 | grep "Downloaded"
# Shows which images have newer versions
```

### 13.2 Backup the Config

The `./config/` directory contains all settings, API keys, and databases. Back
it up:

```bash
# Manual backup to your workstation
scp -r -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50:/opt/arr-stack/config ./arr-backup-$(Get-Date -Format yyyy-MM-dd)
```

### 13.3 Monitoring Disk Usage

TrueNAS has 8.95 TB free right now. Monitor usage:

```bash
# On VM 103, check NFS mount usage
df -h /mnt/truenas

# On TrueNAS, check ZFS pool
zpool list WD_10TB
zfs list -r -o name,used,available,referenced WD_10TB
```

Set up a cron job or Uptime Kuma to alert when usage exceeds 80%.

### 13.4 Quality Profiles — Fine-Tuning Later

Once the stack is running, you can refine quality profiles. The **TRaSH Guides**
([trash-guides.info](https://trash-guides.info)) provide community-maintained
custom formats and quality settings that:

- Prefer certain release groups over others
- Avoid bad encodes/upscales
- Prefer Dolby Vision/HDR for 4K content
- Set proper audio preferences (Atmos, TrueHD, etc.)

These are set up using **Custom Formats** in Sonarr/Radarr. This is an advanced
step for later — the defaults work fine to start.

### 13.5 Adding More Indexers Later

If you find content is sometimes missing, add more indexers:
1. Sign up for another indexer (NZBPlanet, DrunkenSlug, NinjaCentral, etc.)
2. Add it in Prowlarr → Indexers → Add
3. Sync to Sonarr and Radarr

Having 2-3 indexers dramatically improves content coverage.

### 13.6 Cleanup Old Downloads

SABnzbd will accumulate files in the complete folder. Set up automatic cleanup:

1. In SABnzbd → Config → Switches
2. Under **Post-Processing**:
   - **Cleanup List**: Add extensions to delete after unpack: `.nfo, .sfv, .nzb, .txt, .jpg, .png`
   - **Action when encrypted RAR downloads**: `Abort`
   - **Unwanted Extensions**: `.exe, .com, .bat`

Sonarr and Radarr automatically delete the download folder after importing,
so nothing should accumulate long-term.

### 13.7 Security Considerations

- **No external access configured.** All services are LAN-only on
  `192.168.1.0/24`. Don't forward these ports on your router.
- If you want remote access, use:
  - **Twingate** (already running on VM 103) for VPN-like access
  - Or set up a **reverse proxy** with authentication (e.g., Nginx Proxy
    Manager + Authelia)

---

## 14. Troubleshooting

### Connection Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| SABnzbd can't connect to provider | Wrong port/protocol, ISP blocking | Try ports 563, 443, 8080. Check firewall on VM 103. |
| Sonarr can't connect to SABnzbd | Wrong hostname | Use `sabnzbd` (container name), not IP. Verify both are on `arr_network`. |
| Prowlarr can't connect to Sonarr/Radarr | Wrong API key or hostname | Use `sonarr:8989` and `radarr:7878`. Copy API keys exactly. |
| Jellyseerr can't connect to Jellyfin | Jellyfin on different host | Use `192.168.1.133:8096` (LAN IP, not container name). |

### Download Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "No results found" when searching in Sonarr | Indexers not synced | Prowlarr → Indexers → Sync All. Check Sonarr → Indexers afterward. |
| Downloads fail immediately | NZB file references missing articles | Try a different release. Add block account if persistent. |
| Downloads start but stall at 99% | Missing par2 repair files | Wait longer — SABnzbd is trying to repair. If it fails, the NZB was incomplete. |
| "Aborted, cannot be completed" | Missing too many articles | The content has been DMCA'd. Try a different release or add a block account from another backbone. |

### File/Permission Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Sonarr shows "Import failed: Permission denied" | Container UID doesn't match NFS maproot | Check PUID=1000 in compose file. Verify `tech` user is UID 1000 on TrueNAS. |
| Files appear but Jellyfin can't see them | Permission or library scan issue | Check file ownership: `ls -la /mnt/truenas/Movies/`. Trigger manual scan in Jellyfin. |
| Hardlinks not working (files copied instead) | Different filesystem mount points | Verify `df -h /mnt/truenas/Movies/.usenet` and `df -h /mnt/truenas/Movies` show **the same mount**. If they show different entries, the single root mount isn't set up correctly. |

### NFS Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `mount.nfs: access denied` | NFS export doesn't include VM 103's IP | On TrueNAS, verify the NFS share's Network field includes `192.168.1.0/24`. |
| `mount.nfs: Protocol not supported` | NFS version mismatch | Try `nfsvers=4` instead of `3` in fstab. |
| NFS mount hangs on boot (VM won't start) | TrueNAS not available, systemd waits forever | Add `nofail` to fstab options: `defaults,nofail,hard,intr,nfsvers=3`. |

### Docker Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Container exits immediately | Config directory permissions | `sudo chown -R 1000:1000 /opt/arr-stack/config` |
| Container can't write to /data | NFS mount not ready before Docker | Restart containers: `sudo docker compose restart` |
| Port already in use | Conflict with existing service | Change the host port in compose file (e.g., `8081:8080`) |

### TrueNAS-Specific Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Downloads fill up VM 103 disk, not TrueNAS | Docker volume path typo | Check the compose volume: `- /mnt/truenas/Movies/.usenet:/data/usenet`. Verify with `docker inspect sabnzbd \| grep Mounts`. |
| NFS share not listed in `showmount -e` | NFS service not running | TrueNAS UI → Services → Start NFS. Or `systemctl restart nfs-server`. |

---

## 15. Quick Reference

### URLs

All services accessible via direct IP (LAN) or Traefik subdomain (HTTPS):

| Service | Direct (LAN) | Subdomain (HTTPS) | Notes |
|---------|-------------|-------------------|-------|
| **Jellyseerr** (request) | `http://192.168.1.50:5055` | `https://jellyseerr.nkhl.co.uk` | Primary interface |
| **Sonarr** (TV) | `http://192.168.1.50:8989` | `https://sonarr.nkhl.co.uk` | TV show management |
| **Radarr** (Movies) | `http://192.168.1.50:7878` | `https://radarr.nkhl.co.uk` | Movie management |
| **Prowlarr** (Indexers) | `http://192.168.1.50:9696` | `https://prowlarr.nkhl.co.uk` | Indexer manager |
| **SABnzbd** (Downloads) | `http://192.168.1.50:8080` | `https://sabnzbd.nkhl.co.uk` | Download client |
| **Bazarr** (Subtitles) | `http://192.168.1.50:6767` | `https://bazarr.nkhl.co.uk` | Subtitle manager |
| **Portainer** (Docker) | `https://192.168.1.50:9443` | `https://portainer.nkhl.co.uk` | Container management |
| **Jellyfin** (Watch) | `http://192.168.1.133:8096` | `https://jellyfin.nkhl.co.uk` | Media player |
| **TrueNAS** (Storage) | `https://192.168.1.218` | `https://truenas.nkhl.co.uk` | NAS management |
| **OpenBao** (Secrets) | `http://192.168.1.50:8200` | `https://openbao.nkhl.co.uk` | Credential storage |
| **Traefik** (Proxy) | — | `https://traefik.nkhl.co.uk` | Dashboard (basic auth) |

### Important Paths (VM 103)

| Path | Purpose |
|------|---------|
| `/opt/arr-stack/docker-compose.yml` | Compose file — edit here to change config |
| `/opt/arr-stack/config/` | All container persistent data |
| `/mnt/truenas/` | TrueNAS NFS mount point |
| `/mnt/truenas/Movies/.usenet/` | SABnzbd download staging |
| `/mnt/truenas/Movies/` | Radarr movie library |
| `/mnt/truenas/TV/` | Sonarr TV library |
| `/mnt/truenas/Anime/` | Sonarr/Radarr anime library |

### Useful Docker Commands

```bash
# View all ARR containers
sudo docker compose -f /opt/arr-stack/docker-compose.yml ps

# Follow logs for all containers
sudo docker compose -f /opt/arr-stack/docker-compose.yml logs -f

# Follow logs for a single container
sudo docker compose -f /opt/arr-stack/docker-compose.yml logs -f sonarr

# Restart a single container
sudo docker compose -f /opt/arr-stack/docker-compose.yml restart radarr

# Stop the entire stack
sudo docker compose -f /opt/arr-stack/docker-compose.yml down

# Start the stack
sudo docker compose -f /opt/arr-stack/docker-compose.yml up -d

# Pull latest images and recreate
sudo docker compose -f /opt/arr-stack/docker-compose.yml pull
sudo docker compose -f /opt/arr-stack/docker-compose.yml up -d
```

### API Keys (Keep These)

| Service | Where to Find | Used By |
|---------|--------------|---------|
| SABnzbd | Config → General → API Key | Sonarr, Radarr |
| Sonarr | Settings → General → API Key | Prowlarr, Jellyseerr |
| Radarr | Settings → General → API Key | Prowlarr, Jellyseerr |
| NZBGeek | Profile page | Prowlarr |
| Newshosting | Account dashboard | SABnzbd |

### Boot Order Dependency

```
1. Router (192.168.1.1)      — always on
2. Proxmox (192.168.1.200)   — hypervisor
3. TrueNAS (192.168.1.218)   — NFS shares must be available
4. VM 103 (192.168.1.50)     — mounts NFS, starts Docker → ARR stack
5. VM 102 (192.168.1.133)    — mounts NFS, starts Jellyfin
```

> If VM 103 boots before TrueNAS is ready, the NFS mount will fail and Docker
> containers won't have access to `/mnt/truenas`. Add `nofail` to the fstab
> entry if this causes boot issues, and restart Docker after NFS is up:
> `sudo mount -a && sudo docker compose -f /opt/arr-stack/docker-compose.yml up -d`

---

*This guide was created for the Homelab environment described in
`INFRASTRUCTURE.md` and `SERVICES.md`. Update those files when you've completed
the setup to reflect the new services.*
