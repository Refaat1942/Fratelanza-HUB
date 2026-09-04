#!/bin/bash
# Tear down Fratelanza Hub / CRM on this VPS for a clean redeploy.
#
# Usage (on the VPS):
#   cd ~/Fratelanza-HUB
#   chmod +x deploy/teardown.sh
#   ./deploy/teardown.sh              # stop containers, disable nginx, keep DB data
#   ./deploy/teardown.sh --purge      # also delete Docker volumes + uploads
#   ./deploy/teardown.sh --purge-all  # purge + remove ~/Fratelanza-HUB checkout
#
set -eu

PURGE=0
PURGE_ALL=0

for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    --purge-all) PURGE=1; PURGE_ALL=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)"
      exit 1
      ;;
  esac
done

HUB_DIR="${HUB_DIR:-$HOME/Fratelanza-HUB}"
LEGACY_CRM_DIR="/opt/fratelanza-crm"

echo "=== Fratelanza VPS teardown ==="
echo "Hub directory: $HUB_DIR"
echo "Purge data:    $([ "$PURGE" -eq 1 ] && echo yes || echo no)"
echo

stop_compose_in() {
  local dir="$1"
  local label="$2"
  if [ ! -d "$dir" ]; then
    echo "Skip $label — directory not found: $dir"
    return 0
  fi
  if [ ! -f "$dir/docker-compose.yml" ] && [ ! -f "$dir/docker-compose.yaml" ]; then
    echo "Skip $label — no docker-compose file in $dir"
    return 0
  fi
  echo "--- Stopping $label ($dir) ---"
  (
    cd "$dir"
    if [ "$PURGE" -eq 1 ]; then
      docker compose down -v --remove-orphans 2>/dev/null || docker-compose down -v --remove-orphans 2>/dev/null || true
    else
      docker compose down --remove-orphans 2>/dev/null || docker-compose down --remove-orphans 2>/dev/null || true
    fi
  )
}

stop_compose_in "$HUB_DIR" "Fratelanza-HUB"
stop_compose_in "$LEGACY_CRM_DIR" "legacy /opt/fratelanza-crm"

echo "--- Removing stray Fratelanza containers (if any) ---"
docker ps -a --format '{{.Names}}' | grep -E 'fratelanza|Fratelanza' | while read -r name; do
  [ -n "$name" ] && docker rm -f "$name" 2>/dev/null || true
done

if [ -d "$HUB_DIR" ]; then
  echo "--- Removing local overrides ---"
  rm -f "$HUB_DIR/docker-compose.override.yml"
fi

if [ "$PURGE" -eq 1 ] && [ -d "$HUB_DIR/uploads" ]; then
  echo "--- Removing uploaded files ---"
  rm -rf "$HUB_DIR/uploads"
fi

echo "--- Disabling nginx site configs ---"
NGINX_SITES=(
  fratelanza
  fratelanza-hub
  fratelanza-console
  fratelanza-corporate
  pharmapos
  pos
  crm
  hub
)
for site in "${NGINX_SITES[@]}"; do
  sudo rm -f "/etc/nginx/sites-enabled/$site" 2>/dev/null || true
done

if command -v nginx >/dev/null 2>&1; then
  if sudo nginx -t 2>/dev/null; then
    sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null || true
    echo "Nginx reloaded (no Fratelanza sites enabled)."
  else
    echo "WARNING: nginx -t failed — fix /etc/nginx manually before reloading."
  fi
fi

echo
echo "=== Teardown complete ==="
echo "Kept: SSL certs in /etc/letsencrypt (safe to reuse on redeploy)."
echo "Kept: DNS records (unchanged)."
if [ "$PURGE" -eq 0 ]; then
  echo "Kept: Docker volumes (tenant DBs) — rerun with --purge to delete all data."
fi

if [ "$PURGE_ALL" -eq 1 ]; then
  echo
  read -r -p "Delete checkout $HUB_DIR? Type 'yes' to confirm: " confirm
  if [ "$confirm" = "yes" ]; then
    rm -rf "$HUB_DIR"
    echo "Removed $HUB_DIR"
  else
    echo "Skipped removing $HUB_DIR"
  fi
fi

echo
echo "Redeploy later:"
echo "  git clone https://github.com/Refaat1942/Fratelanza-CRM.git ~/Fratelanza-HUB"
echo "  cd ~/Fratelanza-HUB && cp .env.example .env && nano .env"
echo "  ./deploy/validate-env.sh .env"
echo "  sudo cp deploy/nginx.conf /etc/nginx/sites-available/fratelanza"
echo "  sudo ln -sf /etc/nginx/sites-available/fratelanza /etc/nginx/sites-enabled/fratelanza"
echo "  sudo nginx -t && sudo systemctl reload nginx"
echo "  docker compose up -d --build"
