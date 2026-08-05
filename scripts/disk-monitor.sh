#!/bin/bash
# 💾 Disk Monitor - بررسی فضای دیسک
# هر 30 دقیقه اجرا میشه

THRESHOLD=80
USAGE=$(df /data | tail -1 | awk '{print $5}' | sed 's/%//')
FREE=$(df -h /data | tail -1 | awk '{print $4}')

if [ "$USAGE" -ge "$THRESHOLD" ]; then
    echo "⚠️ هشدار: فضای دیسک کم است!"
    echo "📊 فضای پر: ${USAGE}%"
    echo "💾 فضای آزاد: ${FREE}"
    echo ""
    echo "🔧 اقدامات پیشنهادی:"
    echo "1. پاکسازی cache"
    echo "2. حذف لاگ‌های قدیمی"
    echo "3. بررسی فایل‌های حجیم"
else
    echo "✅ فضای دیسک اوکیه: ${USAGE}% پر - ${FREE} آزاد"
fi