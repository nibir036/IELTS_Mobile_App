# Deploying the nextED AI service (Coolify)

The AI service runs as its **own Coolify app**, built from this repo, next to
the API server. It has **no domain**: only the API calls it, over Coolify's
internal network. If it is down, Study abroad falls back to the built-in
Gemini versions, and IELTS is not affected at all.

## 1. Create the app

- **New resource → Application → this Git repo**, branch `main`.
- **Build pack:** Dockerfile. **Base directory:** `/ai`. **Dockerfile:** `Dockerfile`.
- **Domain:** leave empty. **Port:** `8000`.
- **Persistent storage:** add a volume mounted at `/app/data`
  (catalogue it has learned, usage counts, and the real restriction list).
- Same server as the API, on Coolify's shared network, so the API can reach it.

## 2. Environment variables (AI app)

| Name | Value |
|---|---|
| `SERVICE_TOKEN` | a long random password (`python -c "import secrets; print(secrets.token_urlsafe(32))"`). Required - the service will not start without it. |
| `LLM_PROVIDER` | `gemini` or `groq` |
| `GEMINI_API_KEY` + `GEMINI_WRITING_MODEL` (or `GROQ_API_KEY` + `GROQ_MODEL`) | the model |
| `FAST_MODEL` | the cheapest small model of that provider (biggest cost saver) |
| `WEB_SEARCH_PROVIDER` + `WEB_SEARCH_API_KEY` | `tavily`, `brave` or `serper` (switches web research on) |
| `ALLOWED_DOMAINS` | keep tight, e.g. `ac.uk,chevening.org,britishcouncil.org,gov.uk` |
| `DATABASE_URL` *(optional)* | the same PostgreSQL URL as the API, for the knowledge base. Its tables go in their own schema (`KB_SCHEMA`, default `nexted_ai`), never Prisma's `public`. Vectors need the pgvector add-on; without it set `EMBEDDINGS_PROVIDER=none`. Leave empty to run on the JSON files in the volume. |

Everything else has a sensible default - see `.env.example`.

## 3. Point the API at it (API app)

| Name | Value |
|---|---|
| `NEXTED_AI_URL` | the AI app's internal address, `http://<ai container name>:8000` (Coolify shows the container name in the app's settings) |
| `NEXTED_AI_TOKEN` | the same value as `SERVICE_TOKEN` above |

Redeploy the API. Its `/health` then shows `nextedAi` as up.

## 4. The real restriction list

Put NextED's list in the volume as `/app/data/restrictions.json`
(same format as `examples/restrictions.sample.json`) and restart the AI app.
Until it is there, restriction checking in this service is off.

## Running it on your computer

Double-click `ai\RUN_AI.bat` (or `tool\RUN_DEMO.bat`, which starts it too).
It listens on http://127.0.0.1:8000 - `/docs` to try it.
