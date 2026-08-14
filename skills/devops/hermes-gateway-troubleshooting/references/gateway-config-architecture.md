# Gateway Config Architecture

How `load_gateway_config()` in `gateway/config.py` loads and merges configuration for the messaging gateway.

## Loading Priority (highest to lowest)

1. **Environment variables** — `_getenv()` via secret scope (profile-aware)
2. **`~/.hermes/config.yaml`** — primary user-facing config
3. **`~/.hermes/gateway.json`** — legacy, provides defaults under config.yaml
4. **Built-in defaults**

## Key Functions

### `_getenv()` — Profile-Aware Env Resolution
```python
def _getenv(name: str, default: Optional[str] = None) -> Optional[str]:
    if current_secret_scope() is not None:
        scope_val = _get_secret(name, None)
        return scope_val if scope_val is not None else default
    env_val = os.environ.get(name)
    return env_val if env_val is not None else default
```
- Under multiplex (multi-profile), reads from active secret scope
- Single-profile: falls through to `os.environ`

### `_apply_env_overrides()` — Env → Config Merge
Called at end of `load_gateway_config()`. Applies env vars directly to `GatewayConfig`:
- `TELEGRAM_HOME_CHANNEL` → `config.platforms[Platform.TELEGRAM].home_channel`
- `TELEGRAM_BOT_TOKEN` → `config.platforms[Platform.TELEGRAM].token`
- Platform `enabled` flag set when token present

### Plugin Enablement Gate
Registry-driven enable for plugin platforms (Telegram, Discord, etc.):
```python
# In load_gateway_config():
if entry.is_connected(config):  # checks token
    if entry.check_fn():  # SDK importable
        config.platforms[platform].enabled = True
```
User explicit `enabled: false` in config.yaml is respected via `_enabled_explicit` marker.

## Home Channel Wiring

`home_channel` only set when:
1. Platform is enabled (`config.platforms[platform].enabled == True`)
2. Env var exists (`TELEGRAM_HOME_CHANNEL`)

```python
telegram_home = getenv("TELEGRAM_HOME_CHANNEL")
if telegram_home and Platform.TELEGRAM in config.platforms:
    config.platforms[Platform.TELEGRAM].home_channel = HomeChannel(...)
```

## Critical Flags

### `_enabled_explicit: true`
Set in `PlatformConfig.extra` when user explicitly wrote `enabled: true/false` in config.yaml. Prevents registry from re-enabling a platform user explicitly disabled.

### `_enabled_explicit: false` / absent
Registry may auto-enable based on token + SDK presence.

## Debugging Tips

```bash
# View loaded config
hermes config get platforms.telegram

# Check if platform thinks it's connected
export PATH="/opt/venv/bin:$PATH"
python3 -c "
from gateway.config import load_gateway_config
cfg = load_gateway_config()
print('telegram enabled:', cfg.platforms.get('telegram', {}).enabled if hasattr(cfg.platforms.get('telegram', {}), 'enabled') else 'N/A')
print('telegram home:', cfg.get_home_channel('telegram'))
"
```