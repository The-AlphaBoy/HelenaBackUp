---
name: hermes-ops
description: "Backup, restore, and optimize Hermes deployments."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, backup, restore, ops, disk, monitoring, railway, deployment]
---

# Hermes Deployment Operations

Operational procedures for managing Hermes Agent deployments — backup, restore, disk space management, health monitoring, and configuration optimization. Covers constrained environments (Railway, Docker, VPS) where disk space is finite and automatic recovery matters.

## When to Load

- Backing up or restoring a Hermes instance
- Diagnosing or preventing "No space left on device" crashes
- Setting up automated backup/monitoring cron jobs
- Optimizing Hermes configuration for speed or resource usage
- User says "وقتشه برگردی" (it's time to come back) or asks to restore from backup
- Any Railway/Docker deployment health concern

## User Preferences (this user)

⚠️ **Detailed Persian logs required.** This user wants every action logged in Farsi with full detail — filenames, sizes, timestamps, what changed and why. Never skip log output. Format: numbered steps, emoji status indicators, before/after comparisons.

⚠️ **Telegram-only interface.** This user explicitly rejected the web dashboard ("کلا صفحه وب رو بیخیال شو" — forget the web page entirely). Do NOT suggest setting up the web dashboard. All interaction happens through Telegram. Backups go to both GitHub AND a Telegram channel (@trackersme). If asked about a web UI, redirect to Telegram capabilities instead.

## Backup & Restore

### Creating a Backup

```bash
# Built-in backup (creates zip)
hermes backup -o /tmp/hermes-backup.zip

# Check result
ls -lh /tmp/hermes-backup.zip
```

### Restoring from GitHub Backup

```bash
# Clone backup repo
git clone "https://<token>@github.com/<user>/<repo>.git" /data/workspace/BackupRepo

# Inspect what's in the backup
python3 -c "
import sqlite3
conn = sqlite3.connect('/data/workspace/BackupRepo/state.db')
for t in conn.execute(\"SELECT name FROM sqlite_master WHERE type='table'\").fetchall():
    count = conn.execute(f'SELECT count(*) FROM [{t[0]}]').fetchone()[0]
    print(f'{t[0]}: {count} rows')
"
```

### Key Files in a Hermes Backup

| File | Purpose | Can regenerate? |
|------|---------|-----------------|
| `state.db` | Session history, messages | No |
| `config.yaml` | Settings | Partially |
| `.env` | API keys, secrets | No |
| `auth.json` | OAuth tokens, credential pools | No |
| `skills/` | Installed skills | Yes (bundled), No (custom) |
| `memories/` | User profile, agent notes | No |
| `cron/` | Scheduled job definitions | No |
| `sessions/` | Gateway routing index | Yes |
| `kanban.db` | Work queue state | Yes |

### What to EXCLUDE from Backups

- `cache/`, `audio_cache/`, `image_cache/` — regenerable
- `models_dev_cache.json`, `ollama_cloud_models_cache.json` — regenerable
- `*.lock` files — transient
- `state-snapshots/` — keep max 2-3, delete older
- Large log files — keep last 50 lines only

## Disk Space Management

### The Problem (Railway)

Railway volumes are small (typically 434MB–1GB). Hermes + logs + caches + state snapshots can fill them fast. When disk hits 100%, the logging handler crashes with `OSError: [Errno 28] No space left on device`, which cascades into gateway restart loops.

### Disk Manager Script

See `scripts/disk-manager.sh` — run periodically to:
1. Trim log files to last 100 lines when > 100KB
2. Delete old state-snapshots (keep max 3)
3. Clear caches older than 24h
4. Delete regenerable cache files (models_dev_cache.json)
5. Report total Hermes size and disk usage

### Disk Monitor Script

See `scripts/disk-monitor.sh` — checks disk usage against thresholds:
- **Normal:** < 70%
- **Warning:** 70–85%
- **Critical:** 85–95%
- **Emergency:** > 95% → auto-run disk manager

### Recommended Cron Schedule

| Job | Frequency | Purpose |
|-----|-----------|---------|
| Backup | Every 3 hours | Push state to GitHub |
| Disk Monitor | Every 30 minutes | Check space, alert if low |
| Disk Manager | On demand (from monitor) | Clean up when critical |

## Configuration Optimization

### Speed Optimizations

```yaml
# Faster compression (default threshold 0.50, some installs use 0.85)
compression:
  enabled: true
  threshold: 0.50    # Compress when context is 50% full (not 85%)
  target_ratio: 0.15  # Compress down to 15%

# Reduce output overhead
display:
  show_reasoning: false  # Don't stream reasoning tokens
  compact: true          # Compact output format

# Limit snapshots to save disk
checkpoints:
  max_snapshots: 3       # Default is 50 — way too many for small volumes
```

### Apply with CLI

```bash
hermes config set compression.threshold 0.50
hermes config set compression.target_ratio 0.15
hermes config set display.show_reasoning false
hermes config set display.compact true
hermes config set checkpoints.max_snapshots 3
```

## Automated Backup (GitHub + Telegram Channel)

### Script Pattern

See `scripts/backup-to-github.sh` — the full automated backup flow:

1. Clean temporary files (caches, old snapshots, lock files)
2. Create zip with `zip -r` (NOT `hermes backup`)
3. Clone/pull the GitHub backup repo
4. Extract zip into repo, commit, push
5. Send summary message to Telegram channel
6. Send zip file to Telegram channel via `sendDocument`
7. Clean up temp files
8. Alert if disk usage > 85%

**Important:** The script must install `zip` if missing: `apt-get install -y zip`

### Cron Job Setup

```
cronjob create:
  name: "Hermes Auto-Backup"
  schedule: "every 3h"
  prompt: "Run bash /data/workspace/hermes-backup.sh and report result"
  enabled_toolsets: ["terminal"]
```

## Telegram Channel Backup

In addition to GitHub, backups can be sent to a Telegram channel as zip files. This provides a second off-site copy and lets the user download backups directly from Telegram.

### Getting the Channel Chat ID

Bots cannot create channels — the user creates one and adds the bot as admin. Then retrieve the chat_id:

```bash
# From @username
curl -s "https://api.telegram.org/bot${TOKEN}/getChat" -d "chat_id=@channel_username"
# Returns: { "ok": true, "result": { "id": -100XXXXXXXXXX, "type": "channel", ... } }

# Channel IDs are negative, typically -100XXXXXXXXXX format
```

**Pitfall:** `getUpdates` will NOT show channel posts if the Hermes gateway is consuming updates via long polling. Use `getChat` with the @username instead.

### Sending Files to a Channel

```bash
# Send text message
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=$CHANNEL_ID" \
  -d "text=$MESSAGE" \
  -d "parse_mode=HTML"

# Send document (zip file)
curl -s "https://api.telegram.org/bot${TOKEN}/sendDocument" \
  -F "chat_id=$CHANNEL_ID" \
  -F "document=@/path/to/file.zip" \
  -F "caption=📦 Backup - $(date)"
```

### Backup Report Format (Telegram)

Send a summary message before the file:

```
📦 بکاپ روزانه هلنا
━━━━━━━━━━━━━━━━━━
📅 تاریخ: YYYY-MM-DD HH:MM:SS
📊 اندازه: 13M
📁 فایل‌ها: 594
💾 دیسک: 9% (387M خالی)
━━━━━━━━━━━━━━━━━━
🔗 GitHub: ✅
📱 تلگرام: ✅
```

Then send the zip file as a document with caption.

## Pitfalls

0. **Cron jobs MUST have a model configured.** When creating cron jobs with `cronjob action=create`, always set `model={"model": "Alpha-001", "provider": "openai-api"}` (or the user's current model). Without it, the job fails with: `Cron job 'X' has no model configured (job.model=None, HERMES_MODEL='', config.yaml model.default missing or empty)`. Use `cronjob action=update` to fix existing jobs. This is the #1 cause of recurring cron error notifications.
1. **`hermes backup -q` creates state snapshots, NOT zip files.** Use without `-q` for portable zip backups.
2. **`unzip` may not be installed** in minimal containers. Install with `apt-get install -y unzip`.
3. **`zip` may not be installed** either. Install both: `apt-get install -y zip unzip`. The `zip` command is needed to CREATE backups; `unzip` is needed to extract them. Railway base images often have `unzip` but not `zip`.
4. **Git needs user.email/user.name** configured. Set with `git config --global user.email "hermes@backup"`.
5. **GitHub PAT in clone URL** — the token appears in the command. The security scanner will flag it. This is expected for backup scripts.
6. **Working directory matters** — if the cwd was inside a deleted directory, subsequent commands fail with `pwd: error retrieving current directory`. Always `cd` to a stable path first.
7. **Backup repos accumulate state snapshots** from `hermes backup -q` runs during testing. Clean them before the real backup commit.

## Backup on Important Changes (User Preference)

The user explicitly requested: **whenever I make important changes, automatically take a backup and notify them.** This is NOT just the scheduled cron job — it's an additional trigger.

### What Counts as "Important"

- Configuration changes (`hermes config set ...`)
- New scripts or skills created/modified
- Cron job creation, modification, or deletion
- Package installation or system-level changes
- Any optimization or system restructuring
- Security-relevant changes

### How to Execute

After completing the important work and reporting to the user, append:

```
📝 در حال گرفتن بکاپ از تغییرات مهم...
```

Then run `bash /data/workspace/hermes-backup.sh`, and report the result with file count, size, and timestamp.

> 📋 See `references/telegram-channel-operations.md` for Telegram Bot API channel operations (sending files, getting chat IDs, error codes).
> 📋 See `references/cron-job-pitfalls.md` for cron job model configuration and common error patterns.

### Why This Exists

The user's previous Hermes instance crashed due to Railway disk exhaustion. They want confidence that no important work is ever lost. The 3-hour cron job covers periodic snapshots; this pattern covers the moments that matter most.

## Web Dashboard Setup

### The Problem

`hermes dashboard --host 0.0.0.0` refuses to bind without an auth provider on non-loopback binds. This is a security hardening from June 2026 — there is NO unauthenticated public-bind option.

### Solution: Basic Auth

```bash
# 1. Install pyyaml if needed
pip install pyyaml

# 2. Generate password hash
export PYTHONPATH="/opt/hermes-agent:$PYTHONPATH"
HASH=$(python3 -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('YOUR_PASSWORD'))")

# 3. Add dashboard config to ~/.hermes/config.yaml
# dashboard:
#   basic_auth:
#     username: YOUR_USERNAME
#     password_hash: YOUR_HASH_HERE

# 4. Start dashboard
hermes dashboard --host 0.0.0.0 --port 9119 --no-open
```

### Railway-Specific Notes

- Railway does NOT auto-expose ports. You must go to **Settings → Networking** and generate a domain or set a custom port.
- The public URL format: `https://<project-name>-<id>.up.railway.app`
- After generating the domain, the dashboard is accessible at that URL (no port in URL needed if Railway routes to 9119).

### Cloudflare Tunnel (for filtered networks)

When Railway's domain is blocked (e.g. in Iran), use `cloudflared` quick tunnels to expose the dashboard:

```bash
# Install cloudflared
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Start tunnel (generates a free *.trycloudflare.com URL)
cloudflared tunnel --url http://localhost:9119

# Output includes a line like:
#   Your quick Tunnel has been created! Visit it at:
#   https://xxxx-xxxx-xxxx.trycloudflare.com
```

The tunnel URL is temporary — it changes on restart. For persistent access, register a Cloudflare account and create a named tunnel.

**Dashboard login URL** is NOT the root — it's at `/login`. Always direct users to `https://<tunnel-url>/login`.

> 📋 See `references/iran-network-restrictions.md` for detailed notes on which services are filtered in Iran and tested workarounds.

### Web Dashboard Language

The web dashboard is a **compiled React SPA** — `display.language` (set to `fa`, `en`, etc.) only affects the **CLI/TUI**, NOT the web dashboard. There is no config key to change the dashboard language. The `dashboard.language` key is not recognized by Hermes and will be silently saved but ignored.

**Workaround for Persian users:** Telegram is the primary interface and is fully controlled by Hermes prompts (always in Persian). The web dashboard is supplementary — use it for visual tasks only.

### Pitfalls

- The `plugins.dashboard_auth.basic` module must be imported from the hermes-agent source tree (`/opt/hermes-agent`), not from pip. Set `PYTHONPATH` accordingly.
- The password hash is scrypt-based and includes `$` characters — use `sed` with care when inserting into YAML.
- **Cloudflare quick tunnels are temporary** — the URL changes when the tunnel process restarts. Do not hardcode tunnel URLs in scripts or documentation.
- **Cloudflare is also filtered in Iran** — the `trycloudflare.com` domain may not load even with VPN. If the user reports the dashboard not loading, this is the likely cause. The tunnel works from the server side (confirmed via curl) but the client cannot reach it. For Iranian users, Telegram-based interaction is the reliable path.
- **`dashboard.language` is not a real config key** — it gets saved to config.yaml but Hermes doesn't read it. Don't promise language changes to the user based on this key.

## Verification

After any backup/restore/optimization:
1. Check disk: `df -h /data`
2. Check Hermes size: `du -sh ~/.hermes/`
3. Verify cron jobs: `cronjob list`
4. Test backup script: run it once manually
5. Check config: `cat ~/.hermes/config.yaml`
