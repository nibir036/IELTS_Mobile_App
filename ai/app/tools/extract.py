"""Turning a university page into rows we can decide things with.

The model is asked for fields AND, for each one, the exact sentence from
the page that says it. Then `core.evidence` checks the sentence really
contains the value, and anything that fails is dropped.

That check is the whole reason this is safe. Without it, "IELTS 7.0" read
off the page and "IELTS 7.0" filled in from the model's general knowledge
look identical.
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field

from app.core.catalogue import Course, Scholarship, Source, make_fact
from app.core.eligibility import level_in_text
from app.core.evidence import (
    ExtractedField, Rejection, find_evidence, keep_backed,
)
from app.core.numbers import num
from app.providers.base import LLMProvider
from app.tools.fetch import Page, sentences

log = logging.getLogger(__name__)

COURSE_SCHEMA = {
    "type": "object",
    "properties": {
        "found": {"type": "boolean"},
        "title": {"type": "string"},
        "university": {"type": "string"},
        "level": {"type": "string"},
        "subject": {"type": "string"},
        "duration": {"type": "string"},
        "intake": {"type": "string"},
        "fields": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "value": {"type": "string"},
                    "evidence": {"type": "string"},
                },
                "required": ["name", "value", "evidence"],
            },
        },
    },
    "required": ["found", "fields"],
}

SCHOLARSHIP_SCHEMA = {
    "type": "object",
    "properties": {
        "found": {"type": "boolean"},
        "title": {"type": "string"},
        "provider": {"type": "string"},
        "level": {"type": "string"},
        "nationalities": {"type": "array", "items": {"type": "string"}},
        "fields": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "value": {"type": "string"},
                    "evidence": {"type": "string"},
                },
                "required": ["name", "value", "evidence"],
            },
        },
    },
    "required": ["found", "fields"],
}

_SYSTEM = (
    "You read one university or funding page and report only what it "
    "actually says.\n\n"
    "For every value you report you must also give `evidence`: the exact "
    "sentence from the page that states it, copied word for word. If you "
    "cannot find a sentence that states a value, leave that field out "
    "entirely. Do not infer, do not estimate, do not use anything you know "
    "from outside this page.\n\n"
    "Field names you may use: min_ielts, min_gpa, tuition, amount, deadline.\n"
    "Dates must be written as YYYY-MM-DD. Money must be digits only.\n\n"
    "Always give `title` and `university` (or `provider` for an award) "
    "when the page is about one course or award. These two name the thing "
    "and a result without them is discarded, so a page read without them "
    "is wasted. The evidence rule above does not apply to them: the title "
    "is the heading, and the institution is whose site this is - the page "
    "URL identifies it even where the text does not repeat the name.\n"
    "Set found=false if this page is not about a single course or award."
)

# Extraction is the single most expensive thing this service does - one
# call per fetched page, with a lot of text in it. Keeping only the lines
# that could possibly carry a requirement, a fee or a date cuts that
# several times over with no loss, because the rest never held an answer.
_MAX_CHARS = 6_000

# Bump this whenever a change here would produce a different row from the
# same page: a new field, a changed prompt, a corrected evidence rule.
# Rows stored under an older number are re-read even if the page has not
# changed, which is the only way a fix reaches pages already seen.
#
#   1  first release
#   2  evidence search understands "24,500" and "15 January 2027", so
#      tuition and deadline stopped being dropped from every page
EXTRACTOR_VERSION = 2


@dataclass
class Extraction:
    found: bool = False
    title: str = ""
    university: str = ""
    provider: str = ""
    level: str = ""
    subject: str = ""
    duration: str = ""
    intake: str = ""
    nationalities: tuple[str, ...] = ()
    kept: list[ExtractedField] = field(default_factory=list)
    dropped: list[Rejection] = field(default_factory=list)
    source: Source | None = None

    def value(self, name: str):
        for f in self.kept:
            if f.name == name:
                return f.value
        return None

    def evidence(self, name: str) -> str:
        for f in self.kept:
            if f.name == name:
                return f.evidence
        return ""


# The top of a page carries what identifies it - the course name, the
# institution, the breadcrumb. None of that contains a requirement
# keyword, so a purely keyword-driven trim discards it and the model is
# handed a page with no heading on it. This many characters are kept
# unconditionally, before any scoring happens.
_KEEP_HEAD_CHARS = 1_500

_FACT_WORDS = (
    "ielts", "english", "entry", "requirement", "deadline", "apply",
    "closing", "fee", "tuition", "cost", "scholarship", "award", "gpa",
)


def _trim_for_prompt(page: Page) -> str:
    """Keep the parts of the page most likely to hold the facts.

    Two things matter and they are not the same: what the page IS, which
    lives at the top and names no facts at all, and what the page SAYS,
    which is scattered through it. Scoring alone finds only the second,
    which is how a 38,000-character course page reached the model with
    its own title missing and came back naming nothing.
    """
    text = page.text
    if len(text) <= _MAX_CHARS:
        return text

    lines = text.split("\n")

    # 1. the head, whole, in order
    head: list[int] = []
    used = 0
    for i, line in enumerate(lines):
        if used >= _KEEP_HEAD_CHARS:
            break
        head.append(i)
        used += len(line) + 1

    # 2. then the lines that actually state something. A navigation link
    #    reading "Fees" scores the same as a sentence giving the fee, so
    #    score is weighed against length: real wording is not one word.
    def score(line: str) -> float:
        low = line.lower()
        hits = sum(word in low for word in _FACT_WORDS)
        if not hits:
            return 0.0
        words = len(line.split())
        if words < 4:          # a link or a menu item, not a statement
            return hits * 0.25
        return hits * min(words, 40) / 10.0

    rest = [
        (score(line), i)
        for i, line in enumerate(lines)
        if i not in set(head) and score(line) > 0
    ]
    rest.sort(key=lambda t: (-t[0], t[1]))

    budget = _MAX_CHARS - used
    picked: list[int] = []
    for _, i in rest:
        length = len(lines[i]) + 1
        if length > budget:
            continue
        picked.append(i)
        budget -= length
        if budget <= 0:
            break

    keep = sorted(set(head) | set(picked))
    return "\n".join(lines[i] for i in keep)[:_MAX_CHARS]


def _coerce(name: str, raw: str):
    """Normalise what the model reported into the type we store."""
    text = str(raw).strip()
    if name in {"min_ielts", "min_gpa", "tuition", "amount"}:
        return num(text)
    if name == "deadline":
        match = re.search(r"\d{4}-\d{2}-\d{2}", text)
        return match.group(0) if match else text
    return text


_FIELD_NAMES = ("min_ielts", "min_gpa", "tuition", "amount", "deadline")
_NAME_KEYS = ("name", "field", "key", "type", "label")
_VALUE_KEYS = ("value", "val", "amount", "number")
_EVIDENCE_KEYS = ("evidence", "quote", "sentence", "source_text", "text")


def _as_field_list(data: dict) -> list[dict]:
    """Pull facts out of whatever shape the model replied in.

    The schema asks for a list of {name, value, evidence}. Smaller models
    return a dict keyed by field name, or put the fields at the top level
    beside the title, or rename `name` to `field`. None of that changes
    what they found, and all of it used to be discarded in silence.

    Nothing here loosens the evidence rule: every value taken from these
    shapes is still checked against a sentence on the page, and dropped
    if the page does not state it.
    """
    out: list[dict] = []

    def add(name, value, evidence="") -> None:
        name = str(name or "").strip().lower()
        if name in _FIELD_NAMES and value not in (None, ""):
            out.append({"name": name, "value": value, "evidence": evidence})

    raw = data.get("fields")
    if raw is None:
        raw = data.get("facts")

    if isinstance(raw, list):
        for item in raw:
            if isinstance(item, dict):
                add(_pick(item, _NAME_KEYS), _pick(item, _VALUE_KEYS),
                    _pick(item, _EVIDENCE_KEYS, ""))
    elif isinstance(raw, dict):
        # {"fields": {"min_ielts": 6.5}} or {"min_ielts": {"value": 6.5}}
        for name, value in raw.items():
            if isinstance(value, dict):
                add(name, _pick(value, _VALUE_KEYS),
                    _pick(value, _EVIDENCE_KEYS, ""))
            else:
                add(name, value)

    if not out:
        # last resort: the fields sitting at the top level next to the title
        for name in _FIELD_NAMES:
            value = data.get(name)
            if isinstance(value, dict):
                add(name, _pick(value, _VALUE_KEYS),
                    _pick(value, _EVIDENCE_KEYS, ""))
            else:
                add(name, value)

    return out


def _pick(item: dict, names: tuple[str, ...], default=None):
    for name in names:
        if name in item and item[name] not in (None, ""):
            return item[name]
    return default


def _repair_evidence(value, claimed: str, page: Page) -> str:
    """If the quoted sentence is not on the page, look for a real one.

    Models paraphrase. A paraphrase is not evidence, so rather than trust
    it we search the page for a sentence that genuinely contains the value.
    """
    flat = page.text.lower()
    if claimed and claimed.strip().lower()[:60] in flat:
        return claimed
    if value in (None, ""):
        return ""
    # The same test the quoted sentence would have faced. A plain
    # substring search was looking for "24500" on a page that says
    # "GBP 24,500", so every tuition and award amount was dropped.
    return find_evidence(value, sentences(page.text))


# A page with none of these words has no answer on it, whatever it is
# about. Checking in code costs nothing; asking a model costs a call.
_WORTH_READING = (
    "ielts", "english language", "entry requirement", "entry requirements",
    "deadline", "closing date", "apply by", "tuition", "fee", "fees",
    "scholarship", "award", "funding", "eligib",
)


def worth_extracting(page: Page, kind: str = "course") -> bool:
    """Cheap relevance gate, so we do not pay to read a listing page."""
    if not page.ok or len(page.text) < 200:
        return False
    low = page.text.lower()
    return any(word in low for word in _WORTH_READING)


async def extract_from_page(
    llm: LLMProvider,
    page: Page,
    kind: str = "course",
) -> Extraction:
    """kind is 'course' or 'scholarship'."""
    if not page.ok:
        return Extraction(found=False)
    # Judge the address before paying to read the page. The URL says an
    # article is an article whatever the text turns out to say, and the
    # check was running after extraction - so a help-desk article cost a
    # model call and several seconds before being thrown away, in a run
    # that then ran out of time with real pages still unread.
    if looks_like_an_article("", page.url):
        log.info("skipped extraction for %s - the address says it is an article", page.url)
        return Extraction(found=False)
    if not worth_extracting(page, kind):
        log.info("skipped extraction for %s - no requirement wording on it", page.url)
        return Extraction(found=False)

    schema = COURSE_SCHEMA if kind == "course" else SCHOLARSHIP_SCHEMA
    user = (
        f"Page URL: {page.url}\n\n"
        f"Page text:\n{_trim_for_prompt(page)}"
    )

    try:
        data = await llm.complete_json(
            # The cheap model is safe here precisely because of the
            # evidence check: a weaker model that invents a requirement has
            # its claim dropped rather than shipped.
            _SYSTEM, user, schema, fast=True, label="extract"
        )
    except Exception as exc:  # noqa: BLE001 - a failed read is not fatal
        log.info("extraction failed for %s: %s", page.url, type(exc).__name__)
        return Extraction(found=False)

    # A schema is a request, not a guarantee. `response_format: json_object`
    # on an OpenAI-compatible endpoint enforces valid JSON and nothing more,
    # so a smaller model returns the right content under the wrong shape -
    # most often by omitting `found` entirely. Treating that as "found
    # nothing" threw away correctly extracted pages, silently.
    raw_fields = _as_field_list(data)
    candidates: list[ExtractedField] = []
    for item in raw_fields:
        name = item["name"]
        value = _coerce(name, item["value"])
        if value is None or value == "":
            continue
        evidence = _repair_evidence(
            item.get("value", ""), str(item.get("evidence", "")), page
        )
        candidates.append(
            ExtractedField(name=name, value=value, evidence=evidence, source_url=page.url)
        )

    kept, dropped = keep_backed(candidates)
    if dropped:
        log.info(
            "dropped %s unbacked field(s) from %s: %s",
            len(dropped), page.url, ", ".join(d.field for d in dropped),
        )

    nationalities = tuple(
        str(n).strip() for n in (data.get("nationalities") or []) if str(n).strip()
    )

    title = str(data.get("title", "")).strip()
    university = str(data.get("university", "")).strip()
    provider = str(data.get("provider", "")).strip()

    # Trust an explicit answer; infer one when the model did not give it.
    # Something named, on a page we were allowed to read, is a find.
    if "found" in data:
        found = bool(data.get("found"))
    else:
        found = bool(title and (university or provider or kept))
        if found:
            log.info("%s gave no 'found' field; inferred from the content", page.url)

    if not found:
        log.info(
            "%s produced nothing usable (keys returned: %s)",
            page.url, ", ".join(sorted(str(k) for k in data)) or "none",
        )

    return Extraction(
        found=found,
        title=title,
        university=university,
        provider=provider,
        level=str(data.get("level", "")).strip(),
        subject=str(data.get("subject", "")).strip(),
        duration=str(data.get("duration", "")).strip(),
        intake=str(data.get("intake", "")).strip(),
        nationalities=nationalities,
        kept=kept,
        dropped=dropped,
        source=Source(
            url=page.url,
            title=data.get("title", ""),
            content_hash=page.content_hash,
            extractor=EXTRACTOR_VERSION,
        ),
    )


# Wording that marks a page as writing ABOUT courses rather than a course.
# A guide answering "what is an MSc?" is a useful page and a wrong result:
# shown as a course it sends a student to an article to apply to.
_ARTICLE_MARKERS = (
    "what is", "what are", "how to", "why study", "is a ", "worth it",
    "guide", "blog", "news", "top 10", "best universities", "explained",
    "everything you need", "ultimate", "vs ", " vs. ",
)


# The same judgement made on the address. A model asked to read an
# article about MSc courses will often title it "MSc in Computer Science"
# - a reasonable summary and a fabricated course, carrying whatever fee
# the article quoted as an example. It can rename the page; it cannot
# rename the URL.
_ARTICLE_PATHS = (
    "/blog/", "/blogs/", "/news/", "/advice/", "/articles/", "/article/",
    "/insights/", "/guides/", "/guide/", "/stories/", "/opinion/",
)
_ARTICLE_SLUGS = (
    "what-is-", "what-are-", "how-to-", "why-study", "worth-it",
    "-guide", "guide-to-", "-explained", "benefits-of-", "-vs-",
    "top-10-", "best-universities",
)


def looks_like_an_article(title: str, url: str = "") -> bool:
    """Is this a piece of writing rather than a thing to apply to?

    Judged on the title and on the address, because they fail
    differently: a page the model has retitled still sits at the address
    the article was published under.
    """
    low = (url or "").strip().lower()
    if low:
        if any(part in low for part in _ARTICLE_PATHS):
            return True
        if any(slug in low for slug in _ARTICLE_SLUGS):
            return True

    low = (title or "").strip().lower()
    if not low:
        return False
    if "?" in low:
        return True
    return any(marker in low for marker in _ARTICLE_MARKERS)


_INSTITUTION_WORDS = ("university", "college", "school of", "institute",
                      "academy", "faculty")


def clean_title(title: str, university: str = "") -> str:
    """Page titles carry the site name; a course title should not.

    "MSc Computer Science | University of Suffolk" is the browser tab, not
    the course, and the tail repeats what is already in the university
    column. Only trailing segments go: taking the head instead turns
    "Computer Science | MSc | University of Lincoln" into "Computer
    Science" and loses the level, which is the part that matters most.
    """
    text = (title or "").strip()
    parts = [p.strip() for p in re.split(r"\s+[|\u2013\u2014::]+\s+|\s+-\s+", text)]
    parts = [p for p in parts if p]
    if len(parts) < 2:
        return text

    uni = (university or "").strip().lower()
    while len(parts) > 1:
        last = parts[-1].lower()
        is_institution = (
            (uni and (last == uni or last in uni or uni in last))
            or any(word in last for word in _INSTITUTION_WORDS)
        )
        if not is_institution:
            break
        parts.pop()

    return " ".join(parts).strip() or text


def to_course(ex: Extraction, course_id: str, country: str) -> Course | None:
    title = clean_title(ex.title, ex.university)
    if not ex.found or not (title and ex.university):
        return None
    url = ex.source.url if ex.source else ""
    if looks_like_an_article(title, url):
        log.info("not a course, reads as an article: %r at %s", title, url)
        return None
    # "MSc Computer Science" states its own level. Leaving it blank
    # because the model did not repeat it costs the level filter, the
    # eligibility ladder and the display line - all from a word that is
    # already in the title.
    level = ex.level or level_in_text(title) or level_in_text(ex.subject)

    course = Course(
        id=course_id,
        title=title,
        university=ex.university,
        country=country,
        level=level,
        subject=ex.subject,
        duration=ex.duration,
        intake=ex.intake,
        official_url=ex.source.url if ex.source else "",
        source=ex.source,
    )
    url = course.official_url
    for name in ("min_ielts", "min_gpa", "tuition", "deadline"):
        value = ex.value(name)
        if value is not None:
            setattr(course, name, make_fact(value, name, url, ex.evidence(name)))
    return course


def to_scholarship(ex: Extraction, scholarship_id: str, country: str) -> Scholarship | None:
    if not ex.found or not ex.title:
        return None
    item = Scholarship(
        id=scholarship_id,
        title=ex.title,
        provider=ex.provider or ex.university,
        country=country,
        level=ex.level,
        nationalities=ex.nationalities,
        official_url=ex.source.url if ex.source else "",
        source=ex.source,
    )
    url = item.official_url
    for name in ("min_ielts", "min_gpa", "amount", "deadline"):
        value = ex.value(name)
        if value is not None:
            setattr(item, name, make_fact(value, name, url, ex.evidence(name)))
    return item