# Iran Network Restrictions — Hermes Deployment Notes

## Blocked Services (from Iran)

| Service | Status | Impact |
|---------|--------|--------|
| Railway.com | 🚫 Filtered | Cannot access Railway dashboard to configure domains/networking |
| Cloudflare (trycloudflare.com) | 🚫 Filtered | Quick tunnel URLs may not load from Iranian browsers |
| Railway public domains | 🚫 Filtered | `*.up.railway.app` URLs blocked |
| Telegram | ✅ Works | Primary communication channel — reliable |
| GitHub | ✅ Works | Backup pushes work fine from Railway servers |

## Workarounds

1. **Telegram as primary interface** — All Hermes operations (chat, config, skills, cron, sessions) work through Telegram. This is the most reliable path for Iranian users.

2. **Cloudflare tunnels work server-side** — The tunnel process runs on Railway (not Iran), so `curl` from the server succeeds. The problem is the Iranian client cannot reach `trycloudflare.com`. Tested: VPN does NOT fix this.

3. **No VPN workaround for Cloudflare** — User tested with VPN and normal internet. Both Railway dashboard and Cloudflare tunnel URLs fail to load. Only Telegram works reliably.

4. **For persistent web access** — Need a domain hosted on a non-filtered DNS provider (not Cloudflare/Railway).

## Real-world test results (2026-07-30)

- `https://observe-dsl-investigators-directory.trycloudflare.com/login` — returns 200 OK from server, empty/blank from Iranian browser (with and without VPN)
- Railway dashboard — completely inaccessible from Iran
- Telegram bot — works perfectly, zero issues
