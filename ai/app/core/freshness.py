"""How long we are willing to trust something we read.

The failure this file exists to prevent: we read a deadline in March, a
university moves it in June, and in July we tell a student the old date
with complete confidence. They miss the intake. Nothing else in the system
can cost a student a year as cheaply as this.

The fix is that different facts run on different clocks. A university's
country does not change. A deadline changes mid-cycle. So a row is never
simply "fresh" or "stale" - each field is judged on its own.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Any


class FieldClass(str, Enum):
    identity = "identity"        # the university's name, its country
    descriptive = "descriptive"  # course title, level, length
    requirement = "requirement"  # IELTS, GPA, nationality rules
    money = "money"              # tuition, award amount
    deadline = "deadline"        # the dangerous one


# How many days we trust a value of each kind before it has to be re-read.
TRUST_DAYS: dict[FieldClass, int] = {
    FieldClass.identity: 365,
    FieldClass.descriptive: 180,
    FieldClass.requirement: 90,
    FieldClass.money: 90,
    FieldClass.deadline: 7,
}


class Freshness(str, Enum):
    fresh = "fresh"              # inside its window; state it plainly
    needs_recheck = "needs_recheck"  # past its window; re-read before using
    unconfirmed = "unconfirmed"  # we could not confirm it; show with a link


@dataclass
class Fact:
    """A single value, and everything needed to decide whether to trust it."""

    value: Any
    field_class: FieldClass = FieldClass.descriptive
    source_url: str = ""
    evidence: str = ""           # the exact sentence it came from
    checked_at: datetime | None = None
    confirmed_unchanged_at: datetime | None = None

    @property
    def last_seen(self) -> datetime | None:
        """The most recent moment we know this was still true."""
        stamps = [s for s in (self.checked_at, self.confirmed_unchanged_at) if s]
        return max(stamps) if stamps else None


def _utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def age_days(fact: Fact, now: datetime | None = None) -> float | None:
    now = _utc(now or datetime.now(timezone.utc))
    seen = fact.last_seen
    if seen is None:
        return None
    return (now - _utc(seen)).total_seconds() / 86400.0


def freshness(fact: Fact, now: datetime | None = None) -> Freshness:
    if not fact.source_url and not fact.evidence:
        return Freshness.unconfirmed
    age = age_days(fact, now)
    if age is None:
        return Freshness.unconfirmed
    allowed = TRUST_DAYS.get(fact.field_class, 180)
    return Freshness.fresh if age <= allowed else Freshness.needs_recheck


def must_recheck(fact: Fact, now: datetime | None = None) -> bool:
    """Should this field be re-read from its page before we answer?"""
    return freshness(fact, now) is not Freshness.fresh


def can_state_plainly(fact: Fact, now: datetime | None = None) -> bool:
    """May this value be written as a plain statement of fact?

    If this returns False the value is still shown - hiding it helps
    nobody - but it is shown with its link and a note that it needs
    checking, never as a confident assertion.
    """
    return freshness(fact, now) is Freshness.fresh


def display(fact: Fact, now: datetime | None = None) -> dict:
    """What the API hands the app for one value."""
    state = freshness(fact, now)
    if state is Freshness.fresh:
        note = ""
    elif state is Freshness.needs_recheck:
        note = "We could not re-check this just now - please confirm it on their page."
    else:
        note = "Not confirmed - please check this on their page."
    return {
        "value": fact.value,
        "confirmed": state is Freshness.fresh,
        "note": note,
        "source_url": fact.source_url,
    }


def stalest_first(facts: dict[str, Fact], now: datetime | None = None) -> list[str]:
    """Field names that need re-reading, most overdue first.

    Used to decide what one request should spend its fetch budget on when
    it cannot afford to re-read everything.
    """
    overdue: list[tuple[float, str]] = []
    for name, fact in facts.items():
        if not must_recheck(fact, now):
            continue
        age = age_days(fact, now)
        allowed = TRUST_DAYS.get(fact.field_class, 180)
        # How far past its own window, proportionally - so a deadline three
        # days over outranks a tuition fee a month over.
        overdue.append(((age or 1e9) / max(allowed, 1), name))
    overdue.sort(reverse=True)
    return [name for _, name in overdue]


# ---------------------------------------------------------------------------
@dataclass
class Change:
    """A value we previously stored that has since moved."""

    field: str
    old_value: Any
    new_value: Any
    source_url: str = ""

    def message(self) -> str:
        label = {
            "deadline": "This deadline moved",
            "tuition": "The tuition figure changed",
            "amount": "The award amount changed",
            "min_ielts": "The IELTS requirement changed",
            "min_gpa": "The grade requirement changed",
        }.get(self.field, f"{self.field} changed")
        return f"{label} from {self.old_value} to {self.new_value}. We checked their page today."


def diff_facts(old: dict[str, Fact], new: dict[str, Fact]) -> list[Change]:
    """What actually changed between what we held and what we just read.

    This is not only bookkeeping. A moved deadline is worth showing the
    student - it is the clearest possible evidence that the app is checking
    rather than guessing.
    """
    changes: list[Change] = []
    for name, new_fact in new.items():
        old_fact = old.get(name)
        if old_fact is None:
            continue
        if str(old_fact.value).strip() != str(new_fact.value).strip():
            changes.append(
                Change(
                    field=name,
                    old_value=old_fact.value,
                    new_value=new_fact.value,
                    source_url=new_fact.source_url,
                )
            )
    return changes


def touch_unchanged(fact: Fact, now: datetime | None = None) -> Fact:
    """We re-read the page and the value was the same - restart its clock.

    Cheap, and the common case. Most re-reads find nothing new.
    """
    fact.confirmed_unchanged_at = _utc(now or datetime.now(timezone.utc))
    return fact
