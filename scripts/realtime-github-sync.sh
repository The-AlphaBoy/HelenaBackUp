#!/bin/bash
# ⚡ Realtime Git Watcher & Sync for Hermes
# Watches key memory, config and skill directories, debounces writes, and pushes to GitHub immediately.

REPO_DIR="/data/workspace/HelenaBackUp"
HERMES_DIR="/data/.hermes"
LOCK_FILE="/tmp/git_sync.lock"

# Target directories to monitor
WATCH_TARGETS=(
    "$HERMES_DIR/memories"
    "$HERMES_DIR/config.yaml"
    "$HERMES_DIR/skills"
    "$HERMES_DIR/SOUL.md"
)

echo "Starting Realtime GitHub Sync daemon..."

sync_to_github() {
    # Simple lock to avoid overlapping syncs
    if [ -f "$LOCK_FILE" ]; then
        return
    fi
    touch "$LOCK_FILE"
    
    # Run the standard secure backup script
    bash /data/.hermes/scripts/hermes-backup.sh >/dev/null 2>&1
    
    rm -f "$LOCK_FILE"
}

# Monitor with inotifywait, with a 5-second debounce window
while true; do
    inotifywait -r -e modify,create,delete,move \
        --exclude '(\.lock|\.tmp|\.log|cache|bin|pending_messages|\.git)' \
        "${WATCH_TARGETS[@]}" 2>/dev/null
    
    # Debounce: wait 5 seconds for rapid changes to settle
    sleep 5
    
    sync_to_github
done
