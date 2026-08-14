---
name: hermes-model-providers
description: "Switch/add Hermes model providers; diagnose 413 rate limits."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, providers, models, groq, configuration, rate-limits]
---

# Hermes Model Provider Setup & Switching

Trigger: user asks to switch or add a model provider (Groq, DeepSeek, etc.) in
Hermes, `hermes chat`/gateway says "Unknown provider 'X'", or model calls fail
with rate-limit / 413 errors. Companion to the bundled `hermes-agent` skill
(which is protected — this skill carries the operational detail and pitfalls).

## Non-interactive config & verification

- `hermes model` and `hermes setup` require a TTY — they fail in pipes/CI.
  Configure non-interactively instead:
  - `hermes config set model.provider <provider>` (ONE key per invocation)
  - `hermes config set model.model <model-id>` (separate call)
  - `hermes config get <key>` also takes exactly ONE key — passing two prints
    the usage banner with "unrecognized arguments".
- Verify resolution with `hermes status` — the Environment block shows the
  resolved `Model:` and `Provider:` lines.
- Test a provider live, non-interactively:
  `hermes chat -q "Say OK" -m <model> --provider <provider>`
  - `-t "file"` or `-t "no tools"` shrinks the system-prompt+toolset payload —
    the key lever when hitting per-minute token limits (see pitfalls).
- Never hand-edit config.yaml; always `hermes config set`.

## Adding a provider with no bundled profile (e.g. Groq)

Provider discovery (`providers/__init__.py`, lazy, once per process):
1. Bundled: `<repo>/plugins/model-providers/<name>/`
2. User: `$HERMES_HOME/plugins/model-providers/<name>/` — **overrides** a
   bundled profile of the same name (last-writer-wins)

Each plugin dir needs exactly two files:
- `plugin.yaml`:
  ```yaml
  name: groq-provider
  kind: model-provider
  version: 1.0.0
  description: Groq (LPU-powered fast inference, OpenAI-compatible)
  author: Nous Research
  ```
- `__init__.py`: instantiate `ProviderProfile(...)` and call
  `register_provider(...)` at module level. See
  `templates/groq-provider-init.py` for a known-good Groq profile to copy.

Useful `ProviderProfile` fields: `name`, `aliases`, `env_vars`,
`display_name`, `description`, `signup_url`, `fallback_models`, `base_url`,
`default_aux_model`. Plain OpenAI-compatible providers need nothing else —
the standard `chat_completions` path just works.

Quick sanity check after creating the plugin (no gateway restart needed for a
fresh process):
```bash
cd /opt/hermes-agent && HERMES_HOME=$HERMES_HOME /opt/venv/bin/python -c "
from providers import get_provider_profile, list_providers
p = get_provider_profile('groq')
print(p.name, p.base_url, any(x.name=='groq' for x in list_providers()))"
```

Alternative without a plugin: `model.provider: custom` + `model.base_url`.
Host-derived key lookup maps `api.<vendor>.com` → `<VENDOR>_API_KEY`
automatically (`api.groq.com` → `GROQ_API_KEY`, `api.deepseek.com` →
`DEEPSEEK_API_KEY`, etc. — see `hermes_cli/runtime_provider.py::_host_derived_api_key`).

**Gateway pick-up:** provider discovery happens once per process, so the
long-running gateway needs a restart to see a new user plugin. Note
`hermes gateway restart` is BLOCKED from inside the gateway process
(SIGTERM propagation guard) — restart from a separate shell or bounce the
container.

## Pitfalls

- **Groq free-tier HTTP 413 is a rate limit, not an auth error**: "Request
  too large ... tokens per minute (TPM): Limit N, Requested M". Hermes'
  system prompt + full toolset ≈ 14–19K tokens per request; Groq free TPM is
  6–12K. Fixes: shrink the toolset (`-t "file"`; trim gateway toolsets),
  upgrade the Groq tier, or pick a higher-limit provider. A 413 with
  `Requested` in it actually PROVES the key works.
- **`groq/compound` and `groq/compound-mini` reject tool calling** (HTTP 400
  "tool calling is not supported with this model") — useless as the main
  agent model.
- **`qwen/qwen3.6-27b` on Groq caps `max_tokens` at 16384** (HTTP 400).
- **Container env vars aren't in your shell**: `GROQ_API_KEY` may exist in
  PID 1's environ but not in the session env or `.env` (entrypoint.sh writes
  only an allowlist). Extract with:
  `tr '\0' '\n' < /proc/1/environ | grep '^GROQ_API_KEY=' | cut -d= -f2-`
- **Validate the key independently** before blaming Hermes:
  `curl -s https://api.groq.com/openai/v1/models -H "Authorization: Bearer $KEY"`
  → model list = valid; `{"error":{"message":"Invalid API Key"}}` = bad key.
- `hermes` may not be on PATH in containers — it lives at `/opt/venv/bin/hermes`.

## User communication preference

This user (AmirReza) writes in Persian and expects replies in Persian.
Keep replies concise and drop a one-line progress note between long tool
chains — he nudges with "خب؟" / "چی شد؟" when a step runs silently too long.

See `references/groq-quirks.md` for the observed Groq rate-limit table,
payload sizes, and the full test matrix from the first setup.
