# Homelab Troubleshooting Guide

Last Updated: 2026-07-21

This guide covers common issues with the ARR stack (Sonarr, Radarr, Prowlarr, SABnzbd, Jellyseerr) and Jellyfin. Work through steps in order — each step assumes the previous ones are working.

---

## Table of Contents

1. [Boot Order & VM Dependencies](#1-boot-order--vm-dependencies)
2. [Quick Fixes (One-Liners)](#2-quick-fixes-one-liners)
3. [8-Step Diagnostic Flowchart](#3-8-step-diagnostic-flowchart)
4. [Common Error Messages & Solutions](#4-common-error-messages--solutions)
5. [Quality Profile Fixes](#5-quality-profile-fixes)
6. [Manual Import in Sonarr/Radarr](#6-manual-import-in-sonarrradarr)
7. [NFS Troubleshooting](#7-nfs-troubleshooting)
8. [Jellyfin Scan & Library Issues](#8-jellyfin-scan--library-issues)
9. [Container Stale Mount Recovery](#9-container-stale-mount-recovery)
10. [Key Paths & Credentials Reference](#10-key-paths--credentials-reference)
11. [Quality Profile: Episodes Rejected Despite "Any" Profile](#11-quality-profile-episodes-rejected-despite-any-profile)
12. [Files Stuck in Complete Folder (Manual Bypass)](#12-files-stuck-in-complete-folder-manual-bypass)
13. [Jellyseerr Not Finding a Show](#13-jellyseerr-not-finding-a-show)
14. [Ultra-HD Profile Blocking 1080p Releases](#14-ultra-hd-profile-blocking-1080p-releases)
15. [Show Requests But Nothing Appears — Verify It's Actually Downloading](#15-show-requests-but-nothing-appears--verify-its-actually-downloading)

---

## 1. Boot Order & VM Dependencies

```
1. Router (192.168.1.1)      — Always on
      │
2. Proxmox (192.168.1.200)   — Always on
      │
3. VM 100 (TrueNAS)          — MUST boot FIRST
      │   Provides NFS shares. If down:
      │   • No storage for downloads
      │   • SABnzbd shows wrong free space
      │   • Jellyfin library empty
      │
4. VM 103 (ubuntu-docker)    — Boots second
      │   Mounts NFS, starts Docker ARR stack + Jellyfin
      │   If TrueNAS down at boot: fstab has nofail, mount point is empty local dir
      │
5. VM 102 (Debian13)         — OFFLINE (no longer needed)
          All services migrated to VM 103 (2026-07-20)
```

**Proxmox Start/Shutdown Order** (recommended):

```
Datacenter → Options → Start/Shutdown Order:
  1. VM 100 (TrueNAS) — Start order: 1, delay: 120s
  2. VM 103 (ubuntu-docker) — Start order: 2, delay: 30s
  3. VM 102 (Debian13) — Start order: 3, delay: 30s
```

---

## 2. Quick Fixes (One-Liners)

### Stale NFS Mount After VM Boot

The most common issue: Docker containers started before the NFS mount was ready. They have a stale, empty view of the filesystem.

```bash
# On VM 103 (fixes ARR stack)
sudo mount -a && sudo docker restart sabnzbd sonarr radarr

# On VM 102 (fixes Jellyfin)
sudo mount -a && echo 7164085 | sudo -S docker restart jellyfin
```

### Force Re-Sync Indexers from Prowlarr

```bash
# From VM 103
curl -s -X POST \
  --header 'X-Api-Key: 0ed144577e604989ab3f213fca6b3760' \
  'http://192.168.1.50:9696/api/v1/application/action/sync/1'   # Sonarr (ID 1)
curl -s -X POST \
  --header 'X-Api-Key: 0ed144577e604989ab3f213fca6b3760' \
  'http://192.168.1.50:9696/api/v1/application/action/sync/2'   # Radarr (ID 2)
```

### Trigger Library Scan on Jellyfin

```bash
# From VM 102
curl -s -X POST "http://localhost:8096/Library/Refresh?api_key=YOUR_API_KEY"
```

Alternative: open Jellyfin UI → Dashboard → Libraries → Scan All Libraries.

---

## 3. 8-Step Diagnostic Flowchart

When episodes show "downloaded" in Sonarr but don't appear in Jellyfin:

```
┌─────────────────────────────────────────────────────────┐
│  "Episodes downloaded but not in Jellyfin"              │
└────────────────────────┬────────────────────────────────┘
                         ▼
            ┌────────────────────────┐
            │ Step 1: TrueNAS up?    │
            │ Proxmox → VM 100 check │
            └───────┬────────────────┘
                    │
          ┌─────────┴─────────┐
          │ YES               │ NO → Start VM 100, wait 2 min, continue
          ▼                   │
   ┌──────────────────┐      │
   │ Step 2: NFS on    │      │
   │ VM 103?           │      │
   │ mount | grep nfs  │      │
   └───────┬───────────┘      │
           │                  │
   ┌───────┴────────┐        │
   │ YES            │ NO → sudo mount -a
   ▼                │
   ┌──────────────────────────┐
   │ Step 3: Files on disk?   │
   │ ls /mnt/truenas/Shows/   │
   │ (or Anime/ or Movies/)   │
   └───────┬──────────────────┘
           │
   ┌───────┴────────┐
   │ YES            │ NO → Go to Step 6
   ▼                │
   ┌──────────────────────────┐
   │ Step 4: NFS on           │
   │ VM 102?                  │
   │ SSH to VM 102: mount     │
   └───────┬──────────────────┘
           │
   ┌───────┴────────┐
   │ YES            │ NO → sudo mount -a on VM 102
   ▼                │
   ┌──────────────────────────────┐
   │ Step 5: Jellyfin sees files? │
   │ sudo docker exec jellyfin    │
   │ ls /media/Shows/             │
   └───────┬──────────────────────┘
           │
   ┌───────┴────────┐
   │ YES            │ NO → sudo docker restart jellyfin
   ▼                │
   ┌──────────────────────┐
   │ Step 5a: Scan libs   │
   │ Jellyfin → Dashboard  │
   │ → Libraries → Scan    │
   └──────────────────────┘
           │
           ▼
   ┌──────────────────────────┐
   │ Step 6: Files in         │
   │ .usenet/complete/ ?      │
   │ ls /mnt/truenas/Movies/  │
   │ .usenet/complete/        │
   └───────┬──────────────────┘
           │
   ┌───────┴────────┐
   │ YES            │ NO → Search NZBGeek found nothing
   ▼                │       → Check indexer capabilities
   │                │       → Check quality profile
   ┌──────────────────────────────┐
   │ Step 7: Manual Import        │
   │ Sonarr → ONE PIECE (2023)    │
   │ → Manual Import → browse to  │
   │ /data/Movies/.usenet/complete│
   │ Select episode → Import      │
   └──────────────────────────────┘
           │
           ▼
   ┌──────────────────────┐
   │ Step 8: Scan Jellyfin │
   │ Dashboard → Libraries │
   │ → Scan All Libraries  │
   └──────────────────────┘
```

---

## 4. Common Error Messages & Solutions

### 4.1 "Permission denied: '/data/Movies'"

**Full error**:
```
PermissionError: [Errno 13] Permission denied: '/data/Movies'
/data/Movies/.usenet/complete is not writable at all
```

**Cause**: NFS mount dropped. `/mnt/truenas/` is an empty local directory owned by root.

**Fix**:
```bash
# On VM 103
sudo mount -a
sudo docker restart sabnzbd
```

**Verify**: SABnzbd should show ~8.5 TB free (TrueNAS), not ~21 GB (local disk).

---

### 4.2 "Import failed, path does not exist or is not accessible"

**Full error**:
```
Import failed, path does not exist or is not accessible by Sonarr: 
/data/Movies/.usenet/complete/Show.Name/
```

**Cause A**: Stale Docker mount — container started before NFS was active.  
**Fix A**:
```bash
sudo docker restart sabnzbd sonarr radarr
```

**Cause B**: NFS mount completely gone.  
**Fix B**:
```bash
sudo mount -a
sudo docker restart sabnzbd sonarr radarr
```

---

### 4.3 "No files found are eligible for import"

**Full error**:
```
No files found are eligible for import in 
/data/Movies/.usenet/complete/Show.Name.S01E01.2160p/
```

**Cause A**: Quality profile rejecting the file format (e.g., Ultra-HD profile rejecting WEBDL-2160p).

**Fix A**: Change quality profile to "Any" in Sonarr → Series → Edit → Quality Profile.

**Cause B**: Indexer capabilities missing (Search/RSS = None in Sonarr).

**Fix B**: In Prowlarr → Settings → Apps → re-save indexer → Sync All Indexers. If issue persists, the indexer capabilities need to be manually injected (see Section 5).

---

### 4.4 "SABnzbd shows 21.5 GB free" (instead of 8.9 TB)

**Cause**: NFS mount dropped. SABnzbd is seeing the local VM disk.

**Fix**:
```bash
sudo mount -a
sudo docker restart sabnzbd
```

**Verify**: SABnzbd should now show ~8.5 TB free space.

---

### 4.5 "mount.nfs: access denied" on VM 102 or VM 103

**Cause**: TrueNAS NFS export missing or network not allowed.

**Fix**: Check TrueNAS NFS shares:
1. Go to TrueNAS UI → Shares → NFS
2. Verify `/mnt/WD_10TB` is exported with mapall_user=tech, mapall_group=tech
3. Verify Networks includes `192.168.1.0/24`
4. Restart NFS service if needed

---

## 5. Quality Profile Fixes

### Problem: Downloads complete but never import

**Check**: What quality profile is the series using?

```bash
# From VM 103, find series ID and profile
curl -s "http://192.168.1.50:8989/api/v3/series?apikey=b2f4370131d143e49f8630157f1cf6a4" | grep -o '"title":"[^"]*"' | head -10
```

Look for the series, find its `qualityProfileId`, then check if the profile allows the downloaded quality.

**Common fix**: Change profile to "Any" (ID 1) in Sonarr UI: Series → Edit → Quality Profile → Any.

### Problem: Indexer capabilities show "None"

**Check**:
```bash
curl -s "http://192.168.1.50:8989/api/v3/indexer?apikey=b2f4370131d143e49f8630157f1cf6a4" | grep -o '"supportsSearch":[a-z]*' | sort | uniq -c
```

If it shows `supportsSearch:false` or is missing, manual search works but automated search doesn't.

**Fix**: Go to Prowlarr → Settings → Apps → edit Sonarr → re-save → Sync All Indexers. If that doesn't work, re-sync via API (see Section 2).

---

## 6. Manual Import in Sonarr/Radarr

Use this when files are in `complete/` but Sonarr/Radarr didn't import them:

### In Sonarr
1. Go to the series → click **Manual Import** (top bar)
2. Browse to `/data/Movies/.usenet/complete/`
3. Find the episode folder → click **Import**
4. Sonarr moves the file to the correct media folder and renames it

### Via Command Line (Emergency)
```bash
# Find files in complete/ but not in media folder
ls /mnt/truenas/Movies/.usenet/complete/ | head -20
ls /mnt/truenas/Shows/

# Manually move (least preferred — Sonarr won't track it)
mv "/mnt/truenas/Movies/.usenet/complete/Show.S01E01.mkv" "/mnt/truenas/Shows/Show Name/Season 01/"
```

---

## 7. NFS Troubleshooting

### Check NFS Mount Status

```bash
# On VM 103
mount | grep truenas
# Expected: 192.168.1.218:/mnt/WD_10TB on /mnt/truenas type nfs4 (rw,...)

# On VM 102
ssh nkhan@192.168.1.133
mount | grep nfs
# Expected: 192.168.1.218:/mnt/WD_10TB on /mnt/media type nfs4 (rw,...)
```

### Remount NFS

```bash
# VM 103
sudo mount -a

# VM 102
sudo mount -a
```

### Check TrueNAS NFS Exports

```bash
# From either VM
showmount -e 192.168.1.218
```

Or via TrueNAS API:
```bash
curl -sk -H "Authorization: Bearer YOUR_API_KEY" \
  "https://192.168.1.218/api/v2.0/sharing/nfs"
```

### Verify Permissions on TrueNAS

All NFS shares should use `mapall_user: tech, mapall_group: tech`. If any show `maproot` instead of `mapall`, update via TrueNAS UI.

### Check fstab Persistence

```bash
# VM 103
grep nfs /etc/fstab
# Should show: 192.168.1.218:/mnt/WD_10TB /mnt/truenas nfs defaults,nofail,hard,intr 0 0

# VM 102
grep nfs /etc/fstab  
# Should show: 192.168.1.218:/mnt/WD_10TB /mnt/media nfs defaults,nofail,hard,intr 0 0
```

If missing, add it:
```bash
# VM 103
echo "192.168.1.218:/mnt/WD_10TB /mnt/truenas nfs defaults,nofail,hard,intr 0 0" | sudo tee -a /etc/fstab

# VM 102
echo "192.168.1.218:/mnt/WD_10TB /mnt/media nfs defaults,nofail,hard,intr 0 0" | sudo tee -a /etc/fstab
```

---

## 8. Jellyfin Scan & Library Issues

Last updated: 2026-07-21

Jellyfin runs on **VM 103 (192.168.1.50)** as a Docker container. Media is
accessed via NFS from TrueNAS at `/mnt/truenas`, mapped to `/data` inside the
container.

### Quick Health Check

```bash
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50

# Is NFS mounted?
mount | grep truenas

# Can Jellyfin container see media?
docker exec jellyfin ls /data/Anime/
docker exec jellyfin ls /data/Shows/
docker exec jellyfin ls /data/Movies/

# Check library scan status (get API key first — see below)
curl -s 'http://192.168.1.50:8096/Library/VirtualFolders' \
  -H 'X-MediaBrowser-Token: <API_KEY>'
```

### Getting an API Key

If no API key exists, generate one via the database:
```bash
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50
KEY=$(uuidgen)
echo "INSERT INTO ApiKeys (Name, AccessToken, DateCreated, DateLastActivity) \
  VALUES ('opencode', '$KEY', datetime('now'), datetime('now'));" | \
  docker exec -i jellyfin sqlite3 /config/data/data/jellyfin.db
echo "API Key: $KEY"
```

### Failure Mode A: Flat Season List — No Series Grouping (Anime/Shows)

**Symptoms:** Anime series shown as individual season entries instead of grouped
under series names. No series-level posters.

**Root cause:** Library was created as `movies` content type. All episode files
are classified as `Movie` in the database instead of `Episode`.

**Fix — via Jellyfin Web UI (recommended):**
1. Open `http://192.168.1.50:8096` → Dashboard → Libraries
2. Delete the broken library (⋮ → Delete). Media files are NOT touched.
3. Click **Add Media Library** → Content type: **Shows** → Name: `<Library>`
4. Folder: `+` → `/data/<Library>` → OK → OK
5. Wait for automatic scan to complete.

**Fix — via API (automated):**
```bash
# Replace LIBRARY and PATH as needed
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50 "curl -s -X DELETE \
  'http://192.168.1.50:8096/Library/VirtualFolders?name=Anime&refreshLibrary=true' \
  -H 'X-MediaBrowser-Token: <API_KEY>'"

# Recreate as shows/tvshows type (use full JSON payload from SERVICES.md)
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50 "curl -s -X POST \
  'http://192.168.1.50:8096/Library/VirtualFolders?name=Anime&collectionType=tvshows&paths=/data/Anime&refreshLibrary=true' \
  -H 'Content-Type: application/json' -H 'X-MediaBrowser-Token: <API_KEY>' \
  -d @/tmp/create_library.json"
```

### Failure Mode B: Library Shows Zero Items After Scan

**Symptoms:** Library exists in Jellyfin but contains no items. Scan completes
but nothing appears.

**Root cause:** Library config has empty `Locations` (the path was lost during
a previous config update). `PathInfos` may exist in XML but the database
doesn't register it.

**Fix:** Delete and recreate the library (same steps as Failure Mode A).

**Diagnostic check:**
```bash
# Shows or Anime with Locations:[] means the path isn't registered
curl -s 'http://192.168.1.50:8096/Library/VirtualFolders' \
  -H 'X-MediaBrowser-Token: <API_KEY>' | grep -A2 '"Name":"Shows"' | grep Locations
# Expected: "Locations":["/data/Shows"]   (NOT empty array)
```

### Failure Mode C: Metadata Not Fetching (No Posters/Descriptions)

**Symptoms:** Files appear but no posters, descriptions, or episode titles.

**Root cause:** `EnableInternetProviders` is `false`. Jellyfin can't reach
TheMovieDB to fetch metadata.

**Fix — via API:**
```bash
curl -s -X POST 'http://192.168.1.50:8096/Library/VirtualFolders/LibraryOptions' \
  -H 'Content-Type: application/json' -H 'X-MediaBrowser-Token: <API_KEY>' \
  -d '{"Id":"<LibraryId>","LibraryOptions":{"EnableInternetProviders":true}}'
```

**WARNING:** Always send the FULL LibraryOptions object, not a partial one.
Sending only `EnableInternetProviders` will reset all other options (PathInfos,
TypeOptions) to defaults. Use the complete JSON template from SERVICES.md.

**Check internet access:**
```bash
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50
docker exec jellyfin curl -s -o /dev/null -w '%{http_code}' https://api.themoviedb.org
# Expected: 301 or 200
```

### Force Full Rescan

```bash
# Find library ItemId first
curl -s 'http://192.168.1.50:8096/Library/VirtualFolders' \
  -H 'X-MediaBrowser-Token: <API_KEY>' | grep -E '"Name"|"ItemId"'

# Trigger full refresh (replace ITEM_ID)
curl -s -X POST \
  "http://192.168.1.50:8096/Items/<ITEM_ID>/Refresh?Recursive=true&MetadataRefreshMode=FullRefresh&ImageRefreshMode=FullRefresh" \
  -H 'X-MediaBrowser-Token: <API_KEY>'
```

### Verify the Fix

After recovery, confirm correct classification:
```bash
ssh -i ~/.ssh/homelab_ubuntu_docker nkhan3@192.168.1.50
docker exec jellyfin sqlite3 /config/data/data/jellyfin.db \
  "SELECT SUBSTR(Type, INSTR(Type, '.')+1) as T, COUNT(*) FROM BaseItems \
   WHERE Path LIKE '/data/Anime/%' AND Type != 'MediaBrowser.Controller.Entities.Folder' \
   GROUP BY Type;"
# Expected: TV.Episode (hundreds), TV.Season (dozens), TV.Series (~11)
# If you see Movies.Movie — library type is wrong, use Failure Mode A fix.
```

---

## 9. Container Stale Mount Recovery

### When This Happens

This is the **most common issue** in the homelab. It occurs when:

1. VM 100 (TrueNAS) is restarted or briefly unavailable
2. VMs 102/103 remain running
3. NFS mount drops silently
4. Docker containers continue running with a stale, empty view of mount points
5. `/mnt/truenas/` or `/mnt/media/` reverts to a local empty directory

### Full Recovery Procedure

```bash
# === VM 103 (ARR stack) ===
ssh nkhan3@192.168.1.50

# Step 1: Remount NFS
sudo mount -a

# Step 2: Verify NFS shows TrueNAS data (not empty)
ls /mnt/truenas/
# Should show: Anime  Movies  Shows  TV

# Step 3: Restart all containers that depend on NFS
sudo docker restart sabnzbd sonarr radarr

# Step 4: Verify containers see NFS (not empty)
sudo docker exec sonarr ls /data/Anime/
sudo docker exec sabnzbd df -h /data/ | grep -c "8.9T"
```

```bash
# === VM 102 (Jellyfin) ===
ssh nkhan@192.168.1.133

# Step 1: Remount NFS
sudo mount -a

# Step 2: Restart Jellyfin
echo 7164085 | sudo -S docker restart jellyfin

# Step 3: Verify
echo 7164085 | sudo -S docker exec jellyfin ls /media/Anime/
```

---

## 10. Key Paths & Credentials Reference

### File System Paths

| Path | Location | Purpose |
|------|----------|---------|
| `/mnt/truenas/` | VM 103 | TrueNAS root mount |
| `/mnt/media/` | VM 102 | TrueNAS root mount (Jellyfin) |
| `/mnt/truenas/Anime/` | TrueNAS | Anime library |
| `/mnt/truenas/Movies/` | TrueNAS | Movies library |
| `/mnt/truenas/Shows/` | TrueNAS | TV Shows library |
| `/mnt/truenas/TV/` | TrueNAS | TV library |
| `/mnt/truenas/Movies/.usenet/incomplete/` | TrueNAS | SABnzbd temp downloads |
| `/mnt/truenas/Movies/.usenet/complete/` | TrueNAS | SABnzbd completed downloads |
| `/opt/arr-stack/` | VM 103 | Docker compose directory |
| `/opt/arr-stack/docker-compose.yml` | VM 103 | Compose file |
| `/opt/arr-stack/config/` | VM 103 | All container persistent data |

### Docker Containers

| Container | Internal Paths | Notes |
|-----------|---------------|-------|
| `sabnzbd` | `/data/Movies/.usenet/incomplete`, `/data/Movies/.usenet/complete` | Download client |
| `sonarr` | `/data/TV`, `/data/Anime`, `/data/Shows` | TV automation |
| `radarr` | `/data/Movies`, `/data/Anime` | Movie automation |
| `prowlarr` | Config only | Indexer manager |
| `jellyseerr` | Config only | Request UI |
| `jellyfin` (VM 102) | `/media/Anime`, `/media/Movies`, `/media/Shows`, `/media/TV` | Media server |

### Service URLs

| Service | Direct (LAN) | Subdomain (HTTPS) |
|---------|-------------|-------------------|
| Traefik | — | `https://traefik.nkhl.co.uk` |
| Jellyseerr | `http://192.168.1.50:5055` | `https://jellyseerr.nkhl.co.uk` |
| Sonarr | `http://192.168.1.50:8989` | `https://sonarr.nkhl.co.uk` |
| Radarr | `http://192.168.1.50:7878` | `https://radarr.nkhl.co.uk` |
| Prowlarr | `http://192.168.1.50:9696` | `https://prowlarr.nkhl.co.uk` |
| SABnzbd | `http://192.168.1.50:8080` | `https://sabnzbd.nkhl.co.uk` |
| Bazarr | `http://192.168.1.50:6767` | `https://bazarr.nkhl.co.uk` |
| Jellyfin | `http://192.168.1.133:8096` | `https://jellyfin.nkhl.co.uk` |
| Portainer | `https://192.168.1.50:9443` | `https://portainer.nkhl.co.uk` |
| OpenBao | `http://192.168.1.50:8200` | `https://openbao.nkhl.co.uk` |
| code-server | `http://192.168.1.50:8443` | `https://code.nkhl.co.uk` |
| TrueNAS | `https://192.168.1.218` | `https://truenas.nkhl.co.uk` |
| Proxmox | `https://192.168.1.200:8006` | `https://proxmox.nkhl.co.uk` |
| Pi-hole | `http://192.168.1.238/admin` | `https://pihole.nkhl.co.uk/admin` |

### NFS Export (TrueNAS)

| Setting | Value |
|---------|-------|
| Path | `/mnt/WD_10TB` |
| Mapall User | `tech` |
| Mapall Group | `tech` |
| Networks | `192.168.1.0/24` |

---

## 11. Quality Profile: Episodes Rejected Despite "Any" Profile

### Problem

Sonarr finds dozens of releases for an episode but rejects all of them. Downloads show "Downloaded" in SABnzbd history but Sonarr never imports them. The SABnzbd error shows:

```
WEBDL-2160p is not wanted in profile
```

**Root cause**: The "Any" quality profile in Sonarr does NOT include 2160p (4K) qualities by default. It only includes up to 1080p. Even the "Ultra-HD" profile may only include a subset of 2160p types (e.g., `HDTV-2160p` but not `WEBDL-2160p` or `WEBRip-2160p`).

### Diagnostic

```bash
# From VM 103, check what qualities the profile allows
curl -s "http://192.168.1.50:8989/api/v3/qualityprofile/1?apikey=YOUR_API_KEY" | grep -o '"name":"[^"]*"' 
```

Check if `WEBDL-2160p`, `WEBRip-2160p`, `Bluray-2160p`, and `HDTV-2160p` are all listed as `allowed: true`.

### Fix

**In Sonarr UI** (simplest):

1. Go to **Settings → Profiles**
2. Click the profile your series uses (e.g., "Any")
3. Scroll to the **Not Allowed** section at the bottom
4. **Check all 2160p qualities**: `HDTV-2160p`, `WEBDL-2160p`, `WEBRip-2160p`, `Bluray-2160p`
5. Click **Save**
6. Go to the series → click the **magnifying glass** (Search All)

**Note**: Some 2160p qualities may be nested under parent groups (e.g., `WEBDL-2160p` is a sub-item of `HDTV-2160p`). You may need to expand the parent to see and enable the sub-items.

### Verify After Fix

In Sonarr → click the series → click on an individual missing episode → click the **Search** icon (person). You should see green accepted entries instead of red rejected ones with "not wanted in profile".

---

## 12. Files Stuck in Complete Folder (Manual Bypass)

### Problem

Episodes download successfully (visible in SABnzbd history). Files exist in `/data/Movies/.usenet/complete/` as valid MKV files. But Sonarr never imports them to the media library — they sit in the complete folder indefinitely with errors like:

```
No files found are eligible for import
Import failed, path does not exist or is not accessible
```

Sonarr's Manual Import, Search All, and Season Search all fail to move the files.

**Root cause**: This happens when Sonarr's internal download tracking gets into a state where it marks the download as "already processed" or "failed" but the files are still in the complete folder. Repeated searches find the SAME release names and the `.1` duplicates start accumulating. Sonarr's import system skips them because they're associated with a previously failed import attempt.

### Pre-Check: Are the Files Actually There?

```bash
# From VM 103
ls /mnt/truenas/Movies/.usenet/complete/ | head -20
find /mnt/truenas/Movies/.usenet/complete/ -name "*.mkv" | head -10
```

If files exist here but not in the media folder (e.g., `/mnt/truenas/Shows/Show Name/Season X/`), proceed.

### Fix: Manual File Copy to Media Folder

Since the files are valid and complete, copy them directly:

```bash
# Example for One Piece S01E02
# Find the folder in complete
ls /mnt/truenas/Movies/.usenet/complete/ | grep "S01E02"

# Copy the MKV to the target folder
cp "/mnt/truenas/Movies/.usenet/complete/Show.Name.S01E02.2160p.GroupName/Show.Name.S01E02.mkv" \
   "/mnt/truenas/Shows/Show Name (2023)/Season 1/"
```

**Bulk copy example** (when you have multiple episodes stuck):

```bash
COMPLETE="/mnt/truenas/Movies/.usenet/complete"
TARGET="/mnt/truenas/Shows/Show Name/Season 1"

# Copy each stuck episode's MKV
cp "$COMPLETE/Show.S01E02."*"/"*.mkv "$TARGET/"
cp "$COMPLETE/Show.S01E05."*"/"*.mkv "$TARGET/"
# ... repeat for each episode
```

### Clean Up Duplicates

After copying, remove the `.1` duplicates that accumulated in the complete folder:

```bash
rm -rf /mnt/truenas/Movies/.usenet/complete/Show.Name.*.1
```

### Force Sonarr to Recognize the New Files

```bash
# Rescan the series disk so Sonarr updates its database
curl -s -X POST \
  "http://192.168.1.50:8989/api/v3/command?apikey=YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"RescanSeries","seriesId":THE_SERIES_ID}'
```

### Final Step: Jellyfin

Restart Jellyfin and scan libraries:

```bash
# On VM 102
echo 7164085 | sudo -S docker restart jellyfin
```

Then go to Jellyfin → Dashboard → Libraries → Scan All Libraries.

### Why This Works When Sonarr's Import Doesn't

Sonarr tracks downloads by GUID. When an import fails, the GUID is marked as "processed." Subsequent attempts to import files with the same GUID are silently skipped. Copying files manually to the media folder bypasses this tracking — then the `RescanSeries` command makes Sonarr discover the files already in place and update its database.

---

## 13. Jellyseerr Not Finding a Show

### Problem

A known show (e.g., ONE PIECE 2023) doesn't appear in Jellyseerr search but IS available on TheMovieDB/TVDB.

**Root cause**: Jellyseerr caches its catalog from Sonarr/Radarr. Newly added shows may not appear instantly. Also, Jellyseerr search sometimes fails on partial or alternate titles.

### Fix

**Option A: Add directly in Sonarr**

1. Go to `http://192.168.1.50:8989` → **Add New**
2. Search for the show (try alternate titles: "ONE PIECE", "One Piece 2023", "Netflix One Piece")
3. Set root folder, quality profile, add the show
4. Jellyseerr will sync within a few hours automatically

**Option B: Force Jellyseerr sync**

1. Jellyseerr → **Settings → Services → Sonarr → Sync Now**

**Option C: Add by TVDB ID**

If Sonarr can't find the show by name:
1. Find the TVDB ID on `thetvdb.com`
2. Sonarr → Add New → type `tvdb:425026` (replace with actual ID)

---

## 14. Ultra-HD Profile Blocking 1080p Releases

### Problem (Affects: Dr. Stone, One Piece, Devil May Cry, most anime)

A show is requested in Jellyseerr, appears in Sonarr, but no downloads ever start. Interactive search (person icon) shows many releases but all are **red/rejected**. The rejection reason is:

```
WEBDL-1080p is not wanted in profile
Bluray-1080p is not wanted in profile
WEBDL-2160p is not wanted in profile
```

**Root cause**: The show's Quality Profile is set to **Ultra-HD** (ID 5). This profile only accepts `HDTV-2160p` — a single quality. Most content (especially Netflix anime, TV shows, and recent movies) releases in 1080p or uses different 2160p formats (WEBDL-2160p, WEBRip-2160p). The Ultra-HD profile rejects everything else.

This is the **#1 recurring issue** in the homelab. It has hit:
- Dr. Stone (Season 4)
- One Piece (2023) — all seasons
- Devil May Cry (2025)
- Mektoub, My Love: Canto Due (2025)
- Any anime or Netflix series added to Sonarr

**Why new shows default to Ultra-HD**: Jellyseerr uses the first/default quality profile when adding shows. If Ultra-HD was the last profile edited or is the default for certain content types, new requests inherit it.

### Diagnostic — 30-Second Check

In **Sonarr** (`http://192.168.1.50:8989`):

1. Click the show that isn't downloading
2. Look at the top bar — it shows **Quality Profile** next to the title
3. If it says **"Ultra-HD"** → this is the problem

Or check via API:
```bash
curl -s "http://192.168.1.50:8989/api/v3/series?apikey=YOUR_KEY" | grep -B5 -A10 "YOUR SHOW NAME"
```

### Fix

**In Sonarr UI** (30 seconds):

1. Click the show → **Edit** (wrench icon, top bar)
2. Change **Quality Profile** from `Ultra-HD` to **`Any`**
3. Click **Save**
4. Click the **magnifying glass** (Search All) at the top of the show page

**After changing**: Wait 2-3 minutes for the search to complete and downloads to begin. Check Sonarr → **Activity** (not just SABnzbd) for queue items.

### Prevention

For future shows, in Jellyseerr settings, set the default quality profile to "Any" or "HD-720p/1080p" instead of "Ultra-HD". This way new requests won't silently fail.

---

## 15. Show Requests But Nothing Appears — Verify It's Actually Downloading

### Problem

You request a show, change quality profile, click Search All — but nothing seems to happen. SABnzbd looks empty. You assume the fix didn't work.

**Common cause**: You checked too quickly. Between clicking "Search All" and SABnzbd showing active downloads, there's a 1-3 minute delay. Also, SABnzbd only shows **actively downloading** items — items queued behind another download won't show until the current one finishes.

### How to Properly Check If It's Working

**Step 1: Check Sonarr Activity (most important)**

Open Sonarr → **Activity** (left sidebar). This shows ALL queued items — not just the one actively downloading. If this shows 8-16 items with status "downloading", your fix worked.

**Step 2: Check SABnzbd after 3 minutes**

Sometimes Sonarr queues episodes in a season pack (one NZB contains all episodes). The pack may take minutes to download. Wait and check SABnzbd again.

**Step 3: Read rejection messages correctly**

In the interactive search (person icon), "Rejected: release already meets cutoff" does NOT mean it failed — it means the episode is **already downloading**. Sonarr shows this when you try to search for an episode that's currently in the queue.

**Step 4: Check the right queue**

| Where | What It Shows |
|-------|--------------|
| Sonarr → Activity | ALL queued items (even those waiting) |
| SABnzbd queue | Only the ACTIVE download + next in line |
| Sonarr → show → Interactive Search | Available releases + what was grabbed |

### The "It Didn't Work" Checklist

Before assuming the fix failed, verify:

| Check | Expected |
|-------|----------|
| Sonarr → Activity has items | Fix worked, downloads are queued |
| SABnzbd has active downloads | Downloading now |
| Quality profile shows "Any" | Profile was changed correctly |
| Episodes are monitored (filled bookmark icon) | Sonarr will search for them |
| SABnzbd disk shows ~8.5 TB | NFS mount is active (not stale) |

### Real Example: Devil May Cry

User changed quality profile to Any, clicked Search All, checked SABnzbd immediately — saw nothing. Assumed it didn't work.

**Reality**: Sonarr Activity had 16 episodes queued. SABnzbd was downloading a different movie (Shadow's Edge at 76%). Once that finished, Devil May Cry Season 1 pack started at 113 MB/s. The search worked immediately — just needed 3 minutes of patience.

---

## 16. Traefik & Reverse Proxy Issues

### 16.1 Subdomain Not Resolving (NXDOMAIN)

**Problem:** `https://traefik.nkhl.co.uk` or any subdomain returns `DNS_PROBE_FINISHED_NXDOMAIN`.

**Fix:**
1. Check your DNS server: `nslookup traefik.nkhl.co.uk`
2. If using IPv6 DNS, Windows may prefer it over IPv4. Check:
   ```powershell
   Get-DnsClientServerAddress -AddressFamily IPv6
   ```
3. Fix: Set DNS to public resolvers:
   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet 3" -ServerAddresses "1.1.1.1", "8.8.8.8"
   ipconfig /flushdns
   ```
4. Verify Cloudflare records exist: `nslookup traefik.nkhl.co.uk 1.1.1.1`
5. If records are missing, check Cloudflare dashboard or API.

### 16.2 502 Bad Gateway

**Problem:** Traefik returns 502 for a service.

**Fix:**
1. Check if the backend service is running: `docker ps | grep <service>`
2. Check Traefik logs: `docker logs traefik --tail 50`
3. Verify the service URL in `/opt/traefik/config.yml` matches the backend port
4. For external hosts (Jellyfin, TrueNAS, Proxmox, Pi-hole), verify connectivity:
   ```bash
   curl -sk https://192.168.1.218:443   # TrueNAS
   curl -s http://192.168.1.133:8096    # Jellyfin
   ```

### 16.3 SSL Certificate Issues

**Problem:** Browser shows certificate error (not Let's Encrypt).

**Fix:**
1. Check cert status: `docker logs traefik | grep -i acme`
2. Cert file: `/opt/traefik/letsencrypt/acme.json`
3. Verify Cloudflare API token is valid:
   ```bash
   cat /opt/traefik/.env   # Should contain CF_DNS_API_TOKEN
   ```
4. Certificates auto-renew every 60 days — no manual intervention needed.
5. If certs won't issue: ensure DNS-01 challenge can reach Cloudflare (internet required).

### 16.4 Traefik Container Not Starting

**Fix:**
```bash
cd /opt/traefik
docker compose down
docker compose up -d
docker logs traefik --tail 50
```

### 16.5 Traefik Dashboard 401 Unauthorized

**Problem:** Dashboard prompts for credentials.

**Fix:** Username: `admin`, Password: stored in OpenBao at `/kv/traefik`.
To reset password:
```bash
cd /opt/traefik
htpasswd -nbB admin 'new-password' > htpasswd
docker compose up -d
```

### 16.6 Verify All Services

Quick health check from the ubuntu-docker VM:
```bash
for svc in traefik portainer openbao code sabnzbd prowlarr sonarr radarr jellyseerr bazarr jellyfin truenas proxmox pihole; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" https://${svc}.nkhl.co.uk 2>/dev/null)
  echo "${svc}: ${code}"
done
```

Expect: `traefik: 401`, all others should return 2xx/3xx (not 000 or 502).

---

*This file covers issues discovered during the ARR stack deployment in June 2026. Update when new issues are found and resolved.*
