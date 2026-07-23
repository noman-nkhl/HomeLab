---
name: ssh-operations
description: "SSH operations skill for connecting, running commands, file transfer, key setup, hardening, and troubleshooting across Windows, Linux, macOS, and WSL."
---

# SSH Operations Skill

Last audited: 2026-07-09

## Purpose

Use this skill whenever the user asks for SSH-related work, including:
- Connecting to a remote host
- Running commands over SSH
- Setting up SSH keys
- Fixing SSH login failures
- Configuring OpenSSH client or server
- Copying files with scp, sftp, or rsync
- Using jump hosts, bastions, tunnels, SOCKS proxies, or port forwarding
- Troubleshooting SSH on Windows, Linux, macOS, WSL, VPS providers, cloud servers, LAN devices
- Hardening SSH safely without locking the user out

## Non-negotiable rules

1. Never ask the user to paste a private key, password, token, recovery code, or full unredacted debug log.
2. Never print or store secrets.
3. Never use brute force, password spraying, credential guessing, bypass attempts.
4. Never disable password login, root login, or an existing access path until a replacement login has been tested in a separate session.
5. Never auto-accept a changed host key.
6. Never use StrictHostKeyChecking=no or UserKnownHostsFile=/dev/null by default.
7. Prefer public-key authentication with a passphrase-protected private key.
8. Prefer Ed25519 keys for new keys unless the target is legacy.
9. Use least privilege. Do not run as root or Administrator unless required.
10. Back up config files before editing.
11. Validate SSH server config before restarting or reloading.
12. Keep an active fallback SSH session open during server-side SSH changes when possible.

## Identification

Linux/macOS/WSL: `uname -a; command -v ssh; ssh -V`
Windows PowerShell: `$PSVersionTable; Get-Command ssh -ErrorAction SilentlyContinue; ssh -V`

## Default connection commands

Basic: `ssh -p $SSH_PORT -o ConnectTimeout=10 -o ServerAliveInterval=30 "${REMOTE_USER}@${TARGET_HOST}"`
With private key: `ssh -i "$PRIVATE_KEY_PATH" -p "$SSH_PORT" -o IdentitiesOnly=yes "${REMOTE_USER}@${TARGET_HOST}"`
Non-interactive test: `ssh -o BatchMode=yes -o ConnectTimeout=10 "${REMOTE_USER}@${TARGET_HOST}" 'echo SSH_OK'`
Force public-key only: `ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no -i "$PRIVATE_KEY_PATH" -o IdentitiesOnly=yes "${REMOTE_USER}@${TARGET_HOST}"`

## Key generation

Use Ed25519 for new keys:
```bash
mkdir -p ~/.ssh; chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 100 -C "$KEY_COMMENT" -f "$PRIVATE_KEY_PATH"
chmod 600 "$PRIVATE_KEY_PATH"; chmod 644 "${PRIVATE_KEY_PATH}.pub"
```
Windows PowerShell:
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.ssh" | Out-Null
ssh-keygen -t ed25519 -a 100 -C "$env:USERNAME@purpose-$(Get-Date -Format yyyyMMdd)" -f $PrivateKeyPath
```

## Linux authorized_keys setup

```bash
mkdir -p ~/.ssh; chmod 700 ~/.ssh; touch ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys
# From client: ssh-copy-id -i "$PUBLIC_KEY_PATH" "${REMOTE_USER}@${TARGET_HOST}"
# Or: cat <PUBLIC_KEY_PATH> | ssh "${REMOTE_USER}@${TARGET_HOST}" 'cat >> ~/.ssh/authorized_keys'
```

## Jump hosts and bastions

One-time: `ssh -J "${BASTION_USER}@${BASTION_HOST}" "${REMOTE_USER}@${TARGET_HOST}"`
Custom jump port: `ssh -J "${BASTION_USER}@${BASTION_HOST}:${BASTION_PORT}" ...`

## Port forwarding

Local: `ssh -L "${LOCAL_PORT}:${DESTINATION_HOST}:${DESTINATION_PORT}" "${REMOTE_USER}@${TARGET_HOST}"`
Remote: `ssh -R "${REMOTE_PORT}:${LOCAL_SERVICE_HOST}:${LOCAL_SERVICE_PORT}" ...`
Dynamic SOCKS: `ssh -D "${SOCKS_PORT}" -N "${REMOTE_USER}@${TARGET_HOST}"`

## File transfer

SCP: `scp -P "$SSH_PORT" -i "$PRIVATE_KEY_PATH" "<LOCAL_PATH>" "${REMOTE_USER}@${TARGET_HOST}:<REMOTE_DIR>/"`
Rsync: `rsync -azP -e "ssh -p $SSH_PORT -i $PRIVATE_KEY_PATH" "<LOCAL_DIR>/" "${REMOTE_USER}@${TARGET_HOST}:<REMOTE_DIR>/"`

## Troubleshooting quick guide

1. DNS/host: "Could not resolve hostname" - `getent hosts`, `nslookup`
2. Port blocked: "Connection timed out" - `nc -vz $TARGET_HOST $SSH_PORT`, check firewall
3. Service not listening: "Connection refused" - `systemctl status ssh`, `ss -tlnp | grep :$SSH_PORT`
4. Public key rejected: "Permission denied (publickey)" - check permissions (700/600), check authorized_keys
5. Host key changed: "REMOTE HOST IDENTIFICATION HAS CHANGED" - verify through trusted channel, then `ssh-keygen -R "$TARGET_HOST"`
6. Bad permissions: `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; chmod 600 ~/.ssh/config`

## Linux sshd_config workflow

Backup: `sudo cp -a /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)`
Validate: `sudo sshd -t`
Reload: `sudo systemctl reload ssh || sudo systemctl reload sshd`

## Lockout-safe hardening checklist

1. Keep current session open
2. Add new public key
3. Test key login from second terminal
4. Backup config
5. Apply hardening changes
6. `sudo sshd -t` validate
7. Reload sshd
8. Test new login from second session
9. Then close fallback
