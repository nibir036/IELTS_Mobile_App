# IELTS AI API (Cloudflare Worker)

Server side for the app's AI features. Holds the OpenRouter key and the R2
bucket so neither ships inside the app.

| Endpoint | What it does |
|---|---|
| `POST /v1/writing/evaluate` | Band + TA/CC/LR/GRA, summary, feedback, line-level issues |
| `POST /v1/writing/rewrite` | Band-8 rewrite of the student's essay + list of changes |
| `POST /v1/speaking/transcribe` | Verbatim transcript of a recording (base64 or R2 key) |
| `POST /v1/speaking/evaluate` | Band + FC/LR/GRA/P from transcript and speaking time |
| `POST /v1/pronunciation/score` | 0–100 score for one word + tip |
| `POST /v1/chat/partner` | AI speaking partner for community rooms: `{history[{role: partner\|student, content}], topic?, questions[]?}` → `{feedback, suggestion, question}` (short feedback on the last answer + one Part 3 follow-up) |
| `PUT /v1/uploads?ext=wav` / `GET /v1/uploads/<key>` | Store / stream recordings in R2 |
| `POST /v1/otp/send`, `/v1/otp/verify` | SMS stub (demo code 123456 until an SMS provider is added) |

## Setup

```
cd backend
npm install
npx wrangler login
npx wrangler secret put OPENROUTER_API_KEY
npx wrangler secret put APP_KEY            # any long random string
# edit wrangler.toml: bucket_name = your R2 bucket, models if you like
npm run deploy                             # prints https://ielts-ai-api.<you>.workers.dev
npm test                                   # offline smoke test (mocks OpenRouter + R2)
```

## Point the app at it

```
flutter run --dart-define=API_BASE_URL=https://ielts-ai-api.<you>.workers.dev --dart-define=APP_KEY=<same key>
```

Without `API_BASE_URL` the app uses its built-in demo scorer, so it keeps
working offline. `APP_KEY` is a shared key for the demo phase only — the
database phase replaces it with real per-user sessions.
