#!/bin/bash
# 🧹 Hermes Auto Cleanup Script
# پاکسازی خودکار کش‌های غیرضروری
# Runs without LLM (no-agent mode) — zero token cost

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
LOG=""

cleaned=0
freed=0

get_size() {
    du -sb "$1" 2>/dev/null | cut -f1 || echo 0
}

format_size() {
    local bytes=$1
    if [ "$bytes" -ge 1048576 ]; then
        local mb=$((bytes / 1048576))
        local frac=$(((bytes % 1048576) * 10 / 1048576))
        echo "${mb}.${frac}MB"
    elif [ "$bytes" -ge 1024 ]; then
        local kb=$((bytes / 1024))
        local frac=$(((bytes % 1024) * 10 / 1024))
        echo "${kb}.${frac}KB"
    else
        echo "${bytes}B"
    fi
}

clean_path() {
    local path="$1"
    local label="$2"
    if [ -d "$path" ] || [ -f "$path" ]; then
        local size=$(get_size "$path")
        if [ "$size" -gt 0 ]; then
            rm -rf "$path"
            freed=$((freed + size))
            cleaned=$((cleaned + 1))
            LOG="${LOG}  ✅ ${label}: $(format_size $size)\n"
        fi
    fi
}

clean_empty_dir() {
    local path="$1"
    if [ -d "$path" ] && [ -z "$(ls -A "$path" 2>/dev/null)" ]; then
        rmdir "$path" 2>/dev/null
    fi
}

# ── 1. Cache files ──
clean_path "/data/.cache/huggingface" "HuggingFace cache"
clean_path "/data/.cache/pip" "pip cache"
clean_path "/data/.cache/huggingface" "HuggingFace cache"
clean_path "$HERMES_HOME/cache/documents" "Document cache"
clean_path "$HERMES_HOME/cache/audio" "Audio cache"
clean_path "$HERMES_HOME/cache/openrouter_model_metadata.json" "OpenRouter metadata"
clean_path "$HERMES_HOME/cache/tool_discovery_cache.json" "Tool discovery cache"
clean_path "$HERMES_HOME/cache/model_catalog.json" "Model catalog"

# ── 2. Stale cache JSON ──
clean_path "$HERMES_HOME/provider_models_cache.json" "Provider models cache"
clean_path "$HERMES_HOME/ollama_cloud_models_cache.json" "Ollama models cache"

# ── 3. Old session dumps (>24h) ──
find "$HERMES_HOME/sessions/" -name "request_dump_*.json" -mmin +1440 -delete 2>/dev/null
old_dumps=$(find "$HERMES_HOME/sessions/" -name "request_dump_*.json" -mmin +1440 2>/dev/null | wc -l)

# ── 4. Log rotation (>7 days) ──
for logfile in "$HERMES_HOME/logs/"*.log; do
    if [ -f "$logfile" ]; then
        size=$(get_size "$logfile")
        if [ "$size" -gt 524288 ]; then  # >500KB
            truncate -s 0 "$logfile"
            freed=$((freed + size))
            cleaned=$((cleaned + 1))
            LOG="${LOG}  ✅ Log rotated: $(basename $logfile) ($(format_size $size))\n"
        fi
    fi
done

# ── 5. Old state snapshots (keep last 2) ──
snap_count=$(ls -d "$HERMES_HOME/state-snapshots/"*/ 2>/dev/null | wc -l)
if [ "$snap_count" -gt 2 ]; then
    excess=$((snap_count - 2))
    ls -dt "$HERMES_HOME/state-snapshots/"*/ 2>/dev/null | tail -n "$excess" | while read dir; do
        size=$(get_size "$dir")
        rm -rf "$dir"
        freed=$((freed + size))
        cleaned=$((cleaned + 1))
        LOG="${LOG}  ✅ Old snapshot: $(basename $dir) ($(format_size $size))\n"
    done
fi

# ── 6. Pre-restore backups ──
for bak in "$HERMES_HOME"/pre-restore-backup-*/; do
    if [ -d "$bak" ]; then
        size=$(get_size "$bak")
        rm -rf "$bak"
        freed=$((freed + size))
        cleaned=$((cleaned + 1))
        LOG="${LOG}  ✅ Pre-restore backup: $(basename $bak) ($(format_size $size))\n"
    fi
done

# ── 7. Clean empty dirs ──
clean_empty_dir "$HERMES_HOME/cache/documents"
clean_empty_dir "$HERMES_HOME/cache/audio"
clean_empty_dir "$HERMES_HOME/image_cache"
clean_empty_dir "$HERMES_HOME/audio_cache"

# ── Summary ──
DISK_AVAIL=$(df -h /data | awk 'NR==2{print $4}')
DISK_PCT=$(df -h /data | awk 'NR==2{print $5}')

if [ "$cleaned" -gt 0 ]; then
    echo "🧹 پاکسازی خودکار — $(date '+%Y-%m-%d %H:%M')"
    echo ".removeItem ${cleaned} فایل حذف شد"
    echo "freeUp $(format_size $freed) فضا آزاد شد"
    echo ""
    printf "$LOG"
    echo ""
    echo "📊 فضای فعلی: ${DISK_PCT} پر — ${DISK_AVAIL} آزاد"
else
    echo "✅ تمیزه! هیچ فایل غیرضروری پیدا نشد."
    echo "📊 فضای فعلی: ${DISK_PCT} پر — ${DISK_AVAIL} آزاد"
fi

# ── 8. Stale model caches ──
clean_path "$HERMES_HOME/models_dev_cache.json" "Model dev cache"
clean_path "$HERMES_HOME/provider_models_cache.json" "Provider models cache"
clean_path "$HERMES_HOME/ollama_cloud_models_cache.json" "Ollama models cache"
