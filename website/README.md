# IELTS AI by nextED — website

Next.js (App Router, TypeScript). It uses the **same API server and database
as the app** (`../server`): same accounts, progress, Pro status and free
limits. Content comes from the same **content packs** the app downloads
(`src/lib/server/packs.ts`), so each web screen reads exactly the data its
app screen reads.

## Run it (Windows)

```
cd website
copy .env.example .env.local      (then set API_BASE_URL)
npm install
npm run sync-assets               (copies Nexi, the logo and the module videos from ../assets)
npm run dev                       → http://localhost:3000
```

Checks: `npm run typecheck` · `npm run build`.

## How it fits together

- The browser only talks to this site. Pages call the API **on the server**
  (`src/lib/server/api.ts`); client components use the same-origin door
  `/api/v1/...` (`src/app/api/v1/[...path]/route.ts`).
- Tokens live in **httpOnly cookies** (`src/lib/session.ts`): page scripts
  can't read them. `src/middleware.ts` gives each browser a device id, renews
  the access token before it expires and protects `/app/*`.
- API keys (AI, SMS, bKash, storage) stay on the API server. This site only
  knows `API_BASE_URL`, `APP_KEY` and `SITE_URL`, all server-only.
- Look and feel: `src/app/globals.css` holds the app's Day / Night tokens
  (`lib/app/theme/tokens.dart`); `src/components/ui.tsx` is the app's kit
  (cards, hero card, peach buttons, Nexi). Font: Outfit. Icons: Material Symbols.

## What's built

| Area | Status |
|---|---|
| Landing page, Terms, Privacy, sitemap | Done (prices and legal text from the content pack) |
| Log in, Sign up (SMS code), Forgot password | Done |
| Session, device id, one-screen rule notices | Done |
| Signed-in shell: Home, Practice, Mock tests, Community chat, Profile tabs | Done |
| Home (greeting, Dive Right In, word of the day), Practice (module video cards) | Done |
| Profile: devices (remove), Day / Night, log out | Done |
| Writing, Speaking, Listening, Reading, Resources, Courses, Mocks, Study plan, Upgrade | Next phases: each screen is ported from its app screen |

Screens not on the web yet show a clear "coming to the website soon" card.

## Deploy (Coolify)

New resource from the same repository → Dockerfile build, **Base Directory
`/website`**, port 3000. Environment: `API_BASE_URL=https://mobile-api.nexted.app`,
`APP_KEY` (if used), `SITE_URL` (the site's https address).
