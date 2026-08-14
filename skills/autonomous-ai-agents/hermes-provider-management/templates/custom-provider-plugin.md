# Custom model-provider plugin for Hermes

Drop-in for a provider that ships no bundled profile (worked for Groq 2026-08-10).
Location: `$HERMES_HOME/plugins/model-providers/<name>/` (here: `/data/.hermes/plugins/model-providers/groq/`).
User plugins override bundled profiles of the same name (last-writer-wins). Discovery is lazy — first `get_provider_profile()` / `list_providers()` call imports everything; api_key-auth profiles auto-extend CANONICAL_PROVIDERS.

## File 1: `__init__.py`

```python
"""<Name> provider profile.

<Name> serves an OpenAI-compatible endpoint at <base_url>.
Auth is a plain API key via <ENV_VAR>. No request-shape quirks — the
standard chat_completions path works as-is.
"""

from __future__ import annotations

from providers import register_provider
from providers.base import ProviderProfile

<name> = ProviderProfile(
    name="<name>",
    aliases=("<name>",),
    env_vars=("<ENV_VAR>",),
    display_name="<Name>",
    description="<Name> (one-line human description)",
    signup_url="<console URL for keys>",
    fallback_models=(
        "<model-1>",
        "<model-2>",
    ),
    base_url="<base_url>",  # e.g. https://api.groq.com/openai/v1
    default_aux_model="<cheap-model>",
)

register_provider(<name>)
```

## File 2: `plugin.yaml`

```yaml
name: <name>-provider
kind: model-provider
version: 1.0.0
description: <Name> (one-line)
author: Nous Research
```

## Verification (no TTY needed)

```bash
cd /opt/hermes-agent && python3 -c "from providers import get_provider_profile; print(get_provider_profile('<name>'))"
# expect: profile:<name> | base_url:<base_url>
```

Then `hermes config set model.provider <name>` + `hermes config set model.model <slug>` and `hermes status`.

## Key caveats
- The key env var must reach the process: `GROQ_API_KEY`/`NVIDIA_API_KEY` are NOT in this deployment's `.env` whitelist (entrypoint.sh) — export per command.
- Low free-tier TPM → Hermes full-tools payload (14–18.5K) gets 413; test with `-t "no tools"` to separate key validity from payload size.
