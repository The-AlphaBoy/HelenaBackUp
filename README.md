# LLM Proxy Worker

Multi-provider LLM proxy with automatic fallback:
- DeepInfra (free models, public endpoint)
- NVIDIA NIM (free, public endpoint)  
- OpenRouter (needs API key)
- Groq (needs API key)
- Together.ai (needs API key)

## Endpoints

- `GET /health` - Health check
- `GET /v1/models` - List models from all providers
- `POST /v1/chat/completions` - Chat with auto-fallback

## Usage

```bash
# Auto provider detection
curl -X POST https://llm-proxy.thealphaboy.workers.dev/v1/chat/completions \
  -H "Authorization: Bearer YOUR_OPENROUTER_KEY" \
  -d '{"model":"meta-llama/llama-3.1-8b-instruct:free","messages":[{"role":"user","content":"Hi"}]}'

# Explicit provider
curl -X POST "https://llm-proxy.thealphaboy.workers.dev/v1/chat/completions?provider=deepinfra" \
  -d '{"model":"meta-llama/Meta-Llama-3.1-8B-Instruct","messages":[{"role":"user","content":"Hi"}]}'
```

## Deploy

1. Push to GitHub
2. Connect in Cloudflare Workers Dashboard: Settings > Build & Deploy > Connect to Git
3. Add secrets: `wrangler secret put DEEPINFRA_KEY` etc.