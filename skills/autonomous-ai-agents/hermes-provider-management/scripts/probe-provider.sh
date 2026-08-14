#!/usr/bin/env bash
# Probe OpenAI-compatible providers: key validity + per-model latency, bounded.
# Usage: probe-provider.sh <base_url> <api_key> <model> [<model> ...]
# Example: probe-provider.sh https://integrate.api.nvidia.com/v1 "$NVIDIA_API_KEY" meta/llama-3.1-8b-instruct deepseek-ai/deepseek-v4-flash-0731
set -u
BASE_URL="${1:?base_url required}"
KEY="${2:?api_key required}"
shift 2
[ "$#" -ge 1 ] || { echo "at least one model required"; exit 2; }

# quick key check
code=$(curl -s -m 15 -o /tmp/probe_models.json -w "%{http_code}" "$BASE_URL/models" -H "Authorization: Bearer $KEY")
echo "[key-check] GET $BASE_URL/models -> HTTP $code"
if [ "$code" != "200" ]; then echo "KEY INVALID or endpoint wrong"; head -c 300 /tmp/probe_models.json; echo; exit 1; fi

for M in "$@"; do
  out=$(curl -s -m 30 -o /tmp/probe_out.json -w "%{http_code}|%{time_total}|%{time_starttransfer}" \
    "$BASE_URL/chat/completions" \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d "{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"Say exactly: OK\"}],\"max_tokens\":20,\"stream\":false}")
  http=${out%%|*}; rest=${out#*|}; total=${rest%%|*}; ttfb=${rest##*|}
  echo "$M => HTTP $http | total ${total}s | ttfb ${ttfb}s"
  [ "$http" = "200" ] || head -c 200 /tmp/probe_out.json
  echo
done
