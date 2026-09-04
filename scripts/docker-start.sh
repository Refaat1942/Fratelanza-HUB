#!/bin/sh
set -eu

# Production containers should not run interactive schema pushes on boot.
# Apply tenant migrations explicitly via deploy/migrate-tenants.sh instead.
if [ "${SKIP_DB_PUSH:-1}" = "0" ]; then
  pnpm --filter @workspace/db run push
fi

exec node --enable-source-maps ./artifacts/api-server/dist/index.mjs
