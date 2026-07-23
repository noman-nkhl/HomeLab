---
name: linux-admin
description: "Linux system administration for Debian13 (192.168.1.133) and ubuntu-docker (192.168.1.50). Use for apt updates, disk checks, service management, user admin, and troubleshooting."
---

# Linux System Administration Skill

## Homelab hosts

| Host | IP | OS | User | Purpose |
|---|---|---|---|---|
| Debian13 | 192.168.1.133 | Debian 13 | nkhan | Jellyfin server |
| ubuntu-docker | 192.168.1.50 | Ubuntu 24.04 | nkhan3 | Docker host |

## Critical: Jellyfin → TrueNAS dependency

VM 102 (Debian13, Jellyfin) mounts media from TrueNAS (VM 100, 192.168.1.218).
- **Boot order:** TrueNAS first, then Jellyfin
- **Shutdown order:** Jellyfin first, then TrueNAS
- **Boot startup delays:** TrueNAS up=120s, ubuntu-docker up=30s, Debian13 up=30s
- If TrueNAS is down, Jellyfin's library is empty

## Standard operations

### Check system health
```bash
# Run on either host via SSH
ssh <user>@<host> 'uptime; free -h; df -h; systemctl list-units --state=failed'
```

### Check disk usage
```bash
ssh <user>@<host> 'df -h; du -sh /var/log /var/cache /tmp'
```

### Check Jellyfin media mounts (Debian13 only)
```bash
ssh nkhan@192.168.1.133 'mount | grep -i truenas || echo "WARNING: TrueNAS mounts not found"'
```

### System updates
```bash
# Ubuntu (VM 103)
ssh nkhan3@192.168.1.50 'sudo apt update && sudo apt list --upgradable'

# Debian (VM 102)
ssh nkhan@192.168.1.133 'sudo apt update && sudo apt list --upgradable'
```

### Apply updates safely
```bash
ssh <user>@<host> 'sudo apt update && sudo apt upgrade -y && echo "Updates applied"'
```

### Check running services
```bash
ssh <user>@<host> 'systemctl list-units --type=service --state=running'
```

### Restart a service
```bash
ssh <user>@<host> 'sudo systemctl restart <service>'
ssh <user>@<host> 'sudo systemctl status <service>'
```

### Check journal for errors
```bash
ssh <user>@<host> 'sudo journalctl -p err -n 50 --no-pager'
```

### Check RAM usage (Debian13 is tight at 6GB)
```bash
ssh nkhan@192.168.1.133 'free -h; ps aux --sort=-%mem | head -10'
```

### Check Jellyfin service (Debian13)
```bash
ssh nkhan@192.168.1.133 'sudo systemctl status jellyfin; curl -s -o /dev/null -w "%{http_code}" http://localhost:8096'
```

## Rules

1. Always SSH to the target host — never assume local access
2. Before updating: check disk space, note current versions, back up critical configs
3. Debian13 RAM is only 6GB — monitor for OOM before large operations
4. Never restart/shutdown Debian13 without checking TrueNAS is running first
5. Jellyfin port 8096 on Debian13 — test with curl after any restart
6. For ubuntu-docker: container state is more important than host services
7. Use sudo for privileged operations — both users likely have NOPASSWD sudo
