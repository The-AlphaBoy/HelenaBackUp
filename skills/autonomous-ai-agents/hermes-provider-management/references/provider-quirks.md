# Measured provider quirks (2026-08-10, this deployment)

Raw `curl` probes (non-stream, max_tokens=20) against the actual keys present in this container. Catalog listing ≠ availability per account.

## Groq — https://api.groq.com/openai/v1 (key: org ...zt5, free on_demand tier)

| Model | Raw curl | Hermes (tools) | Hermes (no tools) | Notes |
|---|---|---|---|---|
| llama-3.3-70b-versatile | ✓ | ❌ 413 TPM 12000 / req 18509 | ✓ | default-capable, slow-ish |
| openai/gpt-oss-120b | ✓ | ❌ 413 TPM 8000 / req 14099 | ✓ | |
| openai/gpt-oss-20b | ✓ | ❌ 413 TPM 8000 / req 14099 | ✓ | |
| llama-3.1-8b-instant | ✓ | ❌ 413 TPM 6000 / req 18507 | ✓ | |
| qwen/qwen3.6-27b | ✓ | ❌ 400 max_tokens ≤ 16384 | — | config-side |
| groq/compound, compound-mini | — | ❌ 400 tool calling not supported | — | routing models, no tools |

Free-tier TPM limits measured: llama-3.3-70b=12000, gpt-oss-*=8000, llama-3.1-8b=6000.
Hermes full payload ≈ 14.1K (openai models) / 18.5K (llama) tokens; `-t file` ≈ 6K → 8b + file tools passed.
Only ~2 models viable for the gateway (full tools): none on free tier without upgrading (Dev tier) or trimming the default toolset below ~6K.

## NVIDIA — https://integrate.api.nvidia.com/v1 (account ...t80dzDS0U0oRuo)

| Model | Raw curl | Notes |
|---|---|---|
| meta/llama-3.1-8b-instruct | ✓ 1.4–2.8s | fastest verified; Hermes metadata context 16K → "below minimum 64,000 required by Hermes" → rejected by Hermes despite raw success |
| deepseek-ai/deepseek-v4-flash-0731 | ✓ 6.4–8.8s | viable fallback |
| meta/llama-3.3-70b-instruct | timeout >25s (curl), >240s (hermes chat) | avoid |
| nvidia/llama-3.1-nemotron-nano-8b-v1 | timeout/404 | 404 on first probe, timeout on second — flaky |
| nvidia/llama-3.1-nemotron-70b-instruct | 404 Function not found for account | catalog-only |
| mistralai/mistral-7b-instruct-v0.3 | 404 | catalog-only |
| ibm/granite-3.0-3b-a800m-instruct, microsoft/phi-3.5-moe-instruct, aisingapore/sea-lion-7b-instruct, nv-mistralai/mistral-nemo-12b-instruct, qwen/qwen2.5-7b-instruct | 404 | catalog-only |
| adept/fuyu-8b, ai21labs/jamba-1.5-large-instruct, databricks/dbrx-instruct | (listed in /models) | not probed |

404 shape: `{"status":404,"title":"Not Found","detail":"Function '<id>': Not found for account '<account>'"}`.

## OpenAI — current active provider (as of 2026-08-10)
Config: `model.provider: openai-api`, `model.default: openai-api:ForHelena`.
Only provider with a valid API key in `.env` (OPENAI_API_KEY). No fallback providers configured.

## Meta-notes
- Verify with `curl -m 30 -o /tmp/out.json -w "%{http_code} %{time_total}s"` — a 404 answers in ~0.1s, real inference takes seconds, free-tier timeouts are the 70b-class.
- Always cross-check Hermes' own model metadata context window (`hermes chat` error "below the minimum 64,000") — raw curl 200 does not imply Hermes acceptance.
- When Gemini 429s, the LLM context summarizer fails and Hermes falls back to deterministic compaction (degraded but functional). Fix: switch to a provider with quota.
- Provider mismatch (config points to provider X but only Y's key exists): `hermes doctor` catches it. Fix: `hermes config set model.provider <available>`, clear stale fallbacks, set model.default.
