---
name: docker-management
description: "Manage Docker containers and services on ubuntu-docker (192.168.1.50). Use when the user asks about Docker containers, restarting services, checking logs, status, or managing the Docker Compose stack."
---

# Docker Management Skill

## Homelab context

- **Host:** ubuntu-docker, VM 103, 192.168.1.50
- **SSH:** `ssh nkhan3@192.168.1.50` (key: `~/.ssh/homelab_ubuntu_docker`)
- **Docker Compose:** Traefik lives at `/opt/traefik/`
- **Docker version:** 29.1.3

## Known services (13 containers)

| Service | Port | Image | Purpose |
|---|---|---|---|
| traefik | 80, 443 | traefik:v3.2 | Reverse proxy |
| portainer | 9443 | portainer/ce | Docker management UI |
| openbao | 8200 | openbao | Secret management |
| code-server | 8443 | linuxserver | VS Code in browser |
| sabnzbd | 8080 | linuxserver | Usenet downloader |
| prowlarr | 9696 | linuxserver | Indexer manager |
| sonarr | 8989 | linuxserver | TV automation |
| radarr | 7878 | linuxserver | Movie automation |
| jellyseerr | 5055 | fallenbagel | Media requests |
| bazarr | 6767 | linuxserver | Subtitle manager |
| twingate | - | twingate/connector:1 | Zero-trust access |
| glances | 61208 | nicolargo | System monitoring |

## Connection pattern

Always connect via SSH to ubuntu-docker before running Docker commands:
```bash
ssh nkhan3@192.168.1.50 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"'
```

## Common operations

### Check all containers
```bash
ssh nkhan3@192.168.1.50 'docker ps -a'
```

### Check specific service logs
```bash
ssh nkhan3@192.168.1.50 'docker logs --tail 50 <container-name>'
```

### Restart a service
```bash
ssh nkhan3@192.168.1.50 'docker restart <container-name>'
```

### Check resource usage
```bash
ssh nkhan3@192.168.1.50 'docker stats --no-stream'
```

### Check Traefik config
```bash
ssh nkhan3@192.168.1.50 'ls /opt/traefik/'
ssh nkhan3@192.168.1.50 'docker logs traefik --tail 30'
```

### Check Portainer status
```bash
ssh nkhan3@192.168.1.50 'docker inspect portainer --format "{{.State.Status}}"'
```

### Full system health
```bash
ssh nkhan3@192.168.1.50 'echo "=== DISK ==="; df -h /; echo "=== MEMORY ==="; free -h; echo "=== CONTAINERS ==="; docker ps --format "table {{.Names}}\t{{.Status}}"; echo "=== DOCKER DISK ==="; docker system df'
```

## Rules

1. Always SSH into 192.168.1.50 first — never assume local Docker access
2. For Traefik config changes, check `/opt/traefik/traefik.yml` and `/opt/traefik/config.yml`
3. Use `docker restart` (not stop + start) for quick service restarts
4. For breaking changes, suggest backing up `/opt/traefik/` before editing
5. Always show container status after any change to confirm it took effect
