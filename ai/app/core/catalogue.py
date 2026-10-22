"""What a course and a scholarship look like once we hold one.

These rows are not seeded by hand. They arrive one of two ways:

  * read off a university's own page during a search, or
  * already in the table because an earlier search read them.

Either way every field that could matter carries the page it came from,
the sentence that proves it, and the date we last looked. A value with no
source is not a fact, and `evidence.py` drops it before it ever gets here.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from app.core.freshness import FieldClass, Fact


def _now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass
class Source:
    url: str
    fetched_at: datetime = field(default_factory=_now)
    title: str = ""
    content_hash: str = ""
    # Which version of the extraction rules produced this row. Skipping an
    # unchanged page is the cheapest thing the service does, but it also
    # freezes the row: a page read under a rule that was later fixed is
    # never read again, because the page itself has not changed. Recording
    # the version is what lets a fix reach rows already stored.
    extractor: int = 0


@dataclass
class Course:
    id: str
    title: str
    university: str
    country: str = ""
    level: str = ""
    subject: str = ""
    duration: str = ""
    intake: str = ""
    tuition: Fact | None = None       # money
    min_ielts: Fact | None = None     # requirement
    min_gpa: Fact | None = None       # requirement
    deadline: Fact | None = None      # deadline - the short clock
    official_url: str = ""
    source: Source | None = None
    verified_by_staff: bool = False

    def facts(self) -> dict[str, Fact]:
        out: dict[str, Fact] = {}
        for name in ("tuition", "min_ielts", "min_gpa", "deadline"):
            value = getattr(self, name)
            if isinstance(value, Fact):
                out[name] = value
        return out


@dataclass
class Scholarship:
    id: str
    title: str
    provider: str = ""
    country: str = ""
    level: str = ""
    amount: Fact | None = None            # money
    deadline: Fact | None = None          # deadline
    min_ielts: Fact | None = None         # requirement
    min_gpa: Fact | None = None           # requirement
    nationalities: tuple[str, ...] = ()   # empty means not restricted by nationality
    official_url: str = ""
    source: Source | None = None
    verified_by_staff: bool = False

    def facts(self) -> dict[str, Fact]:
        out: dict[str, Fact] = {}
        for name in ("amount", "deadline", "min_ielts", "min_gpa"):
            value = getattr(self, name)
            if isinstance(value, Fact):
                out[name] = value
        return out


# Which clock each field runs on. Used by freshness.py and by the code that
# decides whether a value may be stated plainly or must be shown with
# "check this on their page".
FIELD_CLASSES: dict[str, FieldClass] = {
    "university": FieldClass.identity,
    "country": FieldClass.identity,
    "provider": FieldClass.identity,
    "title": FieldClass.descriptive,
    "level": FieldClass.descriptive,
    "subject": FieldClass.descriptive,
    "duration": FieldClass.descriptive,
    "intake": FieldClass.descriptive,
    "min_ielts": FieldClass.requirement,
    "min_gpa": FieldClass.requirement,
    "nationalities": FieldClass.requirement,
    "tuition": FieldClass.money,
    "amount": FieldClass.money,
    "deadline": FieldClass.deadline,
}


def make_fact(
    value: Any,
    field_name: str,
    source_url: str = "",
    evidence: str = "",
    checked_at: datetime | None = None,
) -> Fact:
    return Fact(
        value=value,
        field_class=FIELD_CLASSES.get(field_name, FieldClass.descriptive),
        source_url=source_url,
        evidence=evidence,
        checked_at=checked_at or _now(),
    )