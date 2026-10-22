"""Is this extracted fact actually backed by the page it claims to come from?

When a model reads a university page and reports "IELTS 7.0 required", one
of two things happened: it read that off the page, or it filled a gap with
something plausible. From the outside those look identical.

So every extracted field has to arrive with the sentence it came from, and
this file checks that the sentence genuinely contains the value. A field
that fails is dropped - not flagged, not softened, dropped. A missing
requirement is survivable; an invented one is not.
"""
from __future__ import annotations

import re
from dataclasses import dataclass

from app.core.numbers import normalise_text, num

_MONTHS = [
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
]


@dataclass
class ExtractedField:
    name: str
    value: object
    evidence: str = ""     # the exact sentence from the page
    source_url: str = ""


@dataclass
class Rejection:
    field: str
    value: object
    reason: str


def _number_renderings(value: float) -> list[str]:
    """The ways a page might reasonably write this number."""
    out: set[str] = set()
    if value == int(value):
        whole = int(value)
        out.add(str(whole))
        out.add(f"{whole:,}")
        out.add(f"{whole}.0")
    else:
        out.add(f"{value:g}")
        out.add(f"{value:.1f}")
        out.add(f"{value:,.2f}".rstrip("0").rstrip("."))
    return [r for r in out if r]


def _date_parts(value: str) -> tuple[str, str] | None:
    """Pull (day, month-name) out of an ISO date so we can look for it."""
    match = re.match(r"(\d{4})-(\d{2})-(\d{2})", str(value).strip())
    if not match:
        return None
    _, month, day = match.groups()
    index = int(month) - 1
    if not 0 <= index < 12:
        return None
    return str(int(day)), _MONTHS[index]


def sentence_supports(value, sentence: str) -> tuple[bool, str]:
    """Does this one sentence state this value?

    The single definition of that question. Checking the model's quoted
    sentence and searching the page for a better one are the same test,
    and when they drifted apart the search used a plain substring match:
    a page saying "£24,500" never matched a value of 24500, so every
    money fact was dropped as unbacked no matter what the page said.
    """
    haystack = (sentence or "").lower()
    flat = normalise_text(sentence or "")

    # A date: both the day and its month should appear.
    parts = _date_parts(value) if isinstance(value, str) else None
    if parts:
        day, month = parts
        if month[:3] in haystack and re.search(rf"\b{day}\b", haystack):
            return True, ""
        # Numeric forms: 15/01/2027, 15-01-2027, 2027-01-15
        iso = str(value).strip()
        y, m, d = iso.split("-")[:3]
        numeric = [
            rf"\b{int(d)}[/.-]{int(m)}[/.-]{y}\b",
            rf"\b{y}-{m}-{d}\b",
            rf"\b{int(m)}[/.-]{int(d)}[/.-]{y}\b",
        ]
        if any(re.search(p, haystack) for p in numeric):
            return True, ""
        return False, "the date does not appear in the evidence sentence"

    # A number: some rendering of it should appear.
    numeric_value = num(value)
    if numeric_value is not None and not isinstance(value, (list, tuple)):
        for rendering in _number_renderings(numeric_value):
            if rendering.lower() in haystack:
                return True, ""
        return False, "the number does not appear in the evidence sentence"

    # A list: at least one member should appear.
    if isinstance(value, (list, tuple)):
        if not value:
            return False, "the value is empty"
        for item in value:
            if normalise_text(str(item)) and normalise_text(str(item)) in flat:
                return True, ""
        return False, "none of the listed values appear in the evidence sentence"

    # Plain text: it should appear, allowing for whitespace and punctuation.
    text = normalise_text(str(value))
    if not text:
        return False, "the value is empty"
    if text in flat:
        return True, ""

    # Allow a shortened title: every significant word present, in any order.
    words = [w for w in text.split() if len(w) > 3]
    if words and all(w in flat for w in words):
        return True, ""

    return False, "the value does not appear in the evidence sentence"


def is_backed(field: ExtractedField) -> tuple[bool, str]:
    """Does the evidence sentence really support the value?"""
    if not field.evidence or not field.evidence.strip():
        return False, "no evidence sentence was supplied"
    if not field.source_url:
        return False, "no source page was supplied"
    return sentence_supports(field.value, field.evidence)


def find_evidence(value, sentences_in_page) -> str:
    """The first sentence on the page that states this value, or nothing.

    Used when the model paraphrased instead of quoting. It is not a way
    around the rule: the sentence returned has to pass the same test the
    model's own quote would have.
    """
    for sentence in sentences_in_page:
        ok, _ = sentence_supports(value, sentence)
        if ok:
            return sentence
    return ""


def keep_backed(
    fields: list[ExtractedField],
) -> tuple[list[ExtractedField], list[Rejection]]:
    """Split an extraction into what we may use and what we must throw away."""
    kept: list[ExtractedField] = []
    dropped: list[Rejection] = []
    for f in fields:
        ok, why = is_backed(f)
        if ok:
            kept.append(f)
        else:
            dropped.append(Rejection(field=f.name, value=f.value, reason=why))
    return kept, dropped