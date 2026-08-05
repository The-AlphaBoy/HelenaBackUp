#!/bin/bash
# Hermes Complete Backup Script - GitHub + Telegram Channel
# بکاپ جامع: گیتهاب + کانال تلگرام

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
BACKUP_DIR="/data/workspace/HelenaBackUp"
BACKUP_LOG="$HERMES_HOME/logs/backup.log"
CHANNEL_ID="-1002658483716"
GITHUB_TOKEN="SET_YOUR_TOKEN_HERE"
GITHUB_REPO="https://The-AlphaBoy:${GITHUB_TOKEN}@github.com/The-AlphaBoy/HelenaBackUp.git"

# Load Telegram token
source <(grep "TELEGRAM_BOT_TOKEN" "$HERMES_HOME/.env" 2>/dev/null | sed 's/^/export /')

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_LOG"
}

send_telegram() {
    local text="$1"
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=$CHANNEL_ID" \
        -d "text=$text" \
        -d "parse_mode=HTML" > /dev/null 2>&1
}

send_telegram_file() {
    local file="$1"
    local caption="$2"
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
        -F "chat_id=$CHANNEL_ID" \
        -F "document=@$file" \
        -F "caption=$caption" > /dev/null 2>&1
}

log "🚀 شروع بکاپ..."

# 1. پاکسازی فایل‌های موقت
log "🧹 پاکسازی فایل‌های موقت..."
rm -rf "$HERMES_HOME/cache"/* 2>/dev/null
rm -rf "$HERMES_HOME/sessions"/*.tmp 2>/dev/null
find "$HERMES_HOME" -name "*.log.*" -mtime +1 -delete 2>/dev/null
find "$HERMES_HOME" -name "state-snapshot-*" -mtime +1 -delete 2>/dev/null
rm -f "$HERMES_HOME/state-snapshot-"*.json.gz 2>/dev/null
rm -f "$HERMES_HOME/models_dev_cache.json" 2>/dev/null

# 2. حذف فایل‌های غیرضروری از بکاپ
find "$HERMES_HOME" -name "lock" -delete 2>/dev/null
find "$HERMES_HOME" -name "*.pyc" -delete 2>/dev/null
find "$HERMES_HOME" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
rm -rf "$HERMES_HOME/node_modules" 2>/dev/null
rm -rf "$HERMES_HOME/.git" 2>/dev/null

# 3. ایجاد فایل zip (نیاز به zip نصب باشد: apt-get install -y zip)
ZIP_FILE="/tmp/hermes-backup-$(date +%Y%m%d-%H%M).zip"
cd /tmp
rm -f /tmp/hermes-backup-*.zip 2>/dev/null
cd "$HERMES_HOME"
zip -r "$ZIP_FILE" . -x "*.lock" -x "__pycache__/*" -x "*.pyc" > /dev/null 2>&1

ZIP_SIZE=$(du -h "$ZIP_FILE" | cut -f1)
FILE_COUNT=$(find "$HERMES_HOME" -type f | wc -l)
DISK_USED=$(df -h /data | awk 'NR==2{print $5}')
DISK_AVAIL=$(df -h /data | awk 'NR==2{print $4}')

log "📦 فایل zip: $ZIP_SIZE"

# 4. کلون/آپدیت ریپوزیتوری
if [ -d "$BACKUP_DIR/.git" ]; then
    log "🔄 آپدیت ریپوزیتوری..."
    cd "$BACKUP_DIR"
    git pull origin main > /dev/null 2>&1
else
    log "📥 کلون ریپوزیتوری..."
    rm -rf "$BACKUP_DIR"
    git clone "$GITHUB_REPO" "$BACKUP_DIR" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "❌ خطا در کلون ریپوزیتوری"
        GITHUB_STATUS="❌ ناموفق"
        send_telegram "📦 بکاپ روزانه هلنا
━━━━━━━━━━━━━━━━━━━━━━━━━
📅 تاریخ: $(date '+%Y-%m-%d %H:%M:%S')
📊 اندازه: $ZIP_SIZE
📁 فایل‌ها: $FILE_COUNT
💾 دیسک: $DISK_USED ($DISK_AVAIL خالی)
━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 GitHub: $GITHUB_STATUS
📱 تلگرام: ✅"
        send_telegram_file "$ZIP_FILE" "📦 فایل بکاپ - $(date '+%Y-%m-%d %H:%M:%S')"
        rm -f "$ZIP_FILE"
        exit 1
    fi
    cd "$BACKUP_DIR"
    git config user.email "hermes@backup"
    git config user.name "Hermes Backup"
fi

# 5. استخراج فایل‌ها
unzip -o "$ZIP_FILE" > /dev/null 2>&1

# 6. کامیت و پوش
cd "$BACKUP_DIR"
git add -A > /dev/null 2>&1
CHANGES=$(git diff --stat | tail -1)
git commit -m "backup: $(date '+%Y-%m-%d %H:%M:%S')" > /dev/null 2>&1
git push origin main > /dev/null 2>&1

if [ $? -eq 0 ]; then
    log "✅ بکاپ GitHub موفق!"
    GITHUB_STATUS="✅ موفق"
else
    log "❌ بکاپ GitHub ناموفق!"
    GITHUB_STATUS="❌ ناموفق"
fi

# 7. ارسال به کانال تلگرام
log "📤 ارسال بکاپ به کانال تلگرام..."
BACKUP_DATE=$(date '+%Y-%m-%d %H:%M:%S')
BACKUP_MSG="📦 بکاپ روزانه هلنا
━━━━━━━━━━━━━━━━━━━━━━━━━
📅 تاریخ: $BACKUP_DATE
📊 اندازه: $ZIP_SIZE
📁 فایل‌ها: $FILE_COUNT
💾 دیسک: $DISK_USED ($DISK_AVAIL خالی)
━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 GitHub: $GITHUB_STATUS
📱 تلگرام: ✅"

send_telegram "$BACKUP_MSG"

if [ -f "$ZIP_FILE" ]; then
    send_telegram_file "$ZIP_FILE" "📦 فایل بکاپ - $BACKUP_DATE"
    log "✅ فایل بکاپ به کانال ارسال شد"
fi

# 8. پاکسازی
rm -f "$ZIP_FILE"
rm -rf "$BACKUP_DIR/.git" 2>/dev/null

# 9. بررسی وضعیت دیسک
DISK_PERCENT=$(df /data | awk 'NR==2{print $5}' | tr -d '%')
if [ "$DISK_PERCENT" -gt 85 ]; then
    send_telegram "⚠️ هشدار: فضای دیسک پر است! ($DISK_PERCENT% مصرف شده)"
fi

log "✅ بکاپ کامل شد! (GitHub: $GITHUB_STATUS | تلگرام: ✅)"
