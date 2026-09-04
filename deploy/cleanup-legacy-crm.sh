#!/bin/bash
# Remove legacy CRM / POS / console deployments from this VPS.
# Does NOT stop ~/Fratelanza-HUB — only hub.fratelanza.com should remain.
#
# Usage (on the VPS):
#   chmod +x deploy/cleanup-legacy-crm.sh
#   ./deploy/cleanup-legacy-crm.sh
#
set -eu

echo "=== Remove legacy CRM/POS/console (keep Fratelanza Hub) ==="

# --- Old Python CRM at /opt/fratelanza-crm ---
if [ -d /opt/fratelanza-crm ]; then
  echo "--- Stopping /opt/fratelanza-crm ---"
  (
    cd /opt/fratelanza-crm
    docker compose down -v --remove-orphans 2>/dev/null || docker-compose down -v --remove-orphans 2>/dev/null || true
  )
  echo "Legacy stack stopped. To delete files: sudo rm -rf /opt/fratelanza-crm"
fi

# --- Stale nginx site configs (NOT the main fratelanza Hub config) ---
LEGACY_NGINX_SITES=(
  crm
  pos
  hub
  fratelanza-console
  fratelanza-corporate
  fratelanza-crm
  pharmapos
)
echo "--- Disabling legacy nginx sites ---"
for site in "${LEGACY_NGINX_SITES[@]}"; do
  if [ -e "/etc/nginx/sites-enabled/$site" ] || [ -L "/etc/nginx/sites-enabled/$site" ]; then
    sudo rm -f "/etc/nginx/sites-enabled/$site"
    echo "  removed sites-enabled/$site"
  fi
done

# Ensure the Hub wildcard config is the only Fratelanza proxy
HUB_NGINX="/etc/nginx/sites-enabled/fratelanza"
if [ ! -e "$HUB_NGINX" ] && [ -f "$HOME/Fratelanza-HUB/deploy/nginx.conf" ]; then
  echo "--- Installing Hub nginx config (missing) ---"
  sudo cp "$HOME/Fratelanza-HUB/deploy/nginx.conf" /etc/nginx/sites-available/fratelanza
  sudo ln -sf /etc/nginx/sites-available/fratelanza /etc/nginx/sites-enabled/fratelanza
fi

if command -v nginx >/dev/null 2>&1; then
  if sudo nginx -t 2>/dev/null; then
    sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null || true
    echo "Nginx reloaded."
  else
    echo "WARNING: nginx -t failed — run: sudo nginx -t"
  fi
fi

# --- Orphan containers on old ports ---
echo "--- Removing orphan containers ---"
docker ps -a --format '{{.Names}}' | grep -iE 'fratelanza-crm|pharmapos|fratelanza-console' | while read -r name; do
  [ -n "$name" ] && docker rm -f "$name" 2>/dev/null && echo "  removed container $name"
done

echo
echo "=== Legacy CRM cleanup done ==="
echo
echo "Hub stack (~/Fratelanza-HUB) was NOT stopped."
echo
echo "DNS (Cloudflare) — delete these A records if they exist:"
echo "  crm, pos, console, crm.fratelanza.com"
echo
echo "Keep:"
echo "  fratelanza.com, *.fratelanza.com (wildcard), admin.fratelanza.com"
echo "  (optional explicit) hub → $(
  curl -4 -s ifconfig.me 2>/dev/null || echo 'YOUR_VPS_IP'
)"
echo
echo "Admin: create ONE customer with subdomain 'hub' and enable:"
echo "  • General workspace (all general + HR features)"
echo "  • Medical — core modules + smart tools"
echo
echo "Then open: https://hub.fratelanza.com"
