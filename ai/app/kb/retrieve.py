"""Personal search and the counsellor's context (RAG).

Course and scholarship search, per student:

  1. the keyword tiers that were already here (exact, auditable)
  2. vector search in pgvector, scored for THIS student:
         score = 0.65 x similarity to what they asked
               + 0.35 x similarity to their profile
               + a small bonus for their preferred country
               - a small penalty for rows they were just shown
     so two students typing the same words get different, personal lists
  3. only genuinely close rows count. If fewer than four are close, the
     service goes and reads the web for more (and stores what it finds)

The counsellor gets, besides the profile: the most relevant knowledge
document chunks, the catalogue rows closest to the question, the student's
recent searches, and their earlier conversation from the database.
"""
from __future__ import annotations

import hashlib
import json
import logging
import math
import re

from app.core.eligibility import _rung
from app.core.search import search_words
from app.graphs import nodes

log = logging.getLogger(__name__)


def _profile_text(profile) -> str:
    return "\n".join(profile.summary_lines()) or "No profile details yet."


def _profile_digest(profile) -> str:
    return hashlib.sha1(_profile_text(profile).encode("utf-8")).hexdigest()


async def student_vector(state: dict) -> list[float] | None:
    """The student's profile vector (cached in the database until it changes)."""
    kb, embedder = state.get("kb"), state.get("embedder")
    if not kb or not kb.ready or not embedder or not kb.vectors:
        return None
    profile = state["profile"]
    if profile.is_empty():
        return None
    cached = state.get("profile_vec")
    if cached is not None:
        return cached
    try:
        vec = await kb.profile_vector(
            state.get("student_id", ""),
            profile.model_dump(by_alias=True),
            _profile_digest(profile),
            lambda: embedder.embed_query(_profile_text(profile)),
        )
    except Exception as exc:  # noqa: BLE001
        log.warning("profile vector failed: %s", exc)
        vec = None
    state["profile_vec"] = vec
    return vec


def _query_text(state: dict) -> str:
    c = state.get("constraints") or {}
    bits = [state.get("query", "") or ""]
    for key in ("level", "subject", "country"):
        if c.get(key):
            bits.append(str(c[key]))
    return " ".join(b for b in bits if b).strip()


async def _personal_rows(state: dict, kind: str, rows_by_id: dict) -> tuple[list, int]:
    """(rows ranked for this student, how many are genuinely close)."""
    kb, embedder, settings = state.get("kb"), state.get("embedder"), state.get("settings")
    if not kb or not kb.ready or not kb.vectors or not embedder:
        return [], 0
    query = _query_text(state)
    try:
        qvec = await embedder.embed_query(query) if query else None
    except Exception as exc:  # noqa: BLE001
        log.warning("query embedding failed: %s", exc)
        qvec = None
    pvec = await student_vector(state)
    if not qvec and not pvec:
        return [], 0

    try:
        near = await kb.nearest_items(kind, qvec, pvec, limit=60)
        recent = await kb.recent_searches(state.get("student_id", ""), kind, limit=3)
    except Exception as exc:  # noqa: BLE001
        log.warning("vector search failed: %s", exc)
        return [], 0
    seen_recently = {i for s in recent for i in (s.get("ids") or [])[:6]}
    min_sim = getattr(settings, "rag_min_similarity", 0.6) if settings else 0.6
    country = ((state.get("constraints") or {}).get("country") or "").lower()

    scored = []
    close = 0
    for row_id, qs, ps in near:
        row = rows_by_id.get(row_id)
        if row is None:
            continue
        if qvec is None:
            qs = ps
        score = 0.65 * qs + 0.35 * ps
        if country and country in (row.country or "").lower():
            score += 0.05
        if row_id in seen_recently:
            score -= 0.03
        scored.append((score, row))
        if qs >= min_sim:
            close += 1
    scored.sort(key=lambda x: -x[0])
    return [row for _, row in scored], close


# ----------------------------------------------------------- relevance gate
# Words too general to say what a course is about: "Computer Science" must
# not match "Biomedical Science" on the word "science".
_GENERIC = {
    "science", "sciences", "studies", "study", "applied", "general", "advanced",
    "engineering", "technology", "technologies",
    "honours", "hons", "with", "and", "of", "in", "the", "for", "degree", "degrees",
    "programme", "program", "course", "courses", "international", "top", "best",
    "cheap", "low", "cost", "fee", "fees", "scholarship", "scholarships", "funded",
    "university", "universities", "abroad", "intake", "september", "january", "uk",
    "usa", "us", "canada", "australia", "germany", "ireland", "europe", "bd",
}
_TOKEN = re.compile(r"[a-z0-9+#]+")

# How students in Bangladesh write subjects -> the words course titles use.
_ABBREV = {
    "cse": "computer science engineering", "cs": "computer science",
    "it": "information technology", "ict": "information communication technology",
    "swe": "software engineering", "se": "software engineering",
    "eee": "electrical electronic engineering", "ece": "electronics communication engineering",
    "ete": "electronics telecommunication engineering", "me": "mechanical engineering",
    "ce": "civil engineering", "che": "chemical engineering", "ipe": "industrial production engineering",
    "bba": "business administration", "mba": "business administration",
    "bme": "biomedical engineering", "arch": "architecture", "pharm": "pharmacy",
    "mbbs": "medicine", "bds": "dentistry", "llb": "law", "llm": "law",
    "ds": "data science", "ai": "artificial intelligence", "ml": "machine learning",
    "econ": "economics", "fin": "finance", "acc": "accounting", "mkt": "marketing",
    "hrm": "human resource management", "scm": "supply chain management",
    "geb": "genetic engineering biotechnology", "bmb": "biochemistry molecular biology",
}


_COUNTRIES = (
    "united kingdom", "united states", "new zealand", "south korea", "uk", "usa", "us", "canada",
    "australia", "germany", "ireland", "france", "netherlands", "sweden", "finland", "denmark",
    "norway", "italy", "spain", "japan", "malaysia", "singapore", "china", "korea", "hungary",
    "poland", "austria", "switzerland", "belgium", "dubai", "uae", "turkey", "cyprus", "england",
    "scotland", "wales",
)
_FILLER = {
    "in", "at", "for", "of", "a", "an", "the", "to", "on", "and", "or", "course", "courses",
    "program", "programs", "programme", "programmes", "degree", "degrees", "study", "studies",
    "want", "find", "show", "me", "my", "i", "please", "any", "best", "top", "good", "with",
    "university", "universities", "abroad", "scholarship", "scholarships",
}


def countries_of(text: str, strict: bool = False) -> list[str]:
    """'UK Canada Germany' / 'UK, Canada' -> ['UK', 'Canada', 'Germany'].

    Unknown wording comes back as it was, unless `strict`."""
    rest = f" {(text or '').lower()} "
    found: list[tuple[int, str]] = []
    for name in _COUNTRIES:
        at = rest.find(f" {name} ")
        if at < 0:
            at = rest.find(f" {name},")
        if at >= 0:
            found.append((at, name))
            rest = rest.replace(name, " " * len(name), 1)
    if not found:
        return [] if strict else ([text.strip()] if (text or "").strip() else [])
    pretty = {"uk": "UK", "usa": "USA", "us": "USA", "uae": "UAE"}
    return [pretty.get(n, n.title()) for _, n in sorted(found)]


def place_text(text: str) -> str:
    """'UK Canada Germany' -> 'UK, Canada or Germany'."""
    names = countries_of(text)
    if len(names) <= 1:
        return names[0] if names else ""
    return ", ".join(names[:-1]) + " or " + names[-1]


def typed_subject(query: str, country: str = "") -> str:
    """The subject in what the student typed, without levels or places.

    'PhD Computer Science in UK' -> 'Computer Science'. Empty when the words
    name no subject at all ('msc', 'in canada').
    """
    places = {w for c in countries_of(country, True) + countries_of(query, True) for w in c.lower().split()}
    keep = []
    for token in re.findall(r"[A-Za-z0-9+#&]+", query or ""):
        low = token.lower()
        if low in _FILLER or low in places or low in _COUNTRIES or _rung(low) is not None:
            continue
        keep.append(token)
    if not any(w.lower() not in _GENERIC for w in keep):
        return ""
    return " ".join(keep)


def expand(text: str) -> str:
    """'CSE' -> 'computer science engineering'; other words unchanged."""
    return " ".join(_ABBREV.get(w, w) for w in _TOKEN.findall((text or "").lower()))


def _stem(word: str) -> str:
    # "microbiology" ~ "microbiological", "nursing" ~ "nurse": keep the root.
    return word[: max(4, len(word) - 3)] if len(word) > 5 else word


def topic_words(state: dict) -> list[str]:
    """What the student is looking for, minus levels, places and filler."""
    c = state.get("constraints") or {}
    country = (c.get("country") or "").lower()

    def clean(words) -> list[str]:
        out: list[str] = []
        for w in words:
            w = str(w).lower()
            if len(w) < 3 or w in _GENERIC or w == country or _rung(w) is not None:
                continue
            if w not in out:
                out.append(w)
        return out

    # What they TYPED wins over the profile: a Microbiology student who
    # searches "computer science" wants Computer Science, not Microbiology.
    typed = clean(search_words(expand(state.get("query") or "")))
    if typed:
        profile = state.get("profile")
        own = (getattr(profile, "subject", "") or "").strip().lower()
        subject = (c.get("subject") or "").strip()
        # The model's reading of the request may blend in the profile's
        # subject ("Computer Science for a Microbiology graduate"): keep only
        # words that are not the profile's own subject.
        own_words = set(clean(search_words(expand(own))))
        extra = [w for w in clean(search_words(expand(subject))) if w not in own_words]
        return clean(typed + extra)

    words = search_words(expand(c.get("subject") or ""))
    for k in c.get("keywords") or []:
        words += search_words(expand(str(k)))
    return clean(words)


def _cos(a, b) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


async def keep_relevant(state: dict, rows: list, kind: str) -> list:
    """Only rows that are about what this student wants, at their level.

    A Microbiology student must never be shown MSc Computer Science just
    because those rows happen to be stored. A row stays when:
      * its level is the level they want (or the row does not say), and
      * for courses: its title/subject shares a real word with what they
        want, or it is close in meaning (synonyms: "Microbiology" ~
        "Medical Microbiology and Immunology").
    """
    c = state.get("constraints") or {}
    want_rung = _rung(c.get("level") or "")
    kept = []
    for row in rows:
        row_rung = _rung(getattr(row, "level", "") or "")
        if want_rung is not None and row_rung is not None and row_rung != want_rung:
            continue
        kept.append(row)
    if kind != "course":
        return kept

    words = topic_words(state)
    if not words:
        return kept
    stems = [_stem(w) for w in words]

    def by_words(row) -> bool:
        tokens = _TOKEN.findall(f"{row.title} {getattr(row, 'subject', '')}".lower())
        return any(t.startswith(s) or (len(t) > 3 and s.startswith(_stem(t)))
                   for s in stems for t in tokens if t not in _GENERIC)

    matched = [r for r in kept if by_words(r)]
    rest = [r for r in kept if not by_words(r)]
    embedder, settings = state.get("embedder"), state.get("settings")
    # Meaning is only a rescue for synonyms ("Microbiology" ~ "Medical
    # Immunology and Infection") when no title shares a word at all. Small
    # embedding models score any two short course titles as fairly alike, so
    # letting them add rows next to real word matches mixes subjects.
    if not matched and rest and embedder is not None and getattr(embedder, "dim", 0):
        try:
            topic = " ".join(words).strip()
            q = await embedder.embed_query(topic)
            vecs = await embedder.embed_documents([f"{r.title}. {getattr(r, 'subject', '')}" for r in rest])
            floor = getattr(settings, "subject_min_similarity", 0.8) if settings else 0.8
            sims = [(_cos(q, v) if q else 0.0) for v in vecs]
            best = max(sims, default=0.0)
            close = {id(r) for r, sim in zip(rest, sims) if sim >= floor and sim >= best - 0.03}
            matched += [r for r in rest if id(r) in close]
        except Exception as exc:  # noqa: BLE001
            log.warning("subject check by meaning failed: %s", exc)
    order = {id(r): i for i, r in enumerate(kept)}
    matched.sort(key=lambda r: order[id(r)])
    if len(matched) < len(kept):
        log.info("relevance gate (%s): kept %s of %s for %s", kind, len(matched), len(kept), words)
    return matched


async def relevant_only(state: dict) -> dict:
    """Graph node, after research is merged in: the same gate again, so
    nothing off-subject slips in from the fallback tiers or a stray page."""
    kind = state.get("kind") or "course"
    rows = await keep_relevant(state, list(state.get("candidates") or []), kind)
    out: dict = {"candidates": rows}
    if not rows:
        c = state.get("constraints") or {}
        subject = typed_subject(state.get("query") or "", c.get("country") or "") or c.get("subject") or ""
        what = " ".join(x for x in (c.get("level") or "", subject) if x).strip()
        where = f" in {place_text(c['country'])}" if c.get("country") else ""
        thing = "courses" if kind == "course" else "scholarships"
        out["search_note"] = (
            f"We could not find {what + ' ' if what else ''}{thing}{where} yet. "
            "Try another country or a related subject, or ask a nextED counsellor - "
            "they can check universities we have not read yet."
        )
    return out


async def _search(state: dict, kind: str) -> dict:
    """Search, then the relevance gate, then decide whether to research."""
    out = await _search_raw(state, kind)
    rows = await keep_relevant(state, list(out.get("candidates") or []), kind)
    if len(rows) == len(out.get("candidates") or []):
        if rows and kind == "course" and topic_words(state):
            # Every row passed the subject check, so a "nothing matches your
            # words" note from the plain keyword search would be wrong.
            out = {**out, "search_note": ""}
        return out
    out = dict(out)
    out["candidates"] = rows
    # Fewer than four real matches: go and read the universities' pages.
    out["search_tier"] = "personal" if len(rows) >= 4 else ("personal-thin" if rows else "nearest")
    out["store_exhausted"] = not rows
    if len(rows) >= 4:
        out["search_note"] = ""
    return out


async def _search_raw(state: dict, kind: str) -> dict:
    """Keyword tiers + personal vector search, merged."""
    profile = state["profile"]
    constraints = dict(state.get("constraints") or {})
    # No words typed: search on what the profile says they want to study,
    # instead of matching everything (which is why every student used to get
    # the same handful of rows).
    if not constraints.get("keywords") and constraints.get("subject"):
        constraints["keywords"] = search_words(expand(constraints["subject"]))
    keyword_state = {**state, "constraints": constraints}
    if not (state.get("query") or "").strip() and constraints.get("subject"):
        keyword_state["query"] = constraints["subject"]  # "Nothing matches Nursing", not "that"
    local = await (nodes.search_courses_local(keyword_state) if kind == "course"
                   else nodes.search_scholarships_local(keyword_state))

    store = state["store"]
    rows_by_id = store.courses if kind == "course" else store.scholarships
    personal, close = await _personal_rows(state, kind, rows_by_id)

    tier = local.get("search_tier", "")
    exact = tier in {"country+words", "words"} and bool(constraints.get("keywords"))
    if not personal:
        return local

    # Rows that matched the words AND are close in meaning first, then the
    # rest of the closest rows, then the remaining keyword matches.
    keyword_ids = {r.id for r in local.get("candidates") or []} if exact else set()
    merged, seen = [], set()
    for row in personal:
        if row.id in keyword_ids:
            merged.append(row)
            seen.add(row.id)
    for row in personal[: max(close, 0) or 0]:
        if row.id not in seen:
            merged.append(row)
            seen.add(row.id)
    for row in local.get("candidates") or []:
        if exact and row.id not in seen:
            merged.append(row)
            seen.add(row.id)
    take = 40 if kind == "course" else 30
    good = len(merged)
    if good == 0:
        # Nothing truly close: show the nearest anyway, honestly labelled,
        # and let research go and find better.
        merged = personal[:take]
    log.info("personal search (%s): %s close, %s keyword, %s shown", kind, close, len(keyword_ids), len(merged[:take]))
    note = local.get("search_note", "") if good else (
        "Nothing we hold is a close match yet. These are the nearest for your profile."
    )
    return {
        "candidates": merged[:take],
        "search_note": note if good < 4 else "",
        "search_tier": "personal" if good >= 4 else ("personal-thin" if good else "nearest"),
        "store_exhausted": good == 0,
    }


async def search_courses(state: dict) -> dict:
    return await _search(state, "course")


async def search_scholarships(state: dict) -> dict:
    return await _search(state, "scholarship")


# --------------------------------------------------------------- counsellor
async def counsellor_context(state: dict) -> dict:
    """Knowledge, catalogue rows, recent searches and memory for the reply."""
    kb, embedder = state.get("kb"), state.get("embedder")
    out: dict = {}
    if not kb or not kb.ready:
        return out
    message = state.get("message", "") or ""
    student_id = state.get("student_id", "")
    try:
        qvec = await embedder.embed_query(message) if (embedder and kb.vectors and message) else None
    except Exception as exc:  # noqa: BLE001
        log.warning("message embedding failed: %s", exc)
        qvec = None

    blocks: list[str] = []
    try:
        docs = await kb.search_docs(qvec, search_words(message), limit=4)
        min_sim = getattr(state.get("settings"), "rag_min_similarity", 0.6) - 0.1
        docs = [d for d in docs if d.get("score", 0) >= min_sim]
        if docs:
            blocks.append("KNOWLEDGE (from nextED's own guides - prefer this over general knowledge):")
            for d in docs:
                blocks.append(f"[{d['title']}]\n{d['content'][:1500]}")
    except Exception as exc:  # noqa: BLE001
        log.warning("document search failed: %s", exc)

    try:
        store = state["store"]
        pvec = await student_vector(state)
        rows = []
        for kind, table in (("course", store.courses), ("scholarship", store.scholarships)):
            near = await kb.nearest_items(kind, qvec, pvec, limit=4) if (qvec or pvec) else []
            for row_id, qs, ps in near:
                row = table.get(row_id)
                if row is not None and max(qs, ps) >= 0.55:
                    rows.append((kind, row))
        if rows:
            blocks.append("CATALOGUE ROWS that may be relevant (only mention them if they fit the question):")
            for kind, row in rows[:6]:
                org = getattr(row, "university", "") or getattr(row, "provider", "")
                blocks.append(f"- {kind}: {row.title} - {org}, {row.country} {getattr(row, 'level', '')}".strip())
    except Exception as exc:  # noqa: BLE001
        log.warning("catalogue context failed: %s", exc)

    try:
        searches = await kb.recent_searches(student_id, limit=3)
        typed = [s["query"] for s in searches if s.get("query")]
        if typed:
            blocks.append("The student recently searched for: " + "; ".join(typed))
    except Exception as exc:  # noqa: BLE001
        log.warning("search history failed: %s", exc)

    # The student's one thread lives in the database, so it is the source of
    # truth (another device, a reinstall, a new login all continue the same
    # conversation). The recent messages are read word for word; everything
    # older is in the long-term memory summary.
    try:
        recent = await kb.recent_messages(student_id, limit=14)
        if recent:
            out["history"] = recent
        summary, _ = await kb.memory(student_id)
        if summary:
            out["memory_block"] = summary
    except Exception as exc:  # noqa: BLE001
        log.warning("chat memory failed: %s", exc)

    if blocks:
        out["rag_block"] = "\n\n".join(blocks)
    return out


def dumps(value) -> str:
    return json.dumps(value, ensure_ascii=False, default=str)
