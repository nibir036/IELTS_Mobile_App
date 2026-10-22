"""Is this student eligible for this scholarship?

Arithmetic, not judgement. The model is never asked and cannot object.

The three-way result is the important part and the easiest thing to lose
in a rewrite:

    Eligible      - everything we checked passed
    Borderline    - close, OR we are missing something we would need
    Not eligible  - something failed by more than a near miss

"We do not know" is deliberately not the same as "no". A blank profile
field produces Borderline plus a line naming the field to fill in, which is
what makes "complete your profile to unlock more" honest rather than a
nudge.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum

from app.core.catalogue import Scholarship
from app.core.numbers import normalise_text, num
from app.core.profile import StudentProfile

# How close counts as "nearly". Carried over from the current build.
IELTS_NEAR_MISS = 0.5
GPA_NEAR_MISS = 0.3

# The study ladder, lowest first.
#
# These two fields mean different things and comparing them directly is a
# bug worth naming: `profile.highest_level` is what the student has ALREADY
# COMPLETED, while a scholarship's `level` is what they would STUDY on it.
# A student holding a Bachelors is exactly the right applicant for a
# Masters award - which is the single most common case in this product.
# Matching the two strings against each other marks all of them Borderline
# for no reason.
# HSC, A-levels and a diploma are alternatives at the same stage, not steps
# after one another, so they share a rung. Longest spellings are checked
# first so "higher secondary" is not read as "secondary".
_RUNGS: tuple[tuple[str, int], ...] = (
    ("foundation", 0),
    ("higher secondary", 1), ("a level", 1), ("a-level", 1), ("hsc", 1),
    ("intermediate", 1), ("diploma", 1), ("secondary", 1),
    ("undergraduate", 2), ("bachelors", 2), ("bachelor", 2), ("honours", 2),
    ("bsc", 2), ("ba", 2), ("beng", 2), ("bba", 2),
    ("postgraduate", 3), ("masters", 3), ("master", 3),
    ("msc", 3), ("ma", 3), ("mba", 3), ("meng", 3),
    ("doctorate", 4), ("doctoral", 4), ("phd", 4),
)


def _rung(value: str) -> int | None:
    text = normalise_text(value)
    if not text:
        return None
    words = set(text.split())
    for name, rung in _RUNGS:
        # multi-word spellings match as a phrase; single words must be a
        # whole word, so "ma" does not fire inside "management"
        if " " in name or "-" in name:
            if name in text:
                return rung
        elif name in words:
            return rung
    return None


def level_fits(completed: str, wanted: str) -> tuple[bool, str]:
    """Is a student at `completed` a sensible applicant for `wanted`?

    Yes when the award is at their level or the next rung up. Two rungs or
    more above means they would need the qualification in between first.
    """
    here, there = _rung(completed), _rung(wanted)
    if here is None or there is None:
        # Unrecognised wording on either side - fall back to a plain compare
        # rather than guessing.
        if normalise_text(completed) and normalise_text(wanted):
            a, b = normalise_text(completed), normalise_text(wanted)
            if a in b or b in a:
                return True, f"Your level matches ({wanted})."
        return True, f"This one is for {wanted}."
    if there == here + 1:
        return True, f"{wanted} is the natural next step after your {completed}."
    if there == here:
        return True, f"Your level matches ({wanted})."
    if there < here:
        return True, f"This one is for {wanted}, which you have already passed."
    return (
        False,
        f"This one is for {wanted}; with a {completed} you would normally need "
        "the step in between first.",
    )


class Verdict(str, Enum):
    eligible = "Eligible"
    borderline = "Borderline"
    not_eligible = "Not eligible"


@dataclass
class Eligibility:
    verdict: Verdict
    facts: list[str] = field(default_factory=list)
    missing_fields: list[str] = field(default_factory=list)
    hard_fail: bool = False
    near_miss: bool = False
    unknown: bool = False

    @property
    def order(self) -> int:
        return {
            Verdict.eligible: 0,
            Verdict.borderline: 1,
            Verdict.not_eligible: 2,
        }[self.verdict]


def _fact_value(holder) -> object:
    """Scholarship fields may be a bare value or a Fact carrying provenance."""
    return getattr(holder, "value", holder)


def eligibility(profile: StudentProfile, scholarship: Scholarship) -> Eligibility:
    facts: list[str] = []
    missing: list[str] = []
    hard_fail = False
    near_miss = False
    unknown = False

    # ---------------------------------------------------------- IELTS
    required_band = num(_fact_value(scholarship.min_ielts)) if scholarship.min_ielts else None
    if required_band is not None:
        band = profile.band
        if band is None:
            unknown = True
            missing.append("ieltsBand")
            facts.append(
                f"This one asks for IELTS {_trim(required_band)}. "
                "Add your band and we can tell you properly."
            )
        elif band >= required_band:
            facts.append(f"Your IELTS {_trim(band)} meets the required {_trim(required_band)}.")
        elif required_band - band <= IELTS_NEAR_MISS:
            near_miss = True
            facts.append(
                f"IELTS {_trim(band)} is just under the required {_trim(required_band)}."
            )
        else:
            hard_fail = True
            facts.append(
                f"IELTS {_trim(band)} is below the required {_trim(required_band)}."
            )

    # ------------------------------------------------------------ GPA
    required_gpa = num(_fact_value(scholarship.min_gpa)) if scholarship.min_gpa else None
    if required_gpa is not None:
        gpa = profile.gpa
        if gpa is None:
            unknown = True
            missing.append("result")
            facts.append(
                f"This one asks for a result of at least {_trim(required_gpa)}. "
                "Add yours and we can tell you properly."
            )
        elif gpa >= required_gpa:
            facts.append(f"Your result {_trim(gpa)} meets the required {_trim(required_gpa)}.")
        elif required_gpa - gpa <= GPA_NEAR_MISS:
            near_miss = True
            facts.append(
                f"Your result {_trim(gpa)} is just under the required {_trim(required_gpa)}."
            )
        else:
            hard_fail = True
            facts.append(
                f"Your result {_trim(gpa)} is below the required {_trim(required_gpa)}."
            )

    # ---------------------------------------------------- nationality
    if scholarship.nationalities:
        if not profile.nationality:
            unknown = True
            missing.append("nationality")
            facts.append("This one is limited by nationality. Add yours to check.")
        else:
            mine = normalise_text(profile.nationality)
            listed = [normalise_text(n) for n in scholarship.nationalities]
            if any(mine == n or mine in n or n in mine for n in listed):
                facts.append(f"Open to applicants from {profile.nationality}.")
            else:
                hard_fail = True
                facts.append(
                    f"This one is not open to applicants from {profile.nationality}."
                )

    # --------------------------------------------------------- level
    if scholarship.level:
        if not profile.highest_level:
            # A blank level is ignored rather than counted against them.
            pass
        else:
            fits, note = level_fits(profile.highest_level, scholarship.level)
            if fits:
                facts.append(note)
            else:
                near_miss = True
                facts.append(note)

    # -------------------------------------------------------- verdict
    if hard_fail:
        verdict = Verdict.not_eligible
    elif near_miss or unknown:
        verdict = Verdict.borderline
    else:
        verdict = Verdict.eligible

    if not facts:
        facts.append("No specific requirements were listed that we could check.")

    return Eligibility(
        verdict=verdict,
        facts=facts,
        missing_fields=missing,
        hard_fail=hard_fail,
        near_miss=near_miss,
        unknown=unknown,
    )


def _trim(value: float) -> str:
    """7.0 -> '7', 6.5 -> '6.5'. Students write bands the short way."""
    if value == int(value):
        return str(int(value))
    return f"{value:g}"


# Names to put in a search query, by rung.
_RUNG_NAME = {0: "Foundation", 1: "Higher Secondary", 2: "Bachelors",
              3: "Masters", 4: "PhD"}


def level_in_text(text: str) -> str:
    """The level a student's own words name, if they name one.

    "msc computer science" is a request for a Masters whatever the profile
    says. The student's explicit word is the most reliable signal there
    is, so it beats both the model's guess and the profile.
    """
    rung = _rung(text)
    return _RUNG_NAME.get(rung, "") if rung is not None else ""


def level_to_study(completed: str) -> str:
    """What someone who has finished `completed` would study next.

    The profile records what a student HAS. A course search needs what
    they WANT, and those are one rung apart - reading the first as the
    second is why a Bachelors graduate was shown Bachelors courses.
    """
    here = _rung(completed)
    if here is None:
        return ""
    return _RUNG_NAME.get(min(here + 1, 4), "")