# Hermes Backup Manifest

- **Timestamp:** 2026-07-29_21:37
- **Hostname:** 3167b3f79305
- **Backup Size:** 9.0M

## Included
- SOUL.md, config.yaml, .env
- channel_directory.json, gateway_state.json
- state.db, kanban.db
- memories/
- skills/ (all skill definitions)
- cron/ (job configs + executions)
- hooks/, platforms/, pairing/
- sessions/ (conversation history)
- auth.json (tokens)
- logs/ (last 50 lines each)
- provider_models_cache.json

## Excluded (regenerable)
- cache/, audio_cache/, image_cache/
- bin/, logs/ (full), state/
- *.lock, gateway.pid/logs
