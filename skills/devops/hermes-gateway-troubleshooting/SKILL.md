---
name: hermes-gateway-troubleshooting
description: "Fix Hermes gateway: home channel, FK, disk, SQLite issues."
version: 1.0.0
tags: [hermes, gateway, troubleshooting, telegram, sqlite, debugging]
---
# Hermes Gateway Troubleshooting

Class-level skill for diagnosing and fixing common Hermes messaging gateway issues.

## Common Issues & Fixes

### 1. "No home channel is set for Telegram" Loop

**Symptom:** Repeated notice on every message: "📬 No home channel is set for Telegram. Type /sethome..."

**Root Cause:** `platforms.telegram.enabled` not set in `config.yaml` AND `_enabled_explicit: true` missing. Gateway's `load_gateway_config()` only wires `home_channel` when platform is enabled.

**Fix:**
```bash
hermes config set platforms.telegram.enabled true
hermes config set platforms.telegram.extra._enabled_explicit true
```
Then restart gateway (`hermes gateway restart` or container restart).

### 2. "FOREIGN KEY constraint failed" on Session DB

**Symptom:** `Session DB transcript append failed ... FOREIGN KEY constraint failed` in gateway.log

**Root Cause:** SQLite journal_mode=DELETE (not WAL) + concurrent writes. FK constraints enabled but parent session missing or FK pragma off.

**Fix:**
```bash
# Check FK state
sqlite3 ~/.hermes/state.db "PRAGMA foreign_keys;"
# If ON (1), disable:
sqlite3 ~/.hermes/state.db "PRAGMA foreign_keys=OFF;"
# Verify journal mode (WAL preferred, but 3.46.1 has WAL-reset bug):
sqlite3 ~/.hermes/state.db "PRAGMA journal_mode;"
```
Note: Hermes doctor warns about SQLite 3.46.1 WAL-reset bug — stay on DELETE mode until SQLite upgraded.

### 3. "No space left on device" / Disk Full

**Symptom:** `OSError: [Errno 28] No space left on device` in gateway/session logs

**Fix:** Clean common space hogs:
```bash
# Backups (keep latest 1-2)
rm -rf ~/.hermes/backups/state.db.pre-fix-*
# Cache
rm -rf ~/.hermes/cache/documents/* ~/.hermes/cache/audio/* ~/.hermes/cache/images/* ~/.hermes/cache/videos/*
# Logs
> ~/.hermes/logs/agent.log; > ~/.hermes/logs/gateway.log; > ~/.hermes/logs/errors.log
df -h ~/.hermes  # verify
```

### 4. Provider Key Mismatch / Missing API Keys

**Symptom:** `hermes doctor` reports "No credentials found for provider 'X'" or API calls fail with auth errors. Config references providers whose keys aren't in `~/.hermes/.env`.

**Root Cause:** `model.provider` or `fallback_providers` reference a provider whose API key isn't in `~/.hermes/.env`. Only a whitelist of keys gets copied from container env by the entrypoint script; others stay in PID-1 env only.

**Diagnosis first:**
```bash
# 1. Check what keys actually exist
cat ~/.hermes/.env | grep API_KEY
# 2. Check what provider/fallbacks are configured
hermes config get model.provider
hermes config get fallback_providers
# 3. Cross-reference: if config says nvidia but .env only has OPENAI_API_KEY → mismatch
```

**Fix:**
```bash
# Add missing key(s) to ~/.hermes/.env
echo "GROQ_API_KEY=gsk_..." >> ~/.hermes/.env
# Switch primary provider to one that has a valid key
hermes config set model.provider openai-api
hermes config set model.default "openai-api:<model_name>"
# Set fallback_providers to providers whose keys you actually have
hermes config set fallback_providers '[{"provider": "nvidia", "model": "nvidia/nemotron-3-ultra-550b-a55b"}]'
# Clear broken fallbacks if needed
hermes config set fallback_providers '[]'
```
Then restart gateway externally.

**⚠️ Pitfall:** `hermes providers status` does NOT exist as a CLI command. Use `hermes doctor` to check provider connectivity and key status.

### 5. `hermes` Binary Not in PATH

**Symptom:** `/usr/bin/bash: line 3: hermes: command not found`

**Fix:** Symlink to system PATH:
```bash
ln -sf /opt/venv/bin/hermes /usr/local/bin/hermes
# Verify
which hermes && hermes --version
```

### 6. SQLite WAL-Reset Bug (3.46.1)

**Symptom:** Hermes doctor warns: `⚠ SQLite 3.46.1 (WAL-reset bug)`

**Status:** Fixed in SQLite 3.51.3+ / 3.50.7 / 3.44.6. Requires system package update or `hermes update` for embedded runtime.

**Workaround:** Keep `journal_mode=DELETE` (Hermes does this automatically when it detects vulnerable version).

## Diagnostic Checklist

Run `hermes doctor` first — it catches 80% of issues:
- Config validation
- API keys (⚠ `hermes providers status` does NOT exist — use doctor)
- SQLite version/integrity
- Directory structure
- Provider connectivity

Then verify key ↔ config alignment:
```bash
cat ~/.hermes/.env | grep API_KEY          # what keys exist?
hermes config get model.provider            # what provider is active?
hermes config get fallback_providers        # what fallbacks?
# Cross-reference: keys in .env must match providers in config
```

Then check logs:
```bash
tail -50 ~/.hermes/logs/gateway.log | grep -iE "error|fail|warn|home.channel|foreign"
tail -20 ~/.hermes/logs/errors.log
```

## References

- `references/gateway-config-architecture.md` — How gateway loads config, env overrides, plugin enablement
- `references/sqlite-wal-bug.md` — SQLite 3.46.1 WAL-reset bug details and workarounds
- `references/additional-issues-2026-08-10.md` — Stale-module crash, provider mismatch details, max_tokens cap, Gemini429 fallback