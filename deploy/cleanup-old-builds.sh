#!/usr/bin/env bash
# Safe cleanup of old Docker BUILDS on the Fratelanza VPS.
# Does NOT touch: running containers, named volumes (postgres_data, admin_db_data),
# uploads/, .env, or SSL certs.
#
# Usage:
#   ./deploy/cleanup-old-builds.sh          # dry-run (shows what would be freed)
#   ./deploy/cleanup-old-builds.sh --apply  # actually delete

set -euo pipefail

APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
fi

echo "=== Docker disk usage (before) ==="
docker system df
echo ""

echo "=== Running stack (will NOT be stopped) ==="
docker compose ps 2>/dev/null || docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
echo ""

prune() {
  local label="$1"
  shift
  echo "--- $label ---"
  if $APPLY; then
    "$@"
    echo "Done."
  else
    echo "[dry-run] would run: $*"
    # builder prune supports --dry-run in newer docker; image prune does not
    if [[ "$1" == "docker" && "$2" == "builder" ]]; then
      docker builder prune --dry-run "${@:3}" 2>/dev/null || true
    fi
  fi
  echo ""
}

if ! $APPLY; then
  echo ">>> DRY RUN — nothing deleted. Pass --apply to clean up. <<<"
  echo ""
fi

# 1. Build cache from repeated `docker compose up --build` (biggest win, zero risk)
prune "Build cache (old layers from docker compose build)" \
  docker builder prune -f --filter until=168h

# 2. Dangling images (<none> tags) — intermediate build leftovers
prune "Dangling images (untagged build leftovers)" \
  docker image prune -f

# 3. Unused images older than 7 days — NOT used by any container (running stack kept)
prune "Unused images older than 7 days (current app/admin images stay if in use)" \
  docker image prune -a -f --filter until=168h

# 4. Stopped containers only (not running ones) — usually none on this stack
prune "Stopped containers" \
  docker container prune -f --filter until=168h

echo "=== NEVER run on this VPS (would break production) ==="
echo "  docker volume prune          # deletes postgres_data, admin_db_data"
echo "  docker system prune -a --volumes"
echo "  docker compose down -v"
echo ""

if $APPLY; then
  echo "=== Docker disk usage (after) ==="
  docker system df
  echo ""
  echo "Cleanup complete. Running services unchanged."
  docker compose ps 2>/dev/null || true
else
  echo "To apply:  cd ~/Fratelanza-HUB && ./deploy/cleanup-old-builds.sh --apply"
fi
