#!/bin/sh
# Container start: apply database migrations, optionally (re)load the content
# seed, then run the API. Settings come from the container's environment
# (Coolify → Environment Variables), not from a .env file.
set -e

echo "[start] applying migrations…"
npx prisma migrate deploy

if [ "$SEED_ON_START" = "true" ]; then
  echo "[start] seeding (SEED_ON_START=true)…"
  npx prisma db seed
fi

echo "[start] starting API on ${HOST:-0.0.0.0}:${PORT:-4000}"
exec npx tsx src/index.ts
