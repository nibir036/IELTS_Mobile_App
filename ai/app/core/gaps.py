"""How far is this student from unlocking more, and is it worth saying?

The rules this file exists to keep honest:

  * state the real distance - "IELTS 6.5 to 7.0", not "improve your English"
  * one gap, not a list of everything wrong with the profile
  * count the unlocks by actually re-running eligibility, never by guessing
  * never personalise an empty profile
"""
from __future__ import annotations

from dataclasses import dataclass, replace

from app.core.catalogue import Scholarship
from app.core.eligibility import Verdict, eligibility
from app.core.numbers import num
from app.core.profile import StudentProfile

_LABEL = {
    "ieltsBand": "IELTS",
    "result": "your result",
    "nationality": "nationality",
}


@dataclass
class Gap:
    field: str
    label: str
    current: float | None
    needed: float | None
    unlocks: int
    message: str


def _with(profile: StudentProfile, field: str, value: str) -> StudentProfile:
    data = profile.model_dump(by_alias=True)
    data[field] = value
    return StudentProfile.model_validate(data)


def _count_eligible(profile: StudentProfile, items: list[Scholarship]) -> int:
    return sum(1 for s in items if eligibility(profile, s).verdict is Verdict.eligible)


def biggest_gap(
    profile: StudentProfile,
    scholarships: list[Scholarship],
) -> Gap | None:
    """The single change that would unlock the most, or None.

    Returns None when the profile is too empty to personalise, when there is
    nothing locked, or when no single change would unlock anything - in all
    three cases saying nothing is better than saying something vague.
    """
    if profile.is_empty() or not scholarships:
        return None

    baseline = _count_eligible(profile, scholarships)
    candidates: list[Gap] = []

    # --- a missing field is a different kind of gap: we cannot even judge.
    #
    # Counting how many it would make ELIGIBLE understates it badly. A
    # student missing two fields would unlock nothing by filling one, and
    # so would be told nothing at all. What filling it really buys them is
    # a definite answer, so that is what we count - and it is still
    # computed by re-running, never estimated.
    for field, attr in (
        ("ieltsBand", "ielts_band"),
        ("result", "result"),
        ("nationality", "nationality"),
    ):
        if profile.has(attr):
            continue
        blocked = sum(
            1 for s in scholarships if field in eligibility(profile, s).missing_fields
        )
        if blocked == 0:
            continue
        label = _LABEL.get(field, field)
        answers = "a definite answer" if blocked == 1 else "definite answers"
        candidates.append(
            Gap(
                field=field,
                label=label,
                current=None,
                needed=None,
                unlocks=blocked,
                message=(
                    f"Add {label} to your profile and we can give you "
                    f"{answers} on {blocked} of these."
                ),
            )
        )

    # --- a numeric shortfall: what is the next threshold worth reaching?
    for field, attr, getter in (
        ("ieltsBand", "ielts_band", lambda s: s.min_ielts),
        ("result", "result", lambda s: s.min_gpa),
    ):
        if not profile.has(attr):
            continue
        current = num(getattr(profile, "band" if field == "ieltsBand" else "gpa"))
        if current is None:
            continue
        thresholds = sorted(
            {
                t
                for t in (
                    num(getattr(getter(s), "value", getter(s))) for s in scholarships
                )
                if t is not None and t > current
            }
        )
        for target in thresholds:
            trial = _with(profile, field, str(target))
            unlocked = _count_eligible(trial, scholarships) - baseline
            if unlocked <= 0:
                continue
            label = _LABEL.get(field, field)
            if field == "ieltsBand":
                msg = (
                    f"{label} {_trim(current)} to {_trim(target)} would unlock "
                    f"{unlocked} more."
                )
            else:
                msg = (
                    f"Raising {label} from {_trim(current)} to {_trim(target)} "
                    f"would unlock {unlocked} more."
                )
            candidates.append(
                Gap(
                    field=field,
                    label=label,
                    current=current,
                    needed=target,
                    unlocks=unlocked,
                    message=msg,
                )
            )
            # Only the nearest useful threshold per field. Listing every rung
            # of the ladder is the "list of everything wrong" we are avoiding.
            break

    if not candidates:
        return None

    # Most unlocked wins; the smaller ask breaks a tie.
    candidates.sort(
        key=lambda g: (-g.unlocks, (g.needed or 0) - (g.current or 0))
    )
    return candidates[0]


def _trim(value: float) -> str:
    if value == int(value):
        return str(int(value))
    return f"{value:g}"
