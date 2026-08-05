#!/bin/bash
# Rebuild HelenaBackUp repo with clean history (no secrets), then push.
set -e

REPO_DIR="/data/workspace/HelenaBackUp"
TMP_DIR="/tmp/helenabackup-rebuild"
BARE_DIR="/tmp/helenabackup-bare"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

cd "$REPO_DIR"

echo "=== 1. گرفتن آخرین حالت فایل‌ها از HEAD ==="
# Add current tracked files (with fixes: .gitignore + patched scripts)
git add -A

echo "=== 2. حذف هر فایل حساس از index ==="
git rm -r --cached . 2>/dev/null || true
# Re-add everything EXCEPT secrets (respecting .gitignore)
git add -A
git reset -q -- .env 2>/dev/null || true

# Double-check nothing sensitive is staged
STAGED_SECRETS=$(git diff --cached --name-only | grep -E '(^|/)\.env($|\.)|auth\.json|\.pem$|\.key$|token' || true)
if [ -n "$STAGED_SECRETS" ]; then
  echo "❌ هنوز فایل حساس توی index هست: $STAGED_SECRETS"
  exit 1
fi
echo "✅ هیچ فایل حساسی در index نیست"

echo "=== 3. ساخت history جدید (بدون هیچ ردی از کلیدها) ==="
rm -rf "$TMP_DIR" "$BARE_DIR"
git clone --no-hardlinks . "$TMP_DIR"
cd "$TMP_DIR"
rm -rf .git

git init -q
git config user.name "Helena Backup Bot"
git config user.email "helena@backup.local"
git branch -m main
git add -A
# Final safety: scan staged content for REAL secret patterns (exclude placeholder examples like sk-xxx)
if git diff --cached | grep -E "^\+.*(sk-[a-zA-Z0-9]{20}|nvapi-[a-zA-Z0-9]{20}|[0-9]{8,}:[A-Za-z0-9_-]{20})" | grep -vE "sk-xxx|sk-XXXX|example|placeholder|YOUR_|your-|sk-YOUR" | head -1 | grep -q .; then
  echo "❌ اسکن امنیتی staged content ناموفق بود!"
  exit 1
fi
git commit -q -m "🔒 Rebuild clean history — secrets removed ($TIMESTAMP)"
echo "✅ commit جدید: $(git rev-parse --short HEAD)"

echo "=== 4. جایگزینی history ریپو ==="
git init -q --bare "$BARE_DIR"
cd "$TMP_DIR"
git remote add bare "$BARE_DIR" 2>/dev/null || git remote set-url bare "$BARE_DIR"
git push -q bare HEAD:main 2>&1 | tail -1 || true

echo "=== 5. بازسازی working repo از bare ==="
cd /data/workspace
rm -rf "$REPO_DIR"
git clone -q "$BARE_DIR" "$REPO_DIR"
cd "$REPO_DIR"
git config user.name "Helena Backup Bot"
git config user.email "helena@backup.local"
git config credential.helper '!gh auth git-credential'

echo "=== 6. بررسی نهایی: تاریخچه جدید ==="
echo "تعداد commit: $(git rev-list --count HEAD)"
echo "فایل‌ها: $(git ls-files | wc -l)"
if git log --all --oneline -- .env auth.json | head -1; then
  echo "❌ هنوز .env توی تاریخچه هست!"
  exit 1
else
  echo "✅ هیچ .env/auth.json توی تاریخچه نیست"
fi

echo "=== 7. push به گیت‌هاب ==="
git push -f origin main 2>&1 | tail -2
echo "🎉 تمام شد!"
