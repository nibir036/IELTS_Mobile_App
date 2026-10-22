"""The steps the three graphs are assembled from.

Written once, used three ways. That sharing is the main reason LangGraph is
worth having here - without it you get three similar handlers that drift
apart over six months.

Every node takes the state dict and returns a dict of updates.
"""
from __future__ import annotations

import logging
import uuid
from dataclasses import asdict
from datetime import datetime, timezone

from app.core.budget import ResearchBudget
from app.core.catalogue import Course, Scholarship
from app.core.eligibility import eligibility, level_in_text, level_to_study
from app.core.freshness import (
    Fact,
    can_state_plainly,
    diff_facts,
    must_recheck,
    touch_unchanged,
)
from app.core.numbers import normalise_text
from app.core.profile import StudentProfile
from app.core.restrictions import (
    Status,
    StudentScope,
    check_restrictions,
    restriction_facts,
)
from app.core.search import (
    course_tiers,
    first_non_empty,
    scholarship_tiers,
    search_words,
)
from app.tools.extract import extract_from_page, to_course, to_scholarship
from app.tools.fetch import host_allowed

log = logging.getLogger(__name__)

MIN_GOOD_MATCHES = 4  # below this we go and look rather than make do


# ---------------------------------------------------------------- shared
async def load_context(state: dict) -> dict:
    """Profile and rules in, scope computed. No network, no model."""
    profile: StudentProfile = state["profile"]
    return {
        "scope": StudentScope.of(profile),
        "words": search_words(state.get("query", "") or ""),
        "trace_notes": [],
    }


async def check_quota(state: dict) -> dict:
    """Spend one credit.

    Placement matters and is easy to break: this runs after the database
    work and immediately before the first model call, so a search that
    returns nothing and never reaches a model costs the student nothing.
    """
    store = state["store"]
    if state.get("kind") in ("course", "scholarship") and not state.get("candidates"):
        # Nothing relevant to show: an honest "not found" costs nothing.
        return {}
    usage = store.consume_ai(state["student_id"])
    return {"usage": usage.as_dict()}


# ------------------------------------------------------------ understand
UNDERSTAND_SCHEMA = {
    "type": "object",
    "properties": {
        "constraints": {
            "type": "object",
            "properties": {
                "country": {"type": "string"},
                "level": {"type": "string"},
                "subject": {"type": "string"},
                "max_tuition": {"type": "number"},
                "currency": {"type": "string"},
                "intake": {"type": "string"},
                "keywords": {"type": "array", "items": {"type": "string"}},
            },
        }
    },
    "required": ["constraints"],
}

_UNDERSTAND_SYSTEM = (
    "You turn a student's request into search constraints. Return only what "
    "the student's words or profile actually support - never invent a country "
    "or a budget they did not mention. Leave a field out if it is not stated. "
    "`level` means the level they want to STUDY, not the one they have "
    "finished: a student holding a Bachelors who asks about an MSc wants "
    "Masters."
)


async def understand(state: dict) -> dict:
    """Free text plus profile -> a constraint object code can apply.

    This is where the model is genuinely useful and completely safe: its
    output is a structure, and code decides what to do with it.
    """
    profile: StudentProfile = state["profile"]
    query = (state.get("query") or "").strip()

    # Start from the profile, so an empty query still searches sensibly.
    # `highest_level` is what they have FINISHED; a course search wants the
    # rung above it, or whatever level their own words name.
    spoken_level = level_in_text(query)
    # What they told us they want to enrol in beats a guess from what they
    # have finished (a Masters graduate may want a PhD - or a second Masters).
    wanted = level_in_text(profile.study_level) or profile.study_level.strip()
    constraints = {
        "country": profile.preferred_country,
        "level": spoken_level or wanted or level_to_study(profile.highest_level),
        "subject": profile.subject,
        "intake": profile.intake,
        "keywords": search_words(query),
    }

    if query:
        llm = state["llm"]
        user = (
            f"Student said: {query}\n\n"
            "Their profile:\n" + "\n".join(profile.summary_lines())
        )
        try:
            data = await llm.complete_json(
                _UNDERSTAND_SYSTEM, user, UNDERSTAND_SCHEMA,
                fast=True, label="understand",
            )
            found = data.get("constraints") or {}
            for key in ("country", "level", "subject", "intake", "currency"):
                value = str(found.get(key, "") or "").strip()
                if value:
                    constraints[key] = value
            # The student's own word outranks the model's reading of it.
            # A query saying "msc" is not a guess that needs confirming.
            if spoken_level:
                constraints["level"] = spoken_level
            elif wanted:
                constraints["level"] = wanted
            if found.get("max_tuition"):
                constraints["max_tuition"] = found["max_tuition"]
            # What they typed beats the profile: a Microbiology student who
            # searches "computer science" is looking for Computer Science.
            from app.kb.retrieve import typed_subject

            typed = typed_subject(query, constraints.get("country") or "")
            own = (profile.subject or "").strip().lower()
            if typed and (not constraints.get("subject")
                          or str(constraints["subject"]).strip().lower() == own
                          or own and own in str(constraints["subject"]).lower()):
                constraints["subject"] = typed
            extra = [str(k).lower() for k in (found.get("keywords") or []) if k]
            if extra:
                merged = list(dict.fromkeys(list(constraints["keywords"]) + extra))
                constraints["keywords"] = merged[:6]
        except Exception as exc:  # noqa: BLE001
            # A failed understanding is not fatal - the profile-derived
            # constraints above are already usable.
            log.info("understand step failed (%s); using the profile only",
                     type(exc).__name__)

    if query:
        from app.kb.retrieve import typed_subject

        typed = typed_subject(query, constraints.get("country") or "")
        if typed and (constraints.get("subject") or "").strip().lower() == (profile.subject or "").strip().lower():
            constraints["subject"] = typed

    return {"constraints": constraints}


# -------------------------------------------------------------- searching
async def search_courses_local(state: dict) -> dict:
    store = state["store"]
    constraints = state.get("constraints") or {}
    words = constraints.get("keywords") or []
    country = constraints.get("country", "")
    result = first_non_empty(
        list(store.courses.values()),
        course_tiers(words, country, state.get("query", "")),
    )
    log.info(
        "catalogue: %s stored, %s matched (tier %s)",
        len(store.courses) + len(store.scholarships),
        len(result.rows),
        result.tier or "none",
    )
    return {
        "candidates": list(result.rows),
        "search_note": result.note,
        "search_tier": result.tier,
        "store_exhausted": result.exhausted,
    }


async def search_scholarships_local(state: dict) -> dict:
    store = state["store"]
    constraints = state.get("constraints") or {}
    words = constraints.get("keywords") or []
    country = constraints.get("country", "")
    result = first_non_empty(
        list(store.scholarships.values()),
        scholarship_tiers(words, country, state.get("query", "")),
        take=30,
    )
    log.info(
        "catalogue: %s stored, %s matched (tier %s)",
        len(store.courses) + len(store.scholarships),
        len(result.rows),
        result.tier or "none",
    )
    return {
        "candidates": list(result.rows),
        "search_note": result.note,
        "search_tier": result.tier,
        "store_exhausted": result.exhausted,
    }


def needs_research(state: dict) -> bool:
    """Thin or stale enough to be worth going out for?"""
    if not state.get("research_enabled"):
        return False
    candidates = state.get("candidates") or []
    if len(candidates) < MIN_GOOD_MATCHES:
        return True
    # Rows that only turned up because nothing matched (every row of the
    # country, every row at all, or merely the nearest in meaning) are not
    # an answer - go and find real ones. This is what kept every student on
    # the same four seeded courses.
    if state.get("search_tier") in {"country", "all", "personal-thin", "nearest"}:
        return True
    # Enough rows, but is what matters about them still true?
    now = datetime.now(timezone.utc)
    for row in candidates[:MIN_GOOD_MATCHES]:
        facts = row.facts() if hasattr(row, "facts") else {}
        if any(must_recheck(f, now) for f in facts.values()):
            return True
    return False


def route_after_local_search(state: dict) -> str:
    return "" if needs_research(state) else "merge"


# --------------------------------------------------------- the research loop
PLAN_SCHEMA = {
    "type": "object",
    "properties": {
        "queries": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "site": {"type": "string"},
                },
                "required": ["query"],
            },
        }
    },
    "required": ["queries"],
}

_PLAN_SYSTEM = (
    "You plan web searches that will land on official university or funding "
    "pages. Give at most 3 searches. Write each one the way a student would "
    "type it into a search box - the name of the thing they want, nothing "
    "more. The search engine matches meaning, not keywords, so padding a "
    "query with words like 'entry requirements', 'course' or 'official' "
    "drags it towards advice articles and away from the course page. The "
    "country and the allowed sites are already applied for you, so leave "
    "them out. Never plan a search for a country the student did not ask "
    "about."
)


def _as_query_list(data) -> list[dict]:
    """Pull search queries out of whatever shape the model replied in.

    `response_format: json_object` guarantees valid JSON, not the schema
    we asked for, and the smaller the model the more it improvises: a
    bare list, a list of strings, `searches` instead of `queries`, or a
    single `query`. All of those are usable and none of them should cost
    a planning call for nothing.
    """
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        items = None
        for key in ("queries", "searches", "search_queries", "plan"):
            if isinstance(data.get(key), list):
                items = data[key]
                break
        if items is None:
            single = data.get("query") or data.get("search")
            items = [single] if isinstance(single, str) and single.strip() else []
    else:
        return []

    out: list[dict] = []
    for item in items:
        if isinstance(item, str):
            out.append({"query": item, "site": ""})
        elif isinstance(item, dict):
            text = item.get("query") or item.get("q") or item.get("search") or ""
            out.append({"query": str(text), "site": str(item.get("site", "") or "")})
    return out


async def plan_searches(state: dict) -> dict:
    constraints = state.get("constraints") or {}
    kind = state.get("kind", "course")
    llm = state["llm"]

    subject = constraints.get("subject", "")
    from app.kb.retrieve import expand  # "CSE" -> "computer science engineering"

    if subject and expand(subject) != subject.lower():
        subject = f"{subject} ({expand(subject)})"
    country = constraints.get("country", "")
    level = constraints.get("level", "")
    from app.kb.retrieve import place_text

    country = place_text(country) or country

    user = (
        f"Looking for: {kind}s\n"
        f"Country: {country or 'not stated'}\n"
        f"Level: {level or 'not stated'}\n"
        f"Subject: {subject or 'not stated'}\n"
        f"The student typed: {state.get('query', '') or '(nothing)'}"
    )

    queries: list[dict] = []
    seen: set[str] = set()

    def add(text: str, site: str = "") -> None:
        text = (text or "").strip()
        key = text.lower()
        if text and key not in seen:
            seen.add(key)
            queries.append({"query": text, "site": site.strip()})

    # The student's own words go first, unedited. They are the highest
    # signal available and they beat anything built from the profile:
    # "msc computer science" lands on course pages, while the same intent
    # rewritten as "Computer Science Masters course United Kingdom entry
    # requirements" lands on league tables and advice PDFs.
    typed = (state.get("query") or "").strip()
    if typed and level and not level_in_text(typed):
        # "Computer Science" alone finds blogs and undergraduate pages; the
        # level they want makes it a search for programmes.
        add(f"{level} {typed}")
    add(typed)

    try:
        data = await llm.complete_json(
            _PLAN_SYSTEM, user, PLAN_SCHEMA, fast=True, label="plan"
        )
        planned = _as_query_list(data)[:3]
        if not planned:
            log.info(
                "the planner returned no usable queries (keys: %s)",
                ", ".join(sorted(str(k) for k in data))
                if isinstance(data, dict) else type(data).__name__,
            )
        for item in planned:
            add(item["query"], item["site"])
    except Exception as exc:  # noqa: BLE001
        log.info("search planning failed: %s", type(exc).__name__)

    if not queries:
        # No words from the student and no plan: build the plainest query
        # the profile supports. Still no padding - the same rule applies.
        add(" ".join(b for b in (subject, level) if b))

    log.info(
        "planned %s search(es): %s",
        len(queries), [q["query"] for q in queries],
    )
    return {"planned_queries": queries}


async def research(state: dict) -> dict:
    """Search, fetch, extract, keep only what the page actually says.

    Runs on a budget. Running out is not an error: it produces an honest
    partial answer rather than a long wait or a confident guess.
    """
    budget: ResearchBudget = state["budget"]
    searcher = state["web_search"]
    fetcher = state["fetcher"]
    llm = state["llm"]
    store = state["store"]
    kind = state.get("kind", "course")
    country = (state.get("constraints") or {}).get("country", "")

    found: list = []
    sources: list[dict] = []
    changes: list[str] = []
    seen_urls: set[str] = set()
    reused = 0  # pages that had not changed, so cost nothing to re-read
    off_host = 0  # search results we are not allowed to read
    trail: list[dict] = []  # what happened to every result (shown in dev)

    # A general web search mostly returns league tables and advice sites
    # rather than university pages. Restricting the search to the hosts the
    # gate would let us read anyway makes most results usable instead of
    # most of them wasted.
    policy = getattr(fetcher, "policy", None)
    allowed = tuple(getattr(policy, "allowed_domains", ()) or ())
    funding = tuple(getattr(policy, "funding_domains", ()) or ())

    # A course is taught by a university; an award is given by a funder.
    # Searching the funders for a course spent the entire page budget on
    # scholarship listings, 403s and advice articles. The fetch gate still
    # allows every host on the list - this only aims the search.
    if kind == "course" and funding:
        targets = tuple(d for d in allowed if d not in funding) or allowed
    else:
        targets = allowed

    for plan in state.get("planned_queries") or []:
        if not budget.can_search():
            break
        if not budget.can_fetch():
            # Searching with nothing left to read it with is pure cost:
            # the provider is billed, results come back, and every one of
            # them is dropped unread.
            log.info("not searching again: %s", budget.stopped_because)
            break
        budget.spend_search()
        # The planner may name one site; otherwise offer every host the gate
        # would let us read. Narrowing to one would hide the funding bodies.
        chosen = plan.get("site")
        sites = (chosen,) if chosen else targets
        try:
            hits = await searcher.search(plan["query"], sites, limit=5)
        except Exception as exc:  # noqa: BLE001
            log.info("web search failed: %s", type(exc).__name__)
            continue
        log.info(
            "search %r in %s returned %s result(s)",
            plan["query"], ",".join(sites) or "the open web", len(hits),
        )
        trail.append({"search": plan["query"], "results": len(hits)})

        for hit in hits:
            if not budget.can_fetch():
                unread = len(hits) - hits.index(hit)
                budget.note_unread(unread)
                log.info(
                    "stopping: %s (%s page(s) read, %s result(s) left unread)",
                    budget.stopped_because, budget.fetches_used, unread,
                )
                break
            if hit.url in seen_urls:
                continue
            seen_urls.add(hit.url)

            # Check the gate before spending a fetch. A refused host that
            # still costs a slot means four league-table results exhaust
            # the budget and nothing is ever read.
            if allowed and not host_allowed(hit.url, allowed):
                off_host += 1
                log.info("not an allowed host, no budget spent: %s", hit.url)
                trail.append({"url": hit.url, "outcome": "not an allowed host"})
                continue

            if kind == "course" and _not_a_course_page(hit.url):
                trail.append({"url": hit.url, "outcome": "skipped: blog/news, not a course page"})
                continue

            budget.spend_fetch()

            page = await fetcher.get(hit.url)
            if not page.ok:
                # Never silent. A page that will not open is the single
                # most common reason a finder comes back empty, and
                # without the reason it is indistinguishable from a page
                # that opened and said nothing useful.
                log.info(
                    "could not read %s: %s",
                    hit.url, page.error or f"http {page.status}",
                )
                trail.append({"url": hit.url, "outcome": f"could not open ({page.error or page.status})"})
                continue

            # Has this page changed since we last read it? If not, there is
            # nothing to extract: restart the clocks and move on. This is the
            # cheapest path through the loop and it costs no model call.
            unchanged = store.find_by_content_hash(page.content_hash, kind)
            if unchanged is not None:
                for fact in unchanged.facts().values():
                    touch_unchanged(fact)
                found.append(unchanged)
                sources.append({"url": page.url, "title": unchanged.title})
                reused += 1
                trail.append({"url": page.url, "outcome": "unchanged, reused"})
                continue

            extraction = await extract_from_page(llm, page, kind=kind)
            if not extraction.found:
                # extract_from_page has already said why; saying "nothing
                # extractable" after "the provider was busy" reads as a
                # verdict on the page, which it is not.
                trail.append({"url": page.url, "outcome": f"no {kind} found on the page"})
                continue

            new_id = uuid.uuid4().hex[:12]
            row = (
                to_course(extraction, new_id, country)
                if kind == "course"
                else to_scholarship(extraction, new_id, country)
            )
            if row is None:
                # The last silent exit in this loop, and the one that hid
                # four read pages behind an empty answer. A row is refused
                # when the page did not yield the two things that identify
                # it, so say which one was missing.
                missing = [
                    name for name, value in (
                        ("title", extraction.title),
                        ("university" if kind == "course" else "provider",
                         extraction.university or extraction.provider),
                    ) if not value
                ]
                log.info(
                    "read %s but could not build a %s from it (no %s)",
                    page.url, kind, " or ".join(missing) or "usable facts",
                )
                trail.append({"url": page.url, "outcome": "missing " + (" or ".join(missing) or "facts")})
                continue

            # Did anything we already held just change?
            before = {}
            existing = _existing_match(store, row, kind)
            if existing is not None:
                before = existing.facts()

            saved = (
                store.upsert_course(row) if kind == "course"
                else store.upsert_scholarship(row)
            )
            if before:
                for change in diff_facts(before, saved.facts()):
                    changes.append(change.message())

            found.append(saved)
            sources.append({"url": page.url, "title": extraction.title})
            trail.append({"url": page.url, "outcome": f"saved: {saved.title} ({getattr(saved, 'level', '')})"})

    if found:
        store.save_courses() if kind == "course" else store.save_scholarships()

    return {
        "researched": found,
        "sources": sources,
        "changes": changes,
        "budget_note": budget.student_note(),
        "budget_summary": {
            **budget.summary(),
            "unchanged_pages": reused,
            "off_allowlist": off_host,
            "trail": trail,
        },
    }


_NOT_COURSE = ("/blog", "blogs.", "/news", "/stories", "/story/", "/student-life", "/events",
               "/magazine", "/press", "/insights", "/articles/", "/podcast")


def _not_a_course_page(url: str) -> bool:
    """Blogs and news pages never hold a course's entry requirements; reading
    them spent the whole page budget on "why I chose computer science"."""
    low = url.lower()
    return any(part in low for part in _NOT_COURSE)


def _existing_match(store, row, kind: str):
    if kind == "course":
        key = store.course_key(row)
        for existing in store.courses.values():
            if store.course_key(existing) == key:
                return existing
        return None
    title = normalise_text(row.title)
    for existing in store.scholarships.values():
        if normalise_text(existing.title) == title:
            return existing
    return None


async def merge(state: dict) -> dict:
    """One pool: what we held and what we just found, judged identically."""
    pool = list(state.get("candidates") or [])
    known = {getattr(r, "id", id(r)) for r in pool}
    for row in state.get("researched") or []:
        if getattr(row, "id", id(row)) not in known:
            pool.append(row)
    note = state.get("search_note", "")
    if state.get("store_exhausted") and state.get("researched"):
        note = "I did not have anything saved for that, so I went and read the universities' own pages."
    return {"candidates": pool, "search_note": note}


# ------------------------------------------------------------ the decisions
async def apply_restrictions(state: dict) -> dict:
    """Code, not the model. Runs over everything, however it got here."""
    rules = state["store"].rules
    scope: StudentScope = state["scope"]
    out = []
    needs_district = False
    for row in state.get("candidates") or []:
        check = check_restrictions(
            rules,
            getattr(row, "university", "") or getattr(row, "provider", ""),
            scope,
        )
        needs_district = needs_district or check.needs_home_district
        out.append((row, check))
    return {"restricted_pairs": out, "needs_home_district": needs_district}


async def compute_eligibility(state: dict) -> dict:
    """The verdict. Decided before the model is called, and never by it."""
    profile: StudentProfile = state["profile"]
    results = [(row, eligibility(profile, row)) for row in state.get("candidates") or []]
    return {"eligibility_pairs": results}


# --------------------------------------------------------------- the model
RANK_SCHEMA = {
    "type": "object",
    "properties": {
        "matches": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "confidence": {"type": "number"},
                    "why": {"type": "string"},
                },
                "required": ["id", "confidence", "why"],
            },
        }
    },
    "required": ["matches"],
}

_RANK_SYSTEM = (
    "You put university courses in a sensible order for one student.\n\n"
    "Use ONLY the courses given to you. Never invent a course, a university, "
    "a fee or an intake. Return at most 12, best first. Score each 0-100 and "
    "explain in one or two short sentences why it might suit them. Do not "
    "promise admission and do not give a percentage chance of being accepted."
)


def _first_value(item: dict, names: tuple[str, ...], default=None):
    for name in names:
        if name in item and item[name] not in (None, ""):
            return item[name]
    return default


_CONFIDENCE_KEYS = ("confidence", "score", "rating", "match", "relevance",
                    "fit", "suitability")
_WHY_KEYS = ("why", "reason", "reasoning", "explanation", "rationale",
             "justification", "note", "comment")
_ID_KEYS = ("id", "course_id", "scholarship_id", "row_id", "identifier")


async def rank(state: dict) -> dict:
    """The model orders what it was given. Ids outside the batch are dropped."""
    import json

    candidates = state.get("candidates") or []
    if not candidates:
        return {"ranking": {}}

    by_id = {c.id: c for c in candidates}
    payload = [
        {
            "id": c.id,
            "title": c.title,
            "university": getattr(c, "university", "") or getattr(c, "provider", ""),
            "country": c.country,
            "level": c.level,
            "subject": getattr(c, "subject", ""),
        }
        for c in candidates[:40]
    ]
    profile: StudentProfile = state["profile"]
    user = (
        "Student profile:\n" + "\n".join(profile.summary_lines())
        + f"\n\nThey asked: {state.get('query', '') or '(nothing specific)'}"
        + "\n\nCourses:\n" + json.dumps(payload, ensure_ascii=False)
    )

    ranking: dict[str, dict] = {}
    unknown: list[str] = []
    try:
        data = await state["llm"].complete_json(
            _RANK_SYSTEM, user, RANK_SCHEMA, label="rank"
        )
        from app.providers.base import clamp

        returned = data.get("matches")
        if not isinstance(returned, list):
            # Some models wrap the list, or name the key something else.
            # Take the first list of objects we can find rather than lose
            # the whole ranking to a wrapper.
            returned = next(
                (v for v in data.values() if isinstance(v, list) and v
                 and isinstance(v[0], dict)),
                [],
            )
            if returned:
                log.info("ranking: 'matches' was missing; used a wrapped list")

        for item in returned or []:
            if not isinstance(item, dict):
                continue
            # The same shape problem as everywhere else: the id came back
            # correctly and the score came back under another name, so every
            # result scored 0 and the ordering was silently lost.
            row_id = str(_first_value(item, _ID_KEYS, ""))
            if row_id not in by_id:
                unknown.append(row_id)
                continue  # the model made it up; drop it
            score = _first_value(item, _CONFIDENCE_KEYS)
            # a 0-1 score is a common reading of "score this match"
            if isinstance(score, (int, float)) and 0 < score <= 1:
                score = score * 100
            ranking[row_id] = {
                "confidence": int(clamp(score, 0, 100, 0)),
                "why": str(_first_value(item, _WHY_KEYS, "") or "").strip()[:300],
            }

        scored = [r for r in ranking.values() if r["confidence"] > 0]
        if ranking and not scored:
            log.warning(
                "ranking scored every result 0 - the model replied with "
                "item keys %s",
                sorted({k for i in returned if isinstance(i, dict) for k in i}),
            )

        if unknown:
            log.warning(
                "ranking returned %s id(s) we did not send, dropped: %s",
                len(unknown), unknown[:5],
            )
        if not ranking and candidates:
            log.warning(
                "ranking produced nothing usable. sent %s id(s) %s; model "
                "replied with keys %s",
                len(by_id), list(by_id)[:5], list(data)[:5],
            )
    except Exception as exc:  # noqa: BLE001
        log.warning("ranking failed (%s); keeping search order", type(exc).__name__)

    return {"ranking": ranking}


PHRASE_SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "reasons": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["id", "reasons"],
            },
        }
    },
    "required": ["items"],
}

_PHRASE_SYSTEM = (
    "The verdict and the facts below are already decided and are correct. "
    "Do not change them, do not add requirements, do not invent anything.\n\n"
    "Rewrite the facts for each scholarship as one or two short, plain "
    "sentences a student can read quickly. Keep every number exactly as "
    "given."
)


async def phrase(state: dict) -> dict:
    """The model's smallest job: making the facts readable.

    Wrapped, because a failed phrasing must never lose a verdict.
    """
    import json

    pairs = state.get("eligibility_pairs") or []
    if not pairs:
        return {"phrased": {}}

    payload = [
        {"id": row.id, "title": row.title, "verdict": result.verdict.value,
         "facts": result.facts}
        for row, result in pairs[:30]
    ]
    phrased: dict[str, list[str]] = {}
    try:
        data = await state["llm"].complete_json(
            _PHRASE_SYSTEM, json.dumps(payload, ensure_ascii=False),
            PHRASE_SCHEMA, label="phrase",
        )
        for item in (data.get("items") or []):
            row_id = str(item.get("id", ""))
            reasons = [str(r).strip() for r in (item.get("reasons") or []) if str(r).strip()]
            if row_id and reasons:
                phrased[row_id] = reasons[:3]
    except Exception as exc:  # noqa: BLE001
        log.info("phrasing failed (%s); using the raw facts", type(exc).__name__)

    return {"phrased": phrased}