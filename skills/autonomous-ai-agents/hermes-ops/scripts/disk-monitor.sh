#!/bin/bash
# Hermes Disk Monitor - مانیتورینگ و هشدار فضای دیسک
# این اسکریپت وضعیت دیسک رو چک می‌کنه و در صورت نیاز هشدار می‌ده

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
DISK_USAGE=$(df -h /data | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_FREE=$(df -h /data | tail -1 | awk '{print $4}')
DISK_TOTAL=$(df -h /data | tail -1 | awk '{print $2}')
DISK_USED=$(df -h /data | tail -1 | awk '{print $3}')
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# آستانه‌های هشدار
WARNING_THRESHOLD=70
CRITICAL_THRESHOLD=85
EMERGENCY_THRESHOLD=95

STATUS="✅ عادی"
STATUS_EMOJI="✅"

if [ "$DISK_USAGE" -ge "$EMERGENCY_THRESHOLD" ]; then
    STATUS="🚨 بحرانی"
    STATUS_EMOJI="🚨"
elif [ "$DISK_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
    STATUS="🔴 بحران"
    STATUS_EMOJI="🔴"
elif [ "$DISK_USAGE" -ge "$WARNING_THRESHOLD" ]; then
    STATUS="🟡 هشدار"
    STATUS_EMOJI="🟡"
fi

cat << EOF
📊 **گزارش وضعیت دیسک Hermes**

⏰ زمان: $TIMESTAMP

$STATUS_EMOJI **وضعیت:** $STATUS

💾 **فضای کل:** $DISK_TOTAL
📦 **فضای استفاده شده:** $DISK_USED
🆓 **فضای خالی:** $DISK_FREE
📈 **درصد استفاده:** ${DISK_USAGE}%

🎯 **آستانه‌ها:**
• عادی: کمتر از ${WARNING_THRESHOLD}%
• هشدار: ${WARNING_THRESHOLD}% تا ${CRITICAL_THRESHOLD}%
• بحران: ${CRITICAL_THRESHOLD}% تا ${EMERGENCY_THRESHOLD}%
• بحرانی: بیش از ${EMERGENCY_THRESHOLD}%
EOF

if [ "$DISK_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
    echo "🔧 **اقدام خودکار:** در حال پاکسازی فضا..."
    bash "$HERMES_HOME/../workspace/hermes-disk-manager.sh" 2>/dev/null
    NEW_USAGE=$(df -h /data | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "📊 **وضعیت بعد از پاکسازی:** ${NEW_USAGE}% استفاده"
    if [ "$NEW_USAGE" -ge "$CRITICAL_THRESHOLD" ]; then
        echo "⚠️ **هشدار:** فضا هنوز بحرانی است! لطفاً دستی بررسی کنید."
    fi
fi

echo "---CRON_OUTPUT---"
echo "دیسک: ${DISK_USAGE}% استفاده | ${DISK_FREE} خالی | $STATUS"
