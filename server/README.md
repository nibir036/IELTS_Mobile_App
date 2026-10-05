# IELTS AI server — API + PostgreSQL

API server for the IELTS AI by nextED Flutter app (Node 20+, TypeScript run
with tsx, no framework) and its PostgreSQL 18 database (Prisma 6).
All keys stay here on the server; the app only ever sees its own login tokens.

## Run the API (Windows)

Double-click `tool\run_server.bat`. It installs packages, adds any missing
settings to `server\.env` (and generates `AUTH_SECRET`), applies migrations
and starts the server on http://localhost:4000 (check `/health`).
From a phone on the same Wi-Fi use `http://<your PC's IP>:4000`.

Settings to fill in `server\.env` (see `.env.example`):

| Setting | For |
|---|---|
| `SMS_PROVIDER=alpha` + `ALPHA_SMS_API_KEY` | Real OTP SMS. With `console` the code is printed in the server window and returned to the app as `devCode`. |
| `GEMINI_API_KEY` | Writing grading + rewrite with Gemini (`GEMINI_WRITING_MODEL`, default `gemini-3.6-flash`) — same examiner prompt as the website |
| `PLAN_AI`, `GEMINI_PLAN_MODEL` | Study plan AI (weekly note + why-lines per task, uses the Gemini key): `all` (default), `pro` (paid only) or `off` (rules only). Optional separate model; empty = the writing model |
| `PLAN_HOURS_PER_HALF_BAND` | Study plan estimate: hours of study per half band with all four modules (default 50) |
| `OPENROUTER_API_KEY` | Speaking-partner chat; writing grading only when no Gemini key is set (or `WRITING_PROVIDER=openrouter`) |
| `SPEAKING_API_BASE_URL`, `SPEAKING_API_KEY` | The NextED_IELTS_Speaking service (Groq Whisper + RunPod + Groq LLM, same as the website); the key = its `INTERNAL_API_KEY` |
| `R2_*` | Recordings, profile photos, voice messages (optional while testing) |

## API (all JSON; `Authorization: Bearer <accessToken>` except auth/config/content)

| Area | Routes |
|---|---|
| Auth | `POST /v1/auth/otp/send` {phone, purpose: signup\|reset} · `POST /v1/auth/otp/verify` → {proof} · `POST /v1/auth/register` {name, phone, password, proof} · `POST /v1/auth/login` · `POST /v1/auth/refresh` {refreshToken} (rotates) · `POST /v1/auth/logout` · `POST /v1/auth/reset-password` {phone, password, proof} |
| Me | `GET/PATCH/DELETE /v1/me` · `POST /v1/me/password` · `GET /v1/me/usage` |
| Content | `GET /v1/content` (manifest) · `/v1/content/bundle?collections=a,b` · `/v1/content/:collection[/:id]` · `/v1/word-of-the-day` — filters such as `?source=bank`, `?kind=full`, `?test=wt_01`; new collections `writing-tests`, `speaking-tests`, `documents` (`?kind=guide\|meta\|list\|glossary\|l10n`) |
| Sync | `GET /v1/sync?since=<iso>` · `POST /v1/sync` {attempts, state, tasks} |
| Progress | `/v1/attempts`, `/v1/state[/:key]`, `/v1/notifications`, `/v1/tasks/:id` |
| Writing AI | `POST /v1/writing/evaluate` {task, prompt\|promptId, text} or {task1, task2} · `POST /v1/writing/rewrite` |
| Speaking AI | `POST /v1/speaking/sessions` {mode, segments[{id, partNumber, label, questionText, audioBase64, format}]} → poll `GET /v1/speaking/sessions/:attemptId` |
| Partner | `POST /v1/chat/partner` {history, topic?, questions?} |
| Files | `PUT /v1/uploads?kind=recording\|voice\|photo&ext=` · `GET /v1/uploads/<key>` (signed URL) · `/v1/recordings` · `/v1/rooms[/:id/messages]` |
| Public | `GET /v1/config` · `GET /v1/legal/:id` · `GET /health` |

Errors: `{error, code}` with codes such as `unauthorized`, `quota_reached`
(free plan: 4 AI-graded writing and 4 speaking tests), `rate_limited`, `ai_busy`.

## First-time setup (Windows)

Double-click `tool\setup_db.bat`, or run it from a terminal. It will:

1. create `server\.env` from `.env.example` and open it — put your `postgres`
   password (and port, if not 5432) in `DATABASE_URL`;
2. `npm install`;
3. `npx prisma migrate dev --name init` — creates the `ielts_ai` database and all tables;
4. `npx prisma db seed` — loads `seed/data/*.json` plus the demo account and
   writes the result to `tool\db_report.txt`.

### Loading new content (any time later)

Double-click `tool\seed_db.bat`. It applies new migrations without touching
existing data (`prisma migrate deploy`), refreshes the Prisma client and runs the
seed again (upserts, nothing is duplicated). Output: `tool\seed_report.txt`.
Before that, after content changes in the app: `python tool/build_seed_formats.py`
then `python tool/build_seed_banks.py`.

## Everyday commands (run inside `server/`)

| Command | What it does |
|---|---|
| `npm run db:studio` | Browse and edit the tables in the browser |
| `npm run db:seed` | Re-load seed data (upserts, safe to repeat) |
| `npm run db:migrate -- --name <change>` | After editing `schema.prisma`: create + apply a migration |
| `npm run db:status` | Which migrations have run |
| `npm run db:reset` | Drop everything, re-run all migrations and the seed (dev only) |
| `npm run db:deploy` | Apply migrations on a server (production) |
| `npm run dev` | API server, restarts on code changes |
| `npm start` | API server |
| `npm run typecheck` | TypeScript check |

## What is where

- `prisma/schema.prisma` — every table. Groups follow `seed/README.md`:
  content (reading, listening, writing, speaking, resources), config (plans,
  certificates, legal, rooms, app config) and users (accounts, sessions, OTP
  codes, attempts, notifications, tasks, saved state, recordings, room messages,
  subscriptions).
- `prisma/seed.ts` — loader. Content ids are the stable ids from `seed/data`
  (`rp_`, `rb_`, `ls_`, `t2_` …), so re-running updates rows in place.
- `src/index.ts` — server; `src/routes/*` — endpoints; `src/lib/*` — auth tokens,
  OTP + Alpha SMS, OpenRouter, writing grader, speaking-service client, R2.
- `src/lib/password.ts` — password hashing (Node's built-in scrypt).

Notes

- Reading library passages (01), question-bank sets (27) and full-test passages
  (53) share `reading_passages` (`source` = `library` | `bank` | `test`); Academic
  Reading Tests 1-10 (54), short practice tests (29) and the old demo tests (02)
  share `reading_tests` (`kind` = `full` | `short` | `demo`).
- Listening sets, writing prompts and speaking topics / cue cards / Part 3 sets
  have `source` = `demo` | `bank` | `test` (+ `test_id`); listening tests and mock
  tests have `kind` = `full` | `demo`. Writing Test and Speaking Test 1-10 are
  `writing_tests` / `speaking_tests`; guides, bank notes, lists and translations
  are `content_documents`.
- Rows from the banks and full tests keep the app's record in `data` (JSONB); the
  content API returns that record, so the app reads it exactly like its assets.
- Reading, listening and writing lessons share `lessons` (`skill` + `sort_order`,
  lesson body in `data`).
- Nested content (paragraphs, question groups, transcripts, charts) is JSONB.
- Audio, images and recordings stay in Cloudflare R2; tables store only the R2 key.
- Demo login after seeding: phone `1734519208`, password `Demo@1234`
  (set `SEED_DEMO=0` in `.env` to skip it).

## Media in Cloudflare R2

Listening audio and the map / writing / reading images are not bundled in the
app; they live in the R2 bucket under `ielts_app_phone_version/` (`R2_APP_PREFIX`):

```
ielts_app_phone_version/
  listening/audio/          P1-FN.mp3, ll_06.mp3 …   (assets/audio/listening)
  listening/maps/           map / plan drawings      (assets/listening/maps)
  writing/task1-images/     Task 1 charts            (assets/writing/task1 + tests)
  writing/guide-images/     writing guide figures    (assets/writing/guide)
  reading/images/           reading diagrams         (assets/diagrams/app)
  speaking/<user id>/<attempt id>/<question>.wav     students' answers (written by the API)
  users/<user id>/<kind>/…                           photos, voice messages, other uploads
```

- Upload / update content media (skips files already there): `npm run media:upload`
  (`-- --dry` to preview, `-- --force` to re-upload everything). The source files stay in
  the repo's `assets/` folders; they are just no longer listed in `pubspec.yaml`.
- The app loads them from `GET /v1/media/<folder>/<file>` (a redirect to a signed R2 link,
  so the bucket stays private) — or straight from a public bucket domain if built with
  `--dart-define=MEDIA_BASE_URL=https://<domain>/ielts_app_phone_version`.
- Flutter **web** loads images with fetch, so the bucket needs a CORS rule
  (R2 → bucket → Settings → CORS policy):
  `[{"AllowedOrigins":["*"],"AllowedMethods":["GET","HEAD"],"AllowedHeaders":["*"],"MaxAgeSeconds":86400}]`

## Deploy on Coolify (VPS)

The app gets its own PostgreSQL (separate from the website's) and the API runs
as a Docker app next to it. The database is never opened to the internet; only
the API has a public HTTPS address.

1. **Database** — Project → *+ New* → *Database* → *PostgreSQL* (16 or newer) →
   Start. Copy its **Postgres URL (internal)** (host is the container name, e.g.
   `postgresql://postgres:…@<id>:5432/postgres`). Leave *Make it publicly
   available* off.
2. **API** — same project → *+ New* → *Application* → this GitHub repo
   (`nibir036/IELTS_Mobile_App`, branch `main`) → Build pack **Dockerfile**,
   Base directory `/`, Dockerfile location `/server/Dockerfile`,
   Ports exposes `4000`. Domain e.g. `https://api.<your-domain>` (add a DNS
   A record for it pointing at the VPS; Coolify gets the HTTPS certificate).
3. **Environment variables** (API → Environment Variables):
   `DATABASE_URL` (the internal URL from step 1) · `AUTH_SECRET` (64 random
   characters) · `SEED_ON_START=true` for the first deploy · `SMS_PROVIDER`,
   `ALPHA_SMS_API_KEY` · `GEMINI_API_KEY` · `OPENROUTER_API_KEY` · `SPEAKING_API_BASE_URL`,
   `SPEAKING_API_KEY` · `R2_*` (optional at first). If the speaking service runs on the same
   Coolify server, point `SPEAKING_API_BASE_URL` at its internal URL (e.g. `http://<service-name>:8000`).
4. **Deploy.** The container applies the migrations (`prisma migrate deploy`),
   seeds when `SEED_ON_START=true` (upserts — safe to repeat) and starts the
   API. Check `https://api.<your-domain>/health`. Then set `SEED_ON_START=false`
   (or leave it true to reload content on every deploy).
5. **App** — build with the API address:
   `flutter build apk --release --dart-define=API_BASE_URL=https://api.<your-domain>`
