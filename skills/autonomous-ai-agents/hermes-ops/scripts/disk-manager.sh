#!/bin/bash
# Hermes Disk Manager - بهینه‌سازی خودکار فضای دیسک
# این اسکریپت هر ۳ ساعت اجرا می‌شه و فضای اضافی رو پاک می‌کنه

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
LOG_FILE="$HERMES_HOME/logs/disk-manager.log"
MAX_LOG_SIZE=102400  # 100KB max log size
MAX_SNAPSHOTS=3      # حداکثر ۳ اسنپشات نگه دار
MAX_STATE_DB_SIZE=52428800  # 50MB max state.db

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] $1" >> "$LOG_FILE"
}

log "=== شروع بهینه‌سازی فضای دیسک ==="

# ۱. پاکسازی لاگ‌های قدیمی
log "۱. پاکسازی لاگ‌ها..."
for log_file in "$HERMES_HOME/logs/"*.log; do
    if [ -f "$log_file" ]; then
        size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)
        if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
            tail -100 "$log_file" > "${log_file}.tmp"
            mv "${log_file}.tmp" "$log_file"
            log "   ✅ لاگ $(basename "$log_file") از $((size/1024))KB به ۱۰۰KB کاهش یافت"
        fi
    fi
done

# ۲. پاکسازی state-snapshots قدیمی
log "۲. پاکسازی state-snapshots..."
snapshot_count=$(ls -d "$HERMES_HOME/state-snapshots/"*/ 2>/dev/null | wc -l)
if [ "$snapshot_count" -gt "$MAX_SNAPSHOTS" ]; then
    ls -d "$HERMES_HOME/state-snapshots/"*/ | head -n -"$MAX_SNAPSHOTS" | while read dir; do
        rm -rf "$dir"
        log "   ✅ اسنپشات قدیمی حذف شد: $(basename "$dir")"
    done
fi

# ۳. پاکسازی کش‌ها
log "۳. پاکسازی کش‌ها..."
for cache_dir in "$HERMES_HOME/cache" "$HERMES_HOME/audio_cache" "$HERMES_HOME/image_cache"; do
    if [ -d "$cache_dir" ]; then
        find "$cache_dir" -type f -mmin +1440 -delete 2>/dev/null
        log "   ✅ کش $(basename "$cache_dir") پاکسازی شد"
    fi
done

# ۴. پاکسازی models_dev_cache.json (قابل بازسازی)
log "۴. پاکسازی models_dev_cache..."
if [ -f "$HERMES_HOME/models_dev_cache.json" ]; then
    rm -f "$HERMES_HOME/models_dev_cache.json"
    log "   ✅ models_dev_cache.json حذف شد (قابل بازسازی خودکار)"
fi

# ۵. بررسی اندازه state.db
log "۵. بررسی state.db..."
state_db="$HERMES_HOME/state.db"
if [ -f "$state_db" ]; then
    db_size=$(stat -f%z "$state_db" 2>/dev/null || stat -c%s "$state_db" 2>/dev/null)
    if [ "$db_size" -gt "$MAX_STATE_DB_SIZE" ]; then
        log "   ⚠️ state.db بیش از 50MB است ($((db_size/1024/1024))MB)"
        log "   💡 پیشنهاد: اجرای hermes sessions prune"
    fi
fi

# ۶. گزارش نهایی
log "=== گزارش نهایی ==="
total_size=$(du -sh "$HERMES_HOME" 2>/dev/null | awk '{print $1}')
disk_free=$(df -h /data | tail -1 | awk '{print $4}')
disk_used=$(df -h /data | tail -1 | awk '{print $5}')

log "📊 اندازه Hermes: $total_size"
log "💾 فضای خالی دیسک: $disk_free"
log "📈 درصد استفاده: $disk_used"
log "=== پایان بهینه‌سازی ==="
