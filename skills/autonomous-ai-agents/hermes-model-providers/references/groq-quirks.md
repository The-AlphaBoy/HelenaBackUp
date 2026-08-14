# Groq observed quirks (free tier, org org_01kzhr28zbe5xs29hvbq508zt5, Aug 2026)

## Models available on the key (15)
allam-2-7b, canopylabs/orpheus-arabic-saudi, canopylabs/orpheus-v1-english,
groq/compound, groq/compound-mini, llama-3.1-8b-instant, llama-3.3-70b-versatile,
meta-llama/llama-prompt-guard-2-22m, meta-llama/llama-prompt-guard-2-86m,
openai/gpt-oss-120b, openai/gpt-oss-20b, openai/gpt-oss-safeguard-20b,
qwen/qwen3.6-27b, whisper-large-v3, whisper-large-v3-turbo

## Free-tier TPM limits and observed payloads
All requests below were `hermes chat -q "Say GROQ OK"` with a fresh session.
The "Requested" token count is the full HTTP payload Hermes sends (system
prompt + tools + history) — that is what Groq bills against per minute.

| Model | Free TPM | Payload with full tools | Payload with `-t "file"` | Payload `-t "no tools"` |
|---|---|---|---|---|
| llama-3.1-8b-instant | 6000 | ~18507 → 413 | worked | worked |
| llama-3.3-70b-versatile | 12000 | ~18507 → 413 | worked | worked |
| openai/gpt-oss-120b | 8000 | ~14099 → 413 | worked | worked |
| openai/gpt-oss-20b | 8000 | ~14099 → 413 | n/a | worked |
| qwen/qwen3.6-27b | ? | HTTP 400 max_tokens ≤ 16384 | — | — |
| groq/compound(-mini) | ? | HTTP 400 tool calling not supported | — | — |

Takeaways:
- Full-toolset payloads (14–19K) exceed every free-tier TPM limit → always
  413 with full tools on this account. Not an auth problem.
- `-t "file"` (single tool) shrank the payload under the limits and worked.
- `-t "no tools"` worked for every model (smallest payload).
- Error message shape to grep for: `Request too large for model \`<m>\` ...
  tokens per minute (TPM): Limit <N>, Requested <M>`.

## Groq gateway environment notes
- GROQ_API_KEY exists in container PID-1 environ but is NOT in the session
  env and NOT in /data/.hermes/.env (entrypoint.sh writes only an allowlist
  of keys; GROQ_API_KEY is not in that list).
- Base URL: https://api.groq.com/openai/v1 (OpenAI-compatible).
- Invalid key response: {"error":{"message":"Invalid API Key","type":"invalid_request_error","code":"invalid_api_key"}}

## Hermes payload lever
Full toolset ≈ 14–19K tokens of system prompt + tool definitions for this
agent. `hermes chat -t "file"` ≈ ~6–8K. Config knob for the gateway:
restrict toolsets (gateway uses all default tools) or pick a provider with
higher TPM. Groq Dev Tier raises limits substantially.
