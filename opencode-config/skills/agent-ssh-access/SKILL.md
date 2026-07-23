---
name: agent-ssh-access
description: Use this skill when the user wants to connect to, manage, inspect, or run commands on a remote Raspberry Pi or Linux server via SSH. Triggers on phrases like "check the pi", "ssh into the server", "check docker on the pi", "restart a service on the remote host", or any request to work with a remote host defined in the agent-ssh-access project.
argument-hint: [host]
compatibility: [claude-code, opencode]
allowed-tools: [Read, Write, Bash, Glob, Grep, Edit]
---

# agent-ssh-access Skill

Safe, auditable SSH access to remote Linux hosts with mandatory plan/go approval before every action.

## Startup sequence (run every time)

### 1. Find the project

Search in order — use the first match found:

1a. From cwd upward:
```bash
find . -maxdepth 4 -type d -name "agent-ssh-access" 2>/dev/null | head -1
```

1b. Global config fallback:
```bash
ls ~/.config/agent-ssh-access/hosts/ 2>/dev/null
```

If neither found: tell the user and stop.

### 2. Resolve the host

List configured hosts:
```bash
ls $PROJECT/client/hosts/*.md | grep -v HOST_TEMPLATE
```

Read the host file and extract: Hostname, Port, User, Key, SAFE_PATHS, Notes.

### 3. Status check (no go needed)

```bash
# SSH reachability (10s timeout)
ssh -i <Key> -p <Port> -o BatchMode=yes -o ConnectTimeout=10 <User>@<Hostname> 'echo ok'

# Mount check
ls $PROJECT/client/mounts/<Hostname>/ 2>/dev/null | head -3
```

Output format:
```
Host:       <hostname> (port <port>)
User:       <user>  |  Key: <key>
SSH:        ✓ reachable  /  ✗ unreachable
Mount:      ✓ active  /  ✗ not mounted
SAFE_PATHS: <list>
Notes:      <from host file>
```

## Plan / go protocol (mandatory for every action)

Before executing anything:
1. Print a numbered plan (1-3 steps) under **Plan:**
2. For privileged steps (sudo, service restarts, etc.): log to session.log before requesting go
3. Wait for the exact word **go** on its own line
4. After go: log confirmed, execute without asking again
5. If the plan changes, print a new Plan and request a new go

Never execute without an explicit go.

## Available actions

### Mount SSHFS
```bash
$PROJECT/client/mount_sshfs.sh --host <Hostname> --port <Port>
```

### Unmount
```bash
$PROJECT/client/unmount.sh --host <Hostname>
```

### Run SSH command (non-privileged)
```bash
ssh -i <Key> -p <Port> -o BatchMode=yes <User>@<Hostname> '<command>'
```

### Run SSH command (privileged / sudo)
```bash
ssh -i <Key> -p <Port> -o BatchMode=yes <User>@<Hostname> 'sudo <command>'
```

### Deactivate access
```bash
$PROJECT/client/deactivate_access.sh --host <Hostname> --remote-user <AdminUser> [--port <Port>]
```

### Activate access
```bash
$PROJECT/client/activate_access.sh --host <Hostname> --remote-user <AdminUser> [--port <Port>]
```

### Revoke access (permanent)
```bash
$PROJECT/client/revoke_access.sh --host <Hostname> --port <Port> --remote-user <AdminUser> [--force-remove-all]
```

### Test login
```bash
$PROJECT/client/test_login.sh --host <Hostname> --port <Port> --key <Key>
```

## SAFE_PATHS enforcement

Only read or reference files on the remote host that fall under SAFE_PATHS in the host file.

## Forbidden actions

- Never store or request private keys, passwords, or secrets
- Never read paths outside SAFE_PATHS on the remote host
- Never execute remote commands without an explicit go
- Never write or modify files in the project directory without user approval

## Host configuration format

Each host file in `client/hosts/` uses this format:
```
Hostname: 192.168.1.133
Port: 22
User: nkhan
Key: ~/.ssh/homelab_ubuntu_docker
SAFE_PATHS:
- /home
- /var/log
- /etc
- /opt
Notes:
- Debian 13 VM
- Jellyfin server
- sudo ALL=(ALL) NOPASSWD:ALL
```
