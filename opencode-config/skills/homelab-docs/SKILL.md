---
name: homelab-docs
description: "Keep INFRASTRUCTURE.md, SERVICES.md, and AGENTS.md in sync after any infrastructure or service change. Use whenever VMs, services, IPs, or configs change."
---

# Homelab Documentation Sync Skill

## Core rule (from AGENTS.md)

> Any time infrastructure or services change, update `INFRASTRUCTURE.md` and `SERVICES.md` immediately. Outdated docs are worse than no docs.

## Files to maintain

| File | Purpose | Location |
|---|---|---|
| AGENTS.md | AI agent context & rules | `HomeLab/AGENTS.md` |
| INFRASTRUCTURE.md | Hardware, VMs, network specs | `HomeLab/INFRASTRUCTURE.md` |
| SERVICES.md | Service catalog, ports, users | `HomeLab/SERVICES.md` |

## When to update

After any of these changes:
- VM created, deleted, or resized (vCPU, RAM, disk)
- IP address changes (especially DHCP VMs 100 and 102)
- New service deployed or existing service port changed
- New user account, API token, or credential created
- Network config change (bridge, VLAN, DNS)
- Storage change (new pool, dataset, disk)
- New subdomain added to Traefik reverse proxy
- Boot order or startup delay modified
- Critical warning or dependency discovered

## Update checklist

1. Read the current file(s) that need changes
2. Identify which sections are affected
3. Edit in place using the existing format (tables, sections)
4. Update the `Last Updated` date at the top of each file
5. If a new service: add to both INFRASTRUCTURE.md and SERVICES.md
6. If a new VM: add to INFRASTRUCTURE.md VM table and AGENTS.md quick reference
7. If a credential: update SECRETS.md (gitignored)
8. After editing: verify with `git diff` to confirm changes are correct

## Format conventions

### VM table (INFRASTRUCTURE.md)
```
| VMID | Name | OS | vCPU | RAM | IP | Role |
```

### Service table (SERVICES.md)
```
| Service | Host | Port | Notes |
```

### Quick reference table (AGENTS.md)
```
| Resource | IP | Access |
```

## Rules

1. Never create a new doc without checking if an existing one covers it
2. Match the existing table format exactly (columns, alignment, emoji usage)
3. Update `Last Updated` date on every edit
4. When in doubt about a change, ask the user for the exact values
5. After updating docs, suggest committing with a descriptive message
