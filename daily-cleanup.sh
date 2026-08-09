#!/bin/bash
# Smart Daily Cleanup - The Guardian Protocol

LOG_FILE="/data/workspace/HelenaBackUp/cleanup_history.txt"
PERMANENT_DIR="/data/workspace/permanent"

echo "Cleanup started at $(date)" >> $LOG_FILE

# 1. Check if GitHub sync is okay before cleaning
cd /data/workspace/HelenaBackUp
git diff --quiet
if [ $? -ne 0 ]; then
    echo "ERROR: Git repo not synced. Cancelling cleanup to prevent data loss." >> $LOG_FILE
    exit 1
fi

# 2. Sync permanent files to Telegram (if changed)
# This part uses a placeholder for the logic we'll add
echo "Checking permanent files..." >> $LOG_FILE
# (Future: Logic to compare and send changed files to Telegram via bot token)

# 3. Intelligent Pruning of cache/tmp
# Only delete files older than 7 days that are NOT in /data/workspace/permanent
find /data/workspace/ -type f -mtime +7 ! -path "$PERMANENT_DIR/*" -delete

echo "Cleanup finished at $(date)" >> $LOG_FILE
