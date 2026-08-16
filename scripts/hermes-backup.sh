#!/bin/bash
# 📦 Hermes Complete Backup — zip + گیت‌هاب + کانال تلگرام (نسخه امن، بدون کلید)
# 🔒 SECURITY: هیچ فایل حساسی (.env, auth.json) در بکاپ یا گیت‌هاب قرار نمی‌گیرد.

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
BACKUP_DIR="/data/workspace/backups"
REPO_DIR="/data/workspace/HelenaBackUp"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/hermes-backup-${TIMESTAMP}.zip"

mkdir -p "$BACKUP_DIR"

cd /data

# ── 1. ساخت zip کامل (بدون فایل‌های حساس) ──
python3 -c "
import zipfile, os

hermes = '.hermes'
skip_dirs = {'cache', 'bin', 'image_cache', 'audio_cache', 'pending_messages', 'pairing', 'platforms', 'sandboxes'}
# 🔒 فایل‌های حساس هرگز وارد بکاپ نشوند
skip_files = {'gateway.pid', 'gateway.lock', 'auth.lock', '.env', 'auth.json', 'auth.json.bak'}
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

# ── 2. پوش به گیت‌هاب (بدون .env — فقط فایل‌های امن) ──
if [ -d "$REPO_DIR/.git" ]; then
  cd "$REPO_DIR"
  # کپی فایل‌های مهم — 🔒 بدون .env و بدون auth.json
  cp /data/.hermes/config.yaml .
  cp /data/.hermes/SOUL.md .
  cp /data/.hermes/state.db .
  cp -r /data/.hermes/memories/ .
  cp -r /data/.hermes/scripts/ .
  cp /data/.hermes/cron/jobs.json cron/ 2>/dev/null

  git add -A
  if git diff --cached --quiet; then
    echo "📝 تغییری نیست — گیت‌هاب آپدیت نشد"
  else
    git commit -m "📦 بکاپ خودکار — $(date '+%Y-%m-%d %H:%M')" 2>&1 | tail -1
    git push origin main 2>&1 | tail -1
    echo "✅ گیت‌هاب آپدیت شد"
  fi
fi

# ── 3. ارسال به کانال تلگرام (تکه‌تکه برای فایل‌های بزرگ) ──
BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN /data/.hermes/.env | cut -d= -f2 2>/dev/null)
CHAT_ID="-1002658483716"
TG_API="https://api.telegram.org/bot${BOT_TOKEN}"

send_tg() { # $1=file  $2=caption → خروجی: ok یا پیام خطا
  curl -s "${TG_API}/sendDocument" \
    -F "chat_id=${CHAT_ID}" \
    -F "document=@$1" \
    -F "caption=$2" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('ok' if d.get('ok') else d.get('description','fail'))" 2>/dev/null
}

if [ -n "$BOT_TOKEN" ]; then
  FILE_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo 0)
  MAX_CHUNK=$((15 * 1024 * 1024))  # 15MB — زیر سقف تلگرام برای فایل‌های doc
  NAME=$(basename "$BACKUP_FILE")
  CAPTION="📦 بکاپ خودکار — $(date '+%Y-%m-%d %H:%M') | $SIZE"

  if [ "$FILE_SIZE" -le "$MAX_CHUNK" ]; then
    result=$(send_tg "$BACKUP_FILE" "$CAPTION")
    if [ "$result" = "ok" ]; then
      echo "✅ کانال آپدیت شد"
    else
      echo "⚠️ ارسال به کانال ناموفق: $result"
    fi
  else
    # فایل بزرگ → تکه‌تکه ۱۵MB با نام استاندارد: name.part001.zip name.part002.zip ...
    CHUNK_DIR="/tmp/hermes-chunks-$$"
    mkdir -p "$CHUNK_DIR"
    # split با پیشوند name.part و پسوند .zip اضافه می‌کنیم بعد
    BASE_NAME="${NAME%.zip}"
    split -b 15M -d -a 3 "$BACKUP_FILE" "$CHUNK_DIR/${BASE_NAME}.part"
    # اضافه کردن .zip به نام هر تکه
    for chunk in "$CHUNK_DIR"/${BASE_NAME}.part*; do
      mv "$chunk" "${chunk}.zip"
    done
    TOTAL=$(ls "$CHUNK_DIR" | wc -l)
    i=0; OK=0
    for chunk in "$CHUNK_DIR"/${BASE_NAME}.part*.zip; do
      i=$((i+1))
      res=$(send_tg "$chunk" "🧩 $CAPTION — بخش $i/$TOTAL | ادغام: cat ${BASE_NAME}.part*.zip > ${NAME}")
      [ "$res" = "ok" ] && OK=$((OK+1))
    done
    rm -rf "$CHUNK_DIR"
    if [ "$OK" -eq "$TOTAL" ]; then
      echo "✅ کانال آپدیت شد (${TOTAL} تکه)"
    else
      echo "⚠️ ${OK}/${TOTAL} تکه ارسال شد"
    fi
  fi
fi

# ── 4. cleanup ──
echo ""
bash "$HERMES_HOME/scripts/daily-cleanup.sh" 2>/dev/null

echo ""
echo "🎉 بکاپ کامل انجام شد!"
