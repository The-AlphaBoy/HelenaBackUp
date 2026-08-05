Scripts: hermes-backup.sh, hermes-disk-manager.sh, hermes-disk-monitor.sh, daily-cleanup.sh. Telegram only.
§
Disk cleanup: .cache/huggingface (142MB) and .cache/pip (120MB) safe to remove. User prefers friendly tone — never use formal address.
§
Railway .env overwritten on restart — use Dashboard Variables. NVIDIA_API_KEY, HERMES_LOCAL_STT_COMMAND, HERMES_LOCAL_STT_LANGUAGE must be in Dashboard.
§
UPDATED: Backup channel is now @backupingm (was @trackersme). Chat ID: -1002658483716. Bot: @Minehelenabot has admin access with Post Messages permission.

hermes-ops skill needs curator adoption — created railway-deployment skill to cover Railway-specific patterns. hermes-ops has outdated channel reference (@trackersme) and missing sections on STT, cron optimization, and package persistence.
§
STT: Google Speech Recognition (free, fa-IR). Script: google_stt.py. ffmpeg at /opt/venv/bin/ffmpeg. echo_transcripts: false. API-based only (no local models >100MB).
§
Backup strategy: 1) Memory-only to GitHub on important changes. 2) Full backup every 3h to GitHub+Telegram. Memory is CRITICAL.
§
AmirReza wants Helena as 'مغز دوم' (second brain). Track ALL personal life — preferences, habits, dates, people, goals, stories. Proactively remember and recall. Core mission: life companion.