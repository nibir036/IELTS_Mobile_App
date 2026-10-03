# IELTS AI API server — for Coolify (or any Docker host).
# Build context = the repository root (the seed reads ../seed/data and
# ../assets/demo/parts), Dockerfile = server/Dockerfile.
FROM node:22-slim

# Prisma needs OpenSSL at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /repo/server

# Dependencies first (cached between deploys while package.json is unchanged).
COPY server/package*.json ./
RUN npm install --no-audit --no-fund

# Server code + the data the seed loads.
COPY server/ ./
COPY seed/data /repo/seed/data
COPY assets/demo/parts /repo/assets/demo/parts
RUN npx prisma generate

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=4000
EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||4000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["sh", "scripts/start.sh"]
