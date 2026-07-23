# Twingate Setup Guide

This file helps you regain Twingate admin access and add all homelab Resources.

---

## Step 1: Regain Twingate Admin Access

1. Go to https://auth.twingate.com
2. Click "Forgot Password"
3. Enter the email you used to sign up for Twingate
4. Check your inbox (and spam folder) for the reset link
5. Reset your password and log in
6. You should see the "khanhomelab" network in your dashboard

If you don't remember which email you used:
- The Twingate connector is active, proving the network exists
- Try any emails you commonly use (personal, GitHub-linked, etc.)
- Contact Twingate support at https://www.twingate.com/support

---

## Step 2: Add Resources (Once Logged In)

Navigate to your "khanhomelab" network in the admin console, then go to
**Resources** and add each of these:

### Group A — ubuntu-docker (192.168.1.50)

| Name                  | Address        | Ports |
|-----------------------|----------------|-------|
| code-server           | 192.168.1.50   | 8443  |
| Portainer             | 192.168.1.50   | 9443  |
| Sonarr                | 192.168.1.50   | 8989  |
| Radarr                | 192.168.1.50   | 7878  |
| Prowlarr              | 192.168.1.50   | 9696  |
| Jellyseerr            | 192.168.1.50   | 5055  |
| SABnzbd               | 192.168.1.50   | 8080  |
| OpenBao               | 192.168.1.50   | 8200  |
| SSH (ubuntu-docker)   | 192.168.1.50   | 22    |

### Group B — Other VMs/Devices

| Name                  | Address        | Ports |
|-----------------------|----------------|-------|
| Proxmox VE            | 192.168.1.200  | 8006  |
| Jellyfin              | 192.168.1.133  | 8096  |
| TrueNAS               | 192.168.1.218  | 443   |
| Pi-hole Admin         | 192.168.1.238  | 80    |

---

## Step 3: (Optional) API Token for Automation

For programmatic resource management, create an API token:

1. In the Twingate admin console, go to **Settings > API Tokens**
2. Click "Generate Token"
3. Name it "homelab-automation"
4. Copy the token — you can use it with the GraphQL API at:
   `https://khanhomelab.twingate.com/api/graphql/`
5. Store it in OpenBao at `kv/twingate` and in `.env` as `TWINGATE_API_TOKEN`

---

## Step 4: Install Twingate on Your Phone

1. Install the Twingate app from App Store (iOS) or Play Store (Android)
2. Open the app and sign in with your Twingate account
3. Select the "khanhomelab" network
4. Tap Connect
5. All Resources above are now reachable from your phone

### Access code-server
- Open your phone browser
- Navigate to: http://192.168.1.50:8443
- Password: HomeLab2026!
- You'll see VS Code with a terminal — type `opencode` to start

---

*Created: 2026-06-21*
