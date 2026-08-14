# SQLite 3.46.1 WAL-Reset Bug

## The Bug

SQLite 3.46.1 (released 2024-08-13) has a corruption bug in WAL mode reset logic:
- **CVE/Reference:** https://sqlite.org/wal.html#walresetbug
- **Trigger:** Checkpoint/reset of WAL file under specific timing conditions
- **Impact:** Database corruption, FK constraint failures, "database disk image is malformed"

## Affected Versions

| Version | Status |
|---------|--------|
| 3.46.1 | **VULNERABLE** — has WAL-reset bug |
| 3.46.0 | Safe |
| 3.45.x | Safe |
| 3.44.6 | **PATCHED** (backport) |
| 3.50.7 | **PATCHED** (backport) |
| 3.51.3+ | **FIXED** |

## Hermes Detection & Workaround

Hermes `doctor` detects this automatically:
```
⚠ SQLite 3.46.1 (WAL-reset bug) (run `hermes update`; fixed versions: 3.51.3+ / 3.50.7 / 3.44.6)
→ state.db: rollback journal mode (34.5 MB, not exposed)
```

Hermes **forces `journal_mode=DELETE`** (rollback journal) instead of WAL when it detects 3.46.1, avoiding the bug entirely.

## Symptoms in Hermes

When WAL mode is somehow enabled on 3.46.1:
- `FOREIGN KEY constraint failed` on session DB writes
- "database or disk is full" (false positive from corruption)
- `PRAGMA integrity_check` may fail
- WAL file not checkpointing properly

## Verification

```bash
# Check SQLite version
sqlite3 --version
# or
python3 -c "import sqlite3; print(sqlite3.sqlite_version)"

# Check journal mode
sqlite3 ~/.hermes/state.db "PRAGMA journal_mode;"
# Should return: delete  (not wal)

# Check FK state
sqlite3 ~/.hermes/state.db "PRAGMA foreign_keys;"
# Hermes typically runs with FK=OFF to avoid constraint issues
```

## Fix Options

### Option 1: `hermes update` (Recommended)
Updates embedded Python/SQLite runtime if Hermes manages it:
```bash
hermes update
```

### Option 2: System Package Update
```bash
# Debian/Ubuntu
apt update && apt install sqlite3 libsqlite3-0

# Alpine
apk upgrade sqlite-libs

# Check after
sqlite3 --version
```

### Option 3: Stay on DELETE Mode (Current Workaround)
If update not possible, ensure Hermes keeps using DELETE mode:
- Don't manually enable WAL: `PRAGMA journal_mode=WAL;`
- Hermes doctor will warn but continues working safely

## Why FK Errors Appear

With WAL mode + bug:
1. Checkpoint fails to flush WAL to main DB
2. Parent session row visible in memory but not on disk
3. Child message insert → FK lookup misses parent → **FK constraint failed**

With DELETE mode (current):
- No WAL, direct writes to DB file
- No checkpoint race condition
- FK still OFF by default in Hermes → fewer false positives

## References

- SQLite WAL Reset Bug: https://sqlite.org/wal.html#walresetbug
- Hermes doctor source: `gateway/config.py` → `_load_gateway_config()` → SQLite version check
- Related: FK pragma handling in `agent/state.py`