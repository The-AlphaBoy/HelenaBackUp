# Additional Gateway Issues (2026-08-10)

Patterns discovered but not yet merged into the main SKILL.md due to content-loading guard.

## 7. Stale-Module Crash After Code Update

**Symptom:** `Error: This gateway is running code from <old_hash> but the checkout on disk is now <new_hash>. Switching models would risk a stale-module crash`

**Root Cause:** Git checkout updated the code but the running gateway process still has old modules loaded.

**Fix:** `hermes gateway restart` from outside the gateway process (from a separate shell). The agent cannot do this from inside — SIGTERM propagates to child processes and kills the command before it completes.

## 8. Provider Mismatch (config vs .env keys)

**Symptom:** `hermes doctor` reports "No credentials found for provider 'X'" or API calls fail with auth errors despite keys existing in `/proc/1/environ`.

**Root Cause:** `model.provider` or `fallback_providers` reference a provider whose API key isn't in `~/.hermes/.env`. Only a whitelist of keys gets copied from container env by the entrypoint script; others stay in PID-1 env only.

**Fix:**
```bash
# Check available keys
cat ~/.hermes/.env | grep API_KEY
# Switch provider to one with a valid key
hermes config set model.provider <available_provider>
hermes config set model.default "<provider>:<model>"
# Clear broken fallbacks
hermes config set fallback_providers '[]'
# User restarts gateway externally
```

**Observed 2026-08-10:** Config had `model.provider: nvidia` + nvidia fallbacks, but only `OPENAI_API_KEY` existed in `.env`. Additionally Gemini was hitting 429 (RESOURCE_EXHAUSTED), causing the LLM context summarizer to fail and fall back to deterministic compaction. Fixed by switching to `openai-api` provider with `ForHelena` model and clearing fallbacks.

## 9. max_tokens Exceeds Provider Output Cap

**Symptom:** `max_tokens exceeds the provider's output cap for this model. Lower model.max_tokens in config.yaml.`

**Fix:** `hermes config set model.max_tokens <lower_value>` (e.g. 4096 for most free-tier providers).

## 10. Gemini 429 Context Summarization Fallback

**Symptom:** When Gemini hits HTTP 429 (RESOURCE_EXHAUSTED), the LLM-based context summarizer fails and Hermes falls back to a deterministic (non-LLM) compaction. This produces a degraded summary — functional but missing nuance.

**Fix:** Switch to a provider with available quota. The deterministic fallback is a safety net, not a resolution.
