export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check
    if (url.pathname === '/health') {
      return Response.json({ status: 'ok', providers: ['openrouter', 'deepinfra', 'nvidia', 'groq', 'together'] }, { headers: corsHeaders });
    }

    // List models from all providers (no auth needed for some)
    if (url.pathname === '/v1/models' || url.pathname === '/models') {
      return handleModels(request, corsHeaders);
    }

    // Chat completions with multi-provider fallback
    if (url.pathname === '/v1/chat/completions' || url.pathname === '/chat/completions') {
      return handleChat(request, corsHeaders);
    }

    return new Response('Not Found', { status: 404, headers: corsHeaders });
  }
};

async function handleModels(request, corsHeaders) {
  const results = [];
  
  // DeepInfra - public models endpoint
  try {
    const resp = await fetch('https://api.deepinfra.com/v1/openai/models');
    if (resp.ok) {
      const data = await resp.json();
      data.data.forEach(m => results.push({ ...m, provider: 'deepinfra' }));
    }
  } catch (e) {}

  // NVIDIA NIM - public models
  try {
    const resp = await fetch('https://integrate.api.nvidia.com/v1/models');
    if (resp.ok) {
      const data = await resp.json();
      data.data.forEach(m => results.push({ ...m, provider: 'nvidia' }));
    }
  } catch (e) {}

  // OpenRouter - needs auth, but we can try
  try {
    const auth = request.headers.get('Authorization');
    if (auth) {
      const resp = await fetch('https://openrouter.ai/api/v1/models', {
        headers: { 'Authorization': auth }
      });
      if (resp.ok) {
        const data = await resp.json();
        data.data.forEach(m => results.push({ ...m, provider: 'openrouter' }));
      }
    }
  } catch (e) {}

  return Response.json({ object: 'list', data: results }, { headers: corsHeaders });
}

async function handleChat(request, corsHeaders) {
  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: 'Invalid JSON' }, { status: 400, headers: corsHeaders });
  }

  const { model, messages, stream, ...params } = body;
  const auth = request.headers.get('Authorization');
  const provider = new URL(request.url).searchParams.get('provider') || 'auto';

  // Determine provider from model name or explicit param
  const selectedProvider = detectProvider(model, provider);
  
  const providers = getProviderOrder(selectedProvider);
  
  for (const p of providers) {
    try {
      const result = await callProvider(p, model, messages, stream, params, auth);
      if (result.ok || result.status !== 403) {
        // Add provider info to response headers
        const headers = new Headers(corsHeaders);
        headers.set('X-Provider', p);
        if (stream) {
          return new Response(result.body, { headers });
        }
        const data = await result.json();
        return Response.json(data, { headers });
      }
    } catch (e) {
      console.log(`Provider ${p} failed:`, e.message);
    }
  }

  return Response.json({ error: 'All providers failed' }, { status: 502, headers: corsHeaders });
}

function detectProvider(model, explicit) {
  if (explicit !== 'auto') return explicit;
  if (!model) return 'auto';
  
  const m = model.toLowerCase();
  if (m.includes('gpt') || m.includes('claude') || m.includes('gemini') || m.includes(':free')) return 'openrouter';
  if (m.includes('deepinfra') || m.startsWith('meta-llama/') || m.startsWith('microsoft/') || m.startsWith('qwen/')) return 'deepinfra';
  if (m.includes('nvidia') || m.includes('nemotron')) return 'nvidia';
  if (m.includes('groq') || m.includes('llama-3.1-') || m.includes('gemma2') || m.includes('mixtral')) return 'groq';
  if (m.includes('together') || m.includes('turbo')) return 'together';
  return 'auto';
}

function getProviderOrder(preferred) {
  const order = ['deepinfra', 'nvidia', 'openrouter', 'groq', 'together'];
  if (preferred !== 'auto') {
    return [preferred, ...order.filter(p => p !== preferred)];
  }
  return order;
}

async function callProvider(provider, model, messages, stream, params, auth) {
  const cleanModel = model.replace(/^(deepinfra|nvidia|openrouter|groq|together)\//, '');
  
  switch (provider) {
    case 'deepinfra':
      return fetch('https://api.deepinfra.com/v1/openai/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': auth || `Bearer ${DEEPINFRA_KEY}`,
        },
        body: JSON.stringify({ model: cleanModel, messages, stream, ...params }),
      });

    case 'nvidia':
      return fetch('https://integrate.api.nvidia.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': auth || `Bearer ${NVIDIA_KEY}`,
        },
        body: JSON.stringify({ model: cleanModel, messages, stream, ...params }),
      });

    case 'openrouter':
      return fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': auth,
          'HTTP-Referer': 'https://llm-proxy.thealphaboy.workers.dev',
          'X-Title': 'Helena LLM Proxy',
        },
        body: JSON.stringify({ model: cleanModel, messages, stream, ...params }),
      });

    case 'groq':
      return fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': auth || `Bearer ${GROQ_KEY}`,
        },
        body: JSON.stringify({ model: cleanModel, messages, stream, ...params }),
      });

    case 'together':
      return fetch('https://api.together.xyz/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': auth || `Bearer ${TOGETHER_KEY}`,
        },
        body: JSON.stringify({ model: cleanModel, messages, stream, ...params }),
      });
  }
}

// These should be set as Worker secrets in Cloudflare Dashboard
const DEEPINFRA_KEY = '';
const NVIDIA_KEY = '';
const GROQ_KEY = '';
const TOGETHER_KEY = '';
