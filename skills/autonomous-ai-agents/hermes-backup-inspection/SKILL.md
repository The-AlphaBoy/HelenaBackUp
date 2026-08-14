---
name: hermes-backup-inspection
description: "Review/restore Hermes backup zips: health, staleness."
tags: [hermes, backup, restore, inspection]
triggers:
  - review backup
  - check backup
  - inspect backup
  - restore backup
  - apply backup
  - backup zip
---

# Hermes Backup Inspection & Restore Decision

## When to use
User sends a Hermes backup (zip via Telegram, or a GitHub repo) and asks to check / review / restore it, or asks to verify backup integrity. This user treats backup verification as routine (GitHub/Git/Cron are his safety net) — expect zips labeled like `hermes-backup-<timestamp>.zip` to arrive in chat.

## Key empirical facts (Railway deployment, Aug 2026)
- **The backup is often RICHER than live.** Railway's ~434MB disk cap + history compaction prunes live `state.db`. Observed: live = 26 sessions / 290 messages while the backup zip (35MB state.db) held 60 sessions / 6,880 messages — the full history the server had already dropped. Backup zips are the archive of record for chat history. NEVER assume "restoring loses recent history" — compare counts FIRST, the default direction is often reversed.
- **Backups contain NO `.env` / `auth.json`** — provider keys live only in the container (PID-1 environ / Railway Variables). A backup config advertising `gemini/...` proves nothing about key availability elsewhere.
- **Model divergence is three-way**: backup `config.yaml` model ≠ live `config.yaml` model ≠ per-session models in `state.db` (`sessions.model` column). Report what each source actually says. Live may run a weak fallback (e.g. `nvidia/meta-llama-3.1-8b-instruct`, no fallback chain) while the backup config had `gemini/...` with NVIDIA + Groq fallbacks.

## Inspection workflow (read-only — never overwrite live state)
1. **Extract** — `unzip` is usually absent in minimal containers; use Python:
   `python3 -c "import zipfile; zipfile.ZipFile('backup.zip').extractall('/tmp/hermes-backup')"`
   Backups wrap everything under a `.hermes/` top folder → root is `/tmp/hermes-backup/.hermes/`.
2. **Inventory**: list key files, count `SKILL.md` files, spot custom (non-bundled) skills — they're the user's real value (e.g. skin-care, hermes-ops, railway-deployment).
3. **Row counts via Python sqlite3** (CLI `sqlite3` is often absent too):
   - `state.db`: `SELECT COUNT(*) FROM sessions` / `messages`; coverage window via `MIN/MAX(timestamp)`; per-model breakdown `SELECT model, COUNT(*) FROM sessions GROUP BY model`.
   - `smart_memory.db`: memories count. `kanban.db`: tasks count (empty is normal).
4. **Read** `memories/MEMORY.md` + `USER.md`, `SOUL.md`, `config.yaml` (model + fallbacks + platforms), `channel_directory.json`.
5. **Cron**: `cron/jobs.json` is a **dict** `{"jobs": [...]}` — iterate `d["jobs"]`, never `for j in d`. Report name / schedule / model / deliver per job.
6. **Staleness check vs live**: run the same queries on live `/data/.hermes/state.db` and present side by side. Live BEHIND backup = restore recovers history, not a loss.
7. **Key availability check** before promising any model switch:
   `tr '\0' '\n' < /proc/1/environ | grep -oE '^[A-Z_]+='` (container PID-1 env) vs `grep -oE '^[A-Z_]+=' ~/.hermes/.env` (entrypoint whitelist). Keys present in PID-1 but not `.env` must be passed explicitly per command.
8. **Report** as a compact table (what's inside ✅ / notes ⚠️ / diff vs live) and ask: restore, keep as-is, or nothing.

## Restore decision notes
- If restore is requested, in this order:
  1. **Disk headroom**: `df -h /data` — Railway volume is ~434MB; a 35MB `state.db` copy needs room. Confirm before overwriting.
  2. **Pre-restore snapshot**: `mkdir -p /data/.hermes/pre-restore-backup-$(date +%Y%m%d_%H%M%S)` and copy `state.db kanban.db config.yaml channel_directory.json gateway_state.json memories/MEMORY.md` into it. Cheap insurance; matches the user's backup-first mindset.
  3. **Verify the SOURCE db first**: `PRAGMA integrity_check` on the backup `state.db` via Python sqlite3 BEFORE copying — only restore from a verified-healthy archive.
  4. **Stop the gateway before swapping `state.db`** (or, if you ARE the gateway, restore non-state files first and warn the user a transient storage-write warning is expected). Observed Aug 2026: restore ran from inside the gateway; config/db swapped in-place while running, user warned that a `⚠️ No reply ... session storage` warning on the next turn is expected and harmless.
- `config.yaml`: compare and keep the more complete version (platforms/security) — never blind-overwrite. Observed: live config had been stripped to a 375-byte minimal file (no `platforms:` section, no tts/stt/display) while the backup config carried the full settings incl. `platforms.telegram.home_channel` and matching `_config_version: 33` — restoring the backup config wholesale was correct and re-added the Telegram home channel. Check `_config_version` parity before replacing.
- **Progress reporting**: this user sends 'خب؟' / 'چطور پیش میره؟' during long restores — send a one-line Persian progress summary after each major step (snapshot taken / config restored / db verified / dbs copied). Never run restore steps silently.
- Skills: merge with `cp -rn` (no-clobber) to keep unique skills from both sides.
- After restore: `cronjob action=list` and check models — jobs referencing an old model may need remove + recreate.

## Pitfalls
- `unzip` / `sqlite3` CLIs missing → Python `zipfile` + `sqlite3` module; never block on the CLIs.
- `sessions` table has `started_at`, not `created_at`.
- `cron/jobs.json` is a dict, not a list (see above).
- Backup `config.yaml` may be minimal or outdated — diff against live before restoring.
- A backup with no `.env` cannot "fix" missing keys on a target box — verify live key names first, then answer feasibility.
- `hermes` CLI often at `/opt/venv/bin/hermes`, not on PATH.
