#!/bin/bash
# 📦 Hermes Complete Backup — zip + گیتهاب + کانال تلگرام

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
BACKUP_DIR="/data/workspace/backups"
REPO_DIR="/data/workspace/HelenaBackUp"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/hermes-backup-${TIMESTAMP}.zip"

mkdir -p "$BACKUP_DIR"

cd /data

# ── 1. ساخت zip کامل ──
python3 -c "
import zipfile, os

hermes = '.hermes'
skip_dirs = {'cache', 'bin', 'image_cache', 'audio_cache', 'pending_messages', 'pairing', 'platforms', 'sandboxes'}
skip_files = {'gateway.pid', 'gateway.lock', 'auth.lock'}
max_log_size = 1024 * 100

with zipfile.ZipFile('${BACKUP_FILE}', 'w', zipfile.ZIP_DEFLATED) as zf:
    count = 0
    for root, dirs, files in os.walk(hermes):
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        for f in files:
            if f in skip_files:
                continue
            filepath = os.path.join(root, f)
            relpath = os.path.relpath(filepath, '.')
            if 'logs/' in relpath and f.endswith('.log'):
                if os.path.getsize(filepath) > max_log_size:
                    continue
            zf.write(filepath, relpath)
            count += 1
    print(f'✅ {count} فایل در بکاپ ذخیره شد')
"

if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
  SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "📦 بکاپ zip: $(basename $BACKUP_FILE) ($SIZE)"
  
  # فقط 3 بکاپ آخر نگه‌دار
  ls -t "$BACKUP_DIR"/hermes-backup-*.zip 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null
else
  echo "❌ خطا در بکاپ!"
  rm -f "$BACKUP_FILE"
  exit 1
fi

# ── 2. پوش به گیتهاب ──
if [ -d "$REPO_DIR/.git" ]; then
  cd "$REPO_DIR"
  
  # کپی فایل‌های مهم
  cp /data/.hermes/config.yaml .
  cp /data/.hermes/.env .
  cp /data/.hermes/SOUL.md .
  cp /data/.hermes/state.db .
  cp -r /data/.hermes/memories/ .
  cp -r /data/.hermes/scripts/ .
  cp /data/.hermes/cron/jobs.json cron/ 2>/dev/null
  
  git add -A
  if git diff --cached --quiet; then
    echo "📝 تغییری نیست — گیتهاب آپدیت نشد"
  else
    git commit -m "📦 بکاپ خودکار — $(date '+%Y-%m-%d %H:%M')" 2>&1 | tail -1
    git push origin main 2>&1 | tail -1
    echo "✅ گیتهاب آپدیت شد"
  fi
fi

# ── 3. ارسال به کانال تلگرام ──
BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN /data/.hermes/.env | cut -d= -f2 2>/dev/null)
if [ -n "$BOT_TOKEN" ]; then
  curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F "chat_id=-1002658483716" \
    -F "document=@${BACKUP_FILE}" \
    -F "caption=📦 بکاپ خودکار — $(date '+%Y-%m-%d %H:%M') | $SIZE" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('✅ کانال آپدیت شد' if d.get('ok') else '')" 2>/dev/null
fi

# ── 4. cleanup ──
echo ""
bash "$HERMES_HOME/scripts/daily-cleanup.sh" 2>/dev/null

echo ""
echo "🎉 بکاپ کامل انجام شد!"
