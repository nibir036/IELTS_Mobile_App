# nextED AI — three features, one service

AI Counsellor, Course Finding and Scholarship Finding, behind one FastAPI
service with LangGraph and LangSmith.

**77 tests, all passing, with no API key and no network.**

```bash
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
cp .env.example .env               # Windows: copy .env.example .env

pytest -q                          # or: python tests/run.py
uvicorn app.main:app --reload      # then http://127.0.0.1:8000/docs
```

It starts and answers with nothing configured. `LLM_PROVIDER=echo` needs no
key, and with no search provider the finders answer from what is stored.

---

## Three ways to test

### 1. The automated suite — proves the rules

```bash
pytest -q                 # or: python tests/run.py   (no pytest needed)
```

111 tests. No key, no network, no database. This is what tells you the
verdicts, restrictions, freshness and evidence checks are all correct.

If a run fails with an `AttributeError`, a `TypeError` on a call that
should work, or an import that cannot resolve, check for a stale file
before reading the traceback — one file being older than the rest is by
far the most common cause, and it looks like a code bug:

```bash
python verify.py
```

It compares every file against the version the rest of the project was
written against and names the ones that differ. Line endings are
normalised, so a file saved on Windows still matches. Your `.env`,
`data/` and real restrictions list are never checked.

### 2. `try.py` — run the three features by hand, no server

```bash
python try.py --list                      # the example students
python try.py --demo                      # all three, offline, with a fake web
python try.py --demo courses "msc artificial intelligence"
python try.py --demo scholarships "masters funding"
python try.py --demo counsellor "should I apply this year?"
python try.py --demo --student borderline        # a 6.5 / 3.2 student
```

`--demo` fakes **only** the web (from `examples/pages/`) and the model.
The fetch gate's rules, the extractor, the evidence check, the verdicts,
the sorting and the write-back are all the real code. It is the quickest
way to see the whole research path work with nothing configured.

Run it twice and watch `stored:` go from 0 to 1 — that is the write-back,
which is how the catalogue fills itself.

Without `--demo` it uses whatever your `.env` says. Once you set
`LLM_PROVIDER=groq` and a `WEB_SEARCH_PROVIDER`, the same commands hit the
real web and the real model.

### 3. The HTTP API — what Node will actually call

```bash
uvicorn app.main:app --reload
```

Then open <http://127.0.0.1:8000/docs> and use **Try it out**, or:

```bash
# is it alive, and what is switched on?
curl http://127.0.0.1:8000/health

# scholarships
curl -X POST http://127.0.0.1:8000/v1/ai/scholarships \
  -H "Content-Type: application/json" \
  -d '{"studentId":"s1","query":"masters scholarship",
       "profile":{"nationality":"Bangladesh","highestLevel":"Bachelors",
                  "result":"3.2","ieltsBand":"6.5",
                  "preferredCountry":"United Kingdom"}}'

# courses
curl -X POST http://127.0.0.1:8000/v1/ai/courses \
  -H "Content-Type: application/json" \
  -d '{"studentId":"s1","query":"msc artificial intelligence",
       "profile":{"highestLevel":"Bachelors","ieltsBand":"6.5",
                  "preferredCountry":"United Kingdom","subject":"Computer Science"}}'

# counsellor
curl -X POST http://127.0.0.1:8000/v1/ai/counsellor \
  -H "Content-Type: application/json" \
  -d '{"studentId":"s1","message":"How much is your file opening fee?",
       "profile":{"preferredCountry":"United Kingdom"}}'

# how many searches has this student used today?
curl "http://127.0.0.1:8000/v1/ai/usage?studentId=s1"
```

To try the API with scripted replies and no key, set `LLM_PROVIDER=demo`
in `.env`. (The web still needs a real search provider in this mode —
`--demo` on `try.py` is the fully offline one.)

Things worth trying, because they show the design working:

| Try this | What you should see |
|---|---|
| Ask the counsellor about the file-opening fee | The approved text word for word, and `usage` does **not** go up |
| `--demo courses "business"` | The course appears, but with **no IELTS figure** — the page never stated one, so the claim was dropped |
| `--demo --student thin scholarships` | `Borderline`, not `Not eligible`, plus which field to fill |
| `--demo --student borderline scholarships` | A gap: "IELTS 6.5 to 7 would unlock 1 more" |
| Run any finder 31 times for one student | `429 ai_limit_reached` |

---

## The one rule everything follows

> **The AI explains the decision. It does not make it.**

| Decision | Made by |
|---|---|
| Is this university closed for this student? | `core/restrictions.py` — Python, exact match |
| Eligible, Borderline or Not eligible? | `core/eligibility.py` — Python, arithmetic |
| Is this fact backed by the page it claims? | `core/evidence.py` — Python |
| Is what we saved still true? | `core/freshness.py` — Python |
| Has today's allowance gone? | `store/json_store.py` — Python |
| What is the student actually asking for? | the model |
| Which searches would find it? | the model |
| Rough order of 40 candidates | the model (ids constrained to those 40) |
| How to say it in good English | the model |

Anything a wrong answer would cost a student a year on is decided in code,
and re-checked in code after the model replies.

---

## How a finder request runs

```
load profile  →  understand the ask (model → constraints)
              →  search what we hold
              →  enough?  ── yes ──→  merge
                    │ no
                    └─→  plan searches (model)
                         fetch official pages (through the gate)
                         extract + prove each field
                         write back to the catalogue
              →  merge
              →  DECIDE IN CODE  (eligibility / restrictions)
              →  spend one credit  →  rank or phrase (model)
              →  drop any id we did not send
              →  sort, tier, label each row's source
```

Everything found on the web is written back, so the next student asking
something similar gets an instant answer. **The catalogue fills itself by
being used.**

---

## What is in here

```
app/
  core/            no model, no network, no framework — every rule lives here
    restrictions.py eligibility.py freshness.py evidence.py
    gaps.py search.py policy.py profile.py budget.py numbers.py
  tools/           the only code that reaches outside
    fetch.py       the gate: allowlist, SSRF, robots, timeouts, redirects
    search_web.py  tavily / brave / serper, and a fake one for tests
    extract.py     page → fields, each with the sentence that proves it
  graphs/
    runner.py      runs on LangGraph, or without it
    nodes.py       the shared steps
    counsellor.py courses.py scholarships.py
  providers/       groq, gemini, echo
  store/           json files now, PostgreSQL later
  api/             the three features, callable without FastAPI
  main.py          the FastAPI app
examples/
  restrictions.sample.json   ← replace with your real list
  students/  pages/
tests/
```

### Endpoints

| Method | Path |
|---|---|
| GET | `/health` |
| GET | `/v1/ai/usage?studentId=…` |
| POST | `/v1/ai/counsellor` |
| POST | `/v1/ai/courses` |
| POST | `/v1/ai/scholarships` |

Each POST takes `{ studentId, profile, query }` (the counsellor takes
`message` and `history` instead). **The profile travels in the request** —
this service never queries your student tables and holds no session. Node
vouches for the student and sends their profile across, which is also why
demo mode needs no separate code path.

```bash
curl -X POST http://127.0.0.1:8000/v1/ai/scholarships \
  -H "Content-Type: application/json" \
  -d '{"studentId":"s1","query":"masters scholarship",
       "profile":{"nationality":"Bangladesh","highestLevel":"Bachelors",
                  "result":"3.2","ieltsBand":"6.5",
                  "preferredCountry":"United Kingdom"}}'
```

---

## Why LangGraph and LangSmith are optional imports

They are in `requirements.txt` and the graphs use them when present. But
`graphs/runner.py` can also run the same nodes itself, which means the
service starts if an install fails, the tests need no LangChain stack, and
a breaking change upstream cannot take the decision layer down. Nodes are
plain async functions either way — nothing in `core/` knows either library
exists.

LangSmith is **off unless `LANGSMITH_TRACING=true` and a key is set**.
Profiles are redacted before anything is sent. Turn it on when you need to
see which tier answered, what the research loop fetched and what the
extractor threw away.

---

## Keeping the cost down

One request costs this many model calls, measured:

| Situation | Calls | Which |
|---|---|---|
| Cold — nothing stored, goes and reads a page | 4 | understand, plan, extract, rank |
| Warm — enough stored, with a typed query | 2 | understand, rank |
| Warm — browsing from the profile, no query | 1 | rank |
| Counsellor, fee or document question | **0** | fixed text from config |

Three of those four are small jobs and go to `FAST_MODEL`. Only the final
rank or phrase uses the main model.

**What already saves money, built in:**

- **Write-back.** Every fact found on the web becomes a stored row, so the
  next student asking something similar takes the 2-call path. The
  expensive request pays for itself.
- **Unchanged pages cost nothing.** Before extracting, the page's content
  hash is compared with what we stored. If it has not moved there is no
  model call at all — just a clock reset. Most re-reads land here.
- **A cheap model reads the pages.** Safe precisely because of the evidence
  check: a weaker model that invents a requirement has the claim dropped,
  not shipped.
- **Irrelevant pages are never sent to a model.** A page with no mention of
  requirements, fees or deadlines is filtered out in code first.
- **Only ~6,000 characters of each page** are sent, chosen by keyword, not
  the whole thing.
- **Fixed replies skip the model entirely** and spend no credit.

**What you can turn down if the bill still bites:**

| Setting | Effect |
|---|---|
| `MAX_FETCHES=2` | Halves the worst case. Each page is one model call. |
| `MAX_SEARCHES=1` | One search per request. |
| `FAST_MODEL=` *(set it!)* | The single biggest lever. Unset means the big model does everything. |
| `NEXTED_AI_DAILY_LIMIT=15` | Fewer requests per student per day. |
| `RESEARCH_ENABLED=false` | No web at all. Answers only from storage — free, but it stops learning. |

**The number to watch:** how often requests take the cold path versus the
warm one. `budget_summary` in the response carries `searches`, `pages` and
`unchanged_pages`. If the cold share is not falling week by week, the
write-back is not working and that is the thing to fix — not the model.

---

## Two bugs this found in the existing build

**1. `num()` could not read "3.2 / 4.0".** The TypeScript version strips
everything except digits and dots, so that becomes `"3.24.0"` and fails to
parse at all. The Python one takes the first number and returns `3.2`. If
students enter results that way, that bug is live right now.

**2. Every Bachelors graduate was marked Borderline for a Masters award.**
`profile.highestLevel` is what the student has *completed*; a scholarship's
`level` is what they would *study*. Comparing the two strings marks the
most common applicant in the whole product as a near miss. `level_fits()`
now understands the ladder: the award's level may be at or one rung above
what the student holds.

A third was caught while writing tests here: `flag_closed` flagged
"Example University" when the reply recommended "Example University **of
Technology**" — telling a student a door was shut when it was not. It now
matches whole names, longest first.

---

## The one file that has to come from you

`examples/restrictions.sample.json` holds **four invented rules** so the
tests have something to run against.

Your 47 real rules are the only data in this project that cannot be found
on the internet — universities do not publish which of them are closed to
Bangladeshi students through NextED's partner arrangements. Point
`RESTRICTIONS_FILE` at your export; the loader takes your `camelCase`
column names as they are.

Until then, restriction checking is simply off and everything else works.
The file is in `.gitignore`.

---

## Before going live

1. **`SERVICE_TOKEN`** must be set. The service refuses to run unprotected
   in production.
2. **Keep it off the internet.** Only the Node API should reach it.
3. **Set a search provider** (Tavily, Brave or Serper) to switch research on.
4. **Keep `ALLOWED_DOMAINS` tight.** `ac.uk` plus a few funders covers the
   UK and gives an attacker almost nothing to aim at.
5. **Move the store to PostgreSQL.** `store/json_store.py` is a single class
   behind one interface; the JSON files are fine for development and for a
   pilot, not for several processes at once.
6. **Watch the fast-path ratio.** How often a request is answered from the
   catalogue versus going out to the web is the clearest measure of whether
   the system is actually learning.#   N e x t e d - a i  
 #   N e x t e d - a i  
 #   N e x t e d - a i  
 