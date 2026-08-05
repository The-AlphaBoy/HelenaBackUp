#!/bin/bash
# Security audit: check if old credentials are still in git history and whether they're active
cd /data/workspace/HelenaBackUp || exit 1

echo "=== کلیدهای موجود در نسخه‌های قدیمی .env (نمایش ماسک‌شده) ==="
for c in f6a2d7d 73f4b2b 17667fd 9da0d12; do
  echo "--- commit $c ---"
  git show $c:.env 2>/dev/null | grep -oE "(sk-[a-zA-Z0-9_-]{8,}|[0-9]{8,}:[A-Za-z0-9_-]{20,}|nvapi-[a-zA-Z0-9_-]{8,})" | sed 's/\(.\{10\}\).*/\1.../'
done

echo ""
echo "=== auth.json در تاریخچه (ماسک‌شده) ==="
for c in 7af3a3d 73f4b2b f6a2d7d; do
  echo "--- commit $c ---"
  git show $c:auth.json 2>/dev/null | grep -oE "\"(api_key|key|token|password)\"[[:space:]]*:[[:space:]]*\"[^\"]{8,}\"" | sed 's/\(:\s*\".....\).*/\1..."/'
done

echo ""
echo "=== مقایسه کلید قدیمی vs فعلی ==="
CURRENT=$(grep OPENAI_API_KEY /data/.hermes/.env | cut -d= -f2-)
OLD=$(git show f6a2d7d:.env 2>/dev/null | grep OPENAI_API_KEY | cut -d= -f2-)
echo "کلید فعلی : ${CURRENT:0:12}..."
echo "کلید قدیمی: ${OLD:0:12}..."
if [ -n "$OLD" ] && [ "$CURRENT" = "$OLD" ]; then
  echo "⚠️  خطر: همون کلید قدیمی هنوز فعاله و توی گیت‌هاب تاریخچه داره!"
else
  echo "✅ کلید عوض شده یا قدیمی غیرفعاله"
fi

echo ""
echo "=== توکن تلگرام قدیمی vs فعلی ==="
TCURRENT=$(grep TELEGRAM_BOT_TOKEN /data/.hermes/.env | cut -d= -f2-)
TOLD=$(git show f6a2d7d:.env 2>/dev/null | grep TELEGRAM_BOT_TOKEN | cut -d= -f2-)
echo "توکن فعلی : ${TCURRENT:0:12}..."
echo "توکن قدیمی: ${TOLD:0:12}..."
if [ -n "$TOLD" ] && [ "$TCURRENT" = "$TOLD" ]; then
  echo "⚠️  خطر: توکن تلگرام قدیمی توی گیت‌هاب تاریخچه داره!"
else
  echo "✅ توکن عوض شده"
fi
