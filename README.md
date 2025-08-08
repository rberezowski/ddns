## 📘 Cloudflare DDNS Auto-Updater – Deployment Guide

Automatically updates A records in Cloudflare based on your dynamic public IP address. Supports multiple subdomains, Discord alerts, logging, and cron-safe operation.

## ✨ Features

- Supports **multiple subdomains** across **multiple domains**
- Auto-creates `.env.ddns` config on first run
- Detects **public IP** automatically
- Updates record **only if IP or proxied has changed**
- Sends **Discord webhook alerts**
- Full **logging** to custom log path
- Designed to be **cron-safe**
- Uses `{COLOR}` tags for **color-coded verbose output**
- Secure `.env` permissions
- Optional **per-subdomain TTL** and proxied control
- Intelligent fallback to default TTL and proxied values
- Modular design with clearly labeled sections

---

### 🛠 Requirements
| Tool  | Purpose              |
|-------|----------------------|
| curl  | API requests         |
| jq    | JSON parsing         |

### ❗ Automatic Install Prompt

If `curl` or `jq` are not found, the script will prompt you to install them using `apt`, `dnf`, `yum`, or `pacman`. If installation fails, the script exits.

---

### 📁 1. File Placement

Place the following files securely on your system:

| File        | Recommended Path         | Description                              |
|-------------|--------------------------|------------------------------------------|
| `ddns.sh`   | `/opt/ddns/ddns.sh`      | Main DDNS script                         |
| `.env.ddns` | `/root/.env.ddns`        | Secure environment config (API keys etc) |

---

### 🔐 2. Set Secure Permissions

Run the following as root:

```bash
chmod 700 /opt/ddns/ddns.sh
chmod 600 /root/.env.ddns
chown root:root /root/.env.ddns
```

---

### 🧪 3. Manual Test (With Verbose Output)

```bash
/opt/ddns/ddns.sh --run --verbose
```

---

### ⏱ 4. Add Cron Job

```cron
*/15 * * * * /opt/ddns/ddns.sh --run >> /var/log/ddns/cron.log 2>&1
```

---

### ⚙️ 5. Optional: First-Time Run

If `/root/.env.ddns` does not exist on the first run:

- Auto-generates a secure `.env.ddns` file
- Adds placeholders for token, webhook, subdomain entries
- Sets `chmod 600` and `chown root:root`

---

### 🔁 6. Update Behavior

The script updates DNS when:

- Public IP changes
- Proxied value changes
- Record does not yet exist

---

### 🧪 Example `.env.ddns`

```ini
CF_API_TOKEN=your_token_here
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
DEFAULT_TTL=120
DEFAULT_PROXIED=true
SUBDOMAIN_COUNT=2

SUBDOMAIN_1=test.mydomain.com
SUBDOMAIN_1_TTL=300
SUBDOMAIN_1_PROXIED=true

SUBDOMAIN_2=home.mydomain.net
```
