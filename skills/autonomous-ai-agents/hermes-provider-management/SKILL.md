---
name: hermes-provider-management
description: "Add/switch Hermes providers: plugins, 413 limits, verify."
version: 1.0.0
author: Hermes Agent
metadata:
  hermes:
    tags: [hermes, providers, groq, nvidia, configuration, llm, rate-limits]
---

# Hermes Provider Management

How to switch the inference provider/model in this Hermes deployment, add a provider that ships with no bundled profile (e.g. Groq), and diagnose API errors (413 payload/TPM, 429, 404, timeouts) quickly. Complements the bundled `hermes-agent` skill — read its `references/providers-and-models.md` for the general provider table; this skill covers mechanics learned in practice.

## User workflow preference (AmirReza)
- Persian speaker — report in Persian, one line per step, after EVERY step. Never go silent for minutes.
- Bounded probes only: curl with `-m 30`; never long silent `hermes chat` loops.
- "متوقفش کن" / "خیلی طول کشید" → stop immediately, summarize what is known, no more tests.

## Environment facts (this deployment)
- Docker on Railway. `HERMES_HOME=/data/.hermes`; CLI at `/opt/venv/bin/hermes` — `export PATH="/opt/venv/bin:$PATH"` first.
- Secrets: the container PID-1 environment (via /proc/1/environ) holds all provider keys. `/app/scripts/entrypoint.sh` copies only a whitelist to `/data/.hermes/.env`; `GROQ_API_KEY` and `NVIDIA_API_KEY` are NOT whitelisted → export explicitly per command.
- `hermes model` requires a TTY (refuses piped runs); `hermes config get` takes ONE key per call. Non-interactive path: `hermes config set model.provider <p>` and `hermes config set model.model <slug>`, then confirm with `hermes status`.
- `hermes gateway restart` is blocked from inside the gateway process — never attempt; provider/model changes apply to new chats without any restart.

## Provider switch sequence
1. `hermes status` → note current Model / Provider lines.
2. Verify the key and latency-test candidates with `scripts/probe-provider.sh <base_url> <api_key> <model...>` (bounded 30s per probe).
3. Pick the fastest HTTP 200 model. Catalog ≠ availability — probe before configuring (many NVIDIA catalog models 404 per-account).
4. Apply: `hermes config set model.provider <p>`; `hermes config set model.model <slug>`.
5. Confirm with `hermes status`, then run ONE `hermes chat -q "ping"` smoke test. Do NOT declare the switch done without the smoke test.

## Adding a provider with no bundled profile (e.g. Groq)
1. Create `$HERMES_HOME/plugins/model-providers/<name>/` containing `__init__.py` (a `ProviderProfile` instance + `register_provider(...)`) and `plugin.yaml` (`kind: model-provider`). Copy `templates/custom-provider-plugin.md`.
2. User plugins override bundled profiles of the same name (last-writer-wins); discovery is lazy (first `list_providers()` / `get_provider_profile()` call) and auto-extends CANONICAL_PROVIDERS for `api_key` auth types.
3. Verify registration without a TTY:
   `cd /opt/hermes-agent && python3 -c "from providers import get_provider_profile; print(get_provider_profile('<name>'))"`

## The 413 payload trap
Hermes' full system prompt + all tools ≈ 14–18.5K tokens per request. Free tiers with low TPM reject it: HTTP 413 "Request too large ... on tokens per minute (TPM): Limit N, Requested M".
- Isolate "bad key" vs "payload too big" by retrying with `-t "no tools"` — if that passes, the key is fine and the issue is TPM/payload.
- Trim toolsets (`-t "file"` or `-t "no tools"`) to fit low-TPM free tiers. Measured per-provider limits: `references/provider-quirks.md`.

## Pitfalls
- Hermes rejects models whose metadata context < 64K ("below the minimum 64,000 required by Hermes") even when the raw API works — e.g. `meta/llama-3.1-8b-instruct` on NVIDIA (16K per Hermes metadata). Curl success ≠ Hermes success.
- Groq `groq/compound` / `compound-mini`: HTTP 400 "tool calling is not supported with this model". `qwen/qwen3.6-27b`: HTTP 400, max_tokens ≤ 16384.
- NVIDIA: most of the ~100 catalog models 404 per-account ("Function ... Not found for account"); `meta/llama-3.3-70b-instruct` > 25s (curl) / > 240s (hermes chat) — avoid; `meta/llama-3.1-8b-instruct` ~1.4–2.8s (fastest raw); `deepseek-ai/deepseek-v4-flash-0731` ~6–9s.
- Full measured tables: `references/provider-quirks.md`.

## Session state (2026-08-10)
Config applied: `nvidia` + `meta/llama-3.1-8b-instruct` (fastest curl-verified) — but the final `hermes chat` smoke test was skipped (user stopped the session). The <64K-context pitfall suggests this combo may be rejected on the gateway. Next session: smoke-test first; if rejected, switch to `deepseek-ai/deepseek-v4-flash-0731` and re-verify.
