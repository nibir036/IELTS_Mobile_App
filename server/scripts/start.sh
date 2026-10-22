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

# Content packs: always, cheap when nothing changed. A failure keeps the
# packs already in the database.
echo "[start] loading content packs…"
npx tsx scripts/load-packs.ts || echo "[start] content packs not updated (see error above)"

# Shared Pro demo accounts "Demo 1" … "Demo 4" (scripts/demo-accounts.ts).
npx tsx scripts/demo-accounts.ts || echo "[start] demo accounts not updated (see error above)"

# nexted.app (study abroad): starter courses + scholarships, only while the
# catalogue is empty. Its tables come from the nexted_module migration above.
npx tsx scripts/nexted-catalogue.ts --if-empty || echo "[start] nexted catalogue not loaded (see error above)"

# UK study-destination restrictions (NextED partner list, scripts/nexted-restrictions.ts).
# Upserted by stable id, so a revised list in that file updates in place.
npx tsx scripts/nexted-restrictions.ts || echo "[start] nexted restrictions not updated (see error above)"

echo "[start] starting API on ${HOST:-0.0.0.0}:${PORT:-4000}"
exec npx tsx src/index.ts
