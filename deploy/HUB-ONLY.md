# Hub-only deployment (General + Medical)

Use this when you want **one** workspace at `https://hub.fratelanza.com` — no separate
`crm`, `pos`, or `console` subdomains.

## DNS (Cloudflare)

| Action | Record |
|--------|--------|
| **Keep** | `fratelanza.com` → VPS IP |
| **Keep** | `*.fratelanza.com` → VPS IP (wildcard) |
| **Keep** | `admin.fratelanza.com` → VPS IP |
| **Delete** | `crm`, `pos`, `console` (if separate A records exist) |

The wildcard `*.fratelanza.com` is enough for `hub.fratelanza.com`. You do not need a
dedicated `hub` A record unless you prefer one.

## VPS — remove legacy CRM

```bash
cd ~/Fratelanza-HUB
chmod +x deploy/cleanup-legacy-crm.sh
./deploy/cleanup-legacy-crm.sh
```

This stops `/opt/fratelanza-crm` (old Python project) and removes nginx configs for
`crm`, `pos`, `console`, etc. It does **not** stop the Hub Docker stack.

## VPS — fresh Hub deploy

```bash
cd ~/Fratelanza-HUB
cp .env.example .env
nano .env                    # all secrets; openssl rand -hex 24 (×5)
./deploy/validate-env.sh .env

sudo cp deploy/nginx.conf /etc/nginx/sites-available/fratelanza
sudo ln -sf /etc/nginx/sites-available/fratelanza /etc/nginx/sites-enabled/fratelanza
sudo rm -f /etc/nginx/sites-enabled/crm /etc/nginx/sites-enabled/pos \
  /etc/nginx/sites-enabled/console /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

docker compose up -d --build
```

## Admin — single `hub` customer

1. Open **https://admin.fratelanza.com**
2. **+ Add customer**
   - Name: `Fratelanza Hub` (any label)
   - Subdomain: **`hub`**
   - Specialization: pick clinic type (e.g. General, Physiotherapy)
3. **Enabled features** — tick both sections:
   - **General workspace** (toggle entire section ON)
   - **HR & Payroll** (optional)
   - **Medical — core modules** (toggle ON)
   - **Medical — smart tools** (toggle ON)
4. Save and wait until DB status = **ready**

## Smoke test

```bash
curl -sf http://127.0.0.1:1025/api/healthz && echo " app OK"
curl -sf http://127.0.0.1:1025/api/healthz -H "Host: hub.fratelanza.com" && echo " hub OK"
curl -sfI https://hub.fratelanza.com/api/healthz | head -1
```

Login at **https://hub.fratelanza.com** as `admin` / `TENANT_DEFAULT_ADMIN_PASSWORD`.

Use the top bar to switch between **General** and **Medical** workspaces.
