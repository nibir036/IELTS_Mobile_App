"""Searching what we already hold.

Two things carried over from the current build because they were right:

  * split the query into words. A single `contains` with the whole sentence
    against one column is why typing "ict" used to return nothing.
  * fall back in tiers, and say which tier answered. A student who sees an
    empty screen concludes the app is broken; shown the closest matches with
    an honest note, they have an answer.

The one addition: when every tier here comes up short, the caller is told,
so it can go and read the universities' own pages instead of giving up.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Callable, Sequence

from app.core.numbers import normalise_text

# Words that carry no search value in this domain.
STOP_WORDS = {
    "and", "or", "the", "for", "with", "from", "into", "about", "a", "an",
    "course", "courses", "program", "programs", "programme", "programmes",
    "degree", "degrees", "study", "studies", "studying",
    "university", "universities", "college", "colleges",
    "scholarship", "scholarships", "funding",
    "want", "wants", "looking", "look", "show", "find", "need", "needs",
    "please", "any", "all", "some", "best", "good", "cheap", "cheapest",
    "me", "my", "i", "in", "on", "to", "at", "is", "are", "can", "do",
}

_SPLIT = re.compile(r"[^a-z0-9+#]+")


def search_words(query: str, limit: int = 6) -> list[str]:
    """Query -> the few words actually worth matching on."""
    if not query:
        return []
    words = [w for w in _SPLIT.split(query.lower()) if w]
    out: list[str] = []
    for w in words:
        if len(w) < 2 or w in STOP_WORDS or w in out:
            continue
        out.append(w)
        if len(out) >= limit:
            break
    return out


def matches_words(row: Any, words: Sequence[str], fields: Sequence[str]) -> bool:
    """Any word, in any of these fields. Case and punctuation insensitive."""
    if not words:
        return True
    blob = " ".join(
        normalise_text(str(getattr(row, f, "") or "")) for f in fields
    )
    return any(w in blob for w in words)


@dataclass
class Tier:
    name: str
    note: str
    predicate: Callable[[Any], bool]


@dataclass
class SearchResult:
    rows: list[Any] = field(default_factory=list)
    note: str = ""
    tier: str = ""
    exhausted: bool = False  # nothing in any tier - time to go and look

    @property
    def empty(self) -> bool:
        return not self.rows


def first_non_empty(
    rows: Sequence[Any],
    tiers: Sequence[Tier],
    take: int = 40,
) -> SearchResult:
    """Run the tiers in order; return the first that produces anything."""
    for tier in tiers:
        hits = [r for r in rows if tier.predicate(r)]
        if hits:
            return SearchResult(rows=hits[:take], note=tier.note, tier=tier.name)
    return SearchResult(rows=[], note="", tier="", exhausted=True)


def course_tiers(words: Sequence[str], country: str, query: str) -> list[Tier]:
    fields = ("title", "subject", "university", "country", "level")
    country_key = normalise_text(country)

    def in_country(row: Any) -> bool:
        return bool(country_key) and country_key in normalise_text(
            str(getattr(row, "country", "") or "")
        )

    shown = query.strip() or "that"
    return [
        Tier(
            "country+words",
            "",
            lambda r: in_country(r) and matches_words(r, words, fields),
        ),
        Tier(
            "words",
            "",
            lambda r: matches_words(r, words, fields),
        ),
        Tier(
            "country",
            f"Nothing we hold matches “{shown}” yet. "
            "These are the closest for your profile.",
            in_country,
        ),
        Tier(
            "all",
            f"Nothing we hold matches “{shown}”"
            + (f" in {country}" if country else "")
            + " yet. Here is what we do have.",
            lambda r: True,
        ),
    ]


def scholarship_tiers(words: Sequence[str], country: str, query: str) -> list[Tier]:
    fields = ("title", "provider", "country", "level")
    shown = query.strip() or "that"
    country_key = normalise_text(country)

    def in_country(row: Any) -> bool:
        return bool(country_key) and country_key in normalise_text(
            str(getattr(row, "country", "") or "")
        )

    return [
        Tier(
            "country+words",
            "",
            lambda r: in_country(r) and matches_words(r, words, fields),
        ),
        Tier("words", "", lambda r: matches_words(r, words, fields)),
        Tier(
            "all",
            f"Nothing we hold mentions “{shown}” yet. "
            "These are the ones you could be eligible for.",
            lambda r: True,
        ),
    ]
