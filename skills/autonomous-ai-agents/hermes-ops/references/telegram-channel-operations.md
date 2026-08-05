# Telegram Bot API — Channel Operations

## Getting Channel Chat ID

The Hermes gateway consumes updates via long polling, so `getUpdates` returns empty for channel posts. Use `getChat` with the channel's @username:

```bash
TOKEN="<from .hermes/.env TELEGRAM_BOT_TOKEN>"

# From @username (most reliable)
curl -s "https://api.telegram.org/bot${TOKEN}/getChat" -d "chat_id=@channel_username"
# → { "ok": true, "result": { "id": -1002658483716, "type": "channel", "title": "Trackers" } }

# Channel IDs are negative: -100XXXXXXXXXX
```

## Sending Messages

```bash
# Text with HTML formatting
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d "chat_id=$CHANNEL_ID" \
  -d "text=<b>Bold</b> and normal" \
  -d "parse_mode=HTML"

# Document/file upload
curl -s "https://api.telegram.org/bot${TOKEN}/sendDocument" \
  -F "chat_id=$CHANNEL_ID" \
  -F "document=@/path/to/file.zip" \
  -F "caption=📦 Backup file"
```

## File Size Limits

- Bot token: max 50MB per file via `sendDocument`
- For larger files, use the Telegram Bot API `uploadFile` approach or split
- Hermes backup zips are typically 12-15MB (well within limit)

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `404 Not Found` | Wrong chat_id or bot not in channel | Verify bot is admin, use @username with getChat |
| `400 Bad Request: wrong chat_id` | Using positive ID for channel | Channel IDs are negative (-100...) |
| `403 Forbidden` | Bot not admin or not in channel | Add bot as admin with "Post Messages" permission |
| `413 File too large` | File > 50MB | Split or compress more aggressively |

## Getting Token from .env

```bash
source <(grep "TELEGRAM_BOT_TOKEN" /data/.hermes/.env | sed 's/^/export /')
# Now $TELEGRAM_BOT_TOKEN is available
```

## Iran-Specific Notes

- `api.telegram.org` is accessible from Iran (not filtered)
- Telegram itself is not filtered in Iran
- Bot API calls from the server work regardless of client location
- The bot can send to channels even if the admin is behind a VPN
