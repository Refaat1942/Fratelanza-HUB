#!/bin/bash
# Quick preflight for ~/Fratelanza-HUB/.env before docker compose up.
set -eu

ENV_FILE="${1:-.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE — copy from .env.example first."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

fail=0

require_min_len() {
  local name="$1"
  local value="${!name:-}"
  local min="$2"
  if [ -z "$value" ] || [ "${#value}" -lt "$min" ] || [[ "$value" == CHANGE_ME* ]]; then
    echo "FAIL  $name (need ${min}+ chars, not CHANGE_ME*)"
    fail=1
  else
    echo "OK    $name (${#value} chars)"
  fi
}

require_url_safe() {
  local name="$1"
  local value="${!name:-}"
  if [ -z "$value" ] || [[ "$value" == CHANGE_ME* ]] || [[ "$value" =~ [@:/?#%&[:space:]] ]]; then
    echo "FAIL  $name (URL-safe alnum/_/- only, not CHANGE_ME*)"
    fail=1
  else
    echo "OK    $name"
  fi
}

echo "Checking $ENV_FILE ..."
require_url_safe POSTGRES_PASSWORD
require_min_len SESSION_SECRET 32
require_url_safe ADMIN_DB_PASSWORD
require_min_len ADMIN_SESSION_SECRET 32
require_min_len ADMIN_PASSWORD 10
require_min_len ADMIN_API_KEY 32
require_min_len TENANT_DEFAULT_ADMIN_PASSWORD 8

if [ "$fail" -ne 0 ]; then
  echo
  echo "Fix the FAIL lines, then: docker compose up -d --force-recreate"
  echo "Generate secrets: openssl rand -hex 24"
  exit 1
fi

echo
echo "All required values look good."
