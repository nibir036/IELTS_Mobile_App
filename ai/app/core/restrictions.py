"""Which universities are closed to this student through NextED.

This is the one piece of information in the whole system that cannot be
found on the internet. Universities do not publish it; it is NextED's own
partner information. It is supplied as a file and matched here.

It is also the part that must never be matched by similarity. "Oxford
Brookes University" and "Oxford International Education Group" are two
different organisations with two different rules. A fuzzy match between
them costs a student a year, and they find out in August.

So: exact comparison on a normalised name. Nothing clever.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from enum import Enum

from app.core.numbers import normalise_text
from app.core.profile import StudentProfile

# Words that appear in university names without distinguishing anything.
_NOISE = {"the", "university", "of", "at"}


class RuleKind(str, Enum):
    full = "full"        # closed outright
    partial = "partial"  # closed for the scope this rule names
    check = "check"      # a counsellor has to confirm


class Status(str, Enum):
    open = "open"
    check = "check"
    closed = "closed"


@dataclass(frozen=True)
class RestrictionRule:
    """One row of the partner list."""

    university: str
    kind: RuleKind = RuleKind.check
    campus: str = ""
    open_campus: str = ""
    levels: tuple[str, ...] = ()          # empty means every level
    regions: tuple[str, ...] = ()         # home districts; empty means all
    except_regions: tuple[str, ...] = ()  # districts carved out
    subjects: tuple[str, ...] = ()        # empty means every subject
    intakes: tuple[str, ...] = ()         # empty means every intake
    note: str = ""
    source: str = ""
    as_of: str = ""
    active: bool = True

    @staticmethod
    def from_row(row: dict) -> "RestrictionRule":
        """Accepts either snake_case or the camelCase the Node side uses."""

        def get(*names, default=None):
            for n in names:
                if n in row and row[n] is not None:
                    return row[n]
            return default

        def tup(*names) -> tuple[str, ...]:
            value = get(*names, default=[]) or []
            if isinstance(value, str):
                value = [v for v in value.split(",") if v.strip()]
            return tuple(str(v).strip() for v in value if str(v).strip())

        kind_raw = str(get("kind", default="check") or "check").lower()
        kind = RuleKind(kind_raw) if kind_raw in {k.value for k in RuleKind} else RuleKind.check

        return RestrictionRule(
            university=str(get("university", default="") or ""),
            kind=kind,
            campus=str(get("campus", default="") or ""),
            open_campus=str(get("openCampus", "open_campus", default="") or ""),
            levels=tup("levels"),
            regions=tup("regions"),
            except_regions=tup("exceptRegions", "except_regions"),
            subjects=tup("subjects"),
            intakes=tup("intakes"),
            note=str(get("note", default="") or ""),
            source=str(get("source", default="") or ""),
            as_of=str(get("asOf", "as_of", default="") or ""),
            active=bool(get("active", default=True)),
        )


@dataclass(frozen=True)
class StudentScope:
    """The parts of a student a rule can be scoped by."""

    home_district: str = ""
    level: str = ""
    subject: str = ""
    intake: str = ""

    @staticmethod
    def of(profile: StudentProfile, subject: str = "", level: str = "") -> "StudentScope":
        return StudentScope(
            home_district=profile.home_district,
            level=level or profile.highest_level,
            subject=subject or profile.subject,
            intake=profile.intake,
        )


@dataclass
class RestrictionCheck:
    status: Status = Status.open
    message: str = ""
    detail: str = ""
    needs_counsellor: bool = False
    needs_home_district: bool = False
    matched: list[RestrictionRule] = field(default_factory=list)


# ---------------------------------------------------------------------------
def university_key(name: str) -> str:
    """A name reduced to the words that actually identify it."""
    words = [w for w in normalise_text(name).split() if w not in _NOISE]
    return " ".join(words)


def same_university(a: str, b: str) -> bool:
    """Exact match on the normalised key. Never fuzzy, never 'close enough'."""
    ka, kb = university_key(a), university_key(b)
    return bool(ka) and ka == kb


def _scope_hits(values: tuple[str, ...], candidate: str) -> bool:
    """Does the student's value fall inside this scope list?

    An empty list means the rule is not scoped on this axis, so it applies.
    A non-empty list with a blank student value is handled by the caller -
    it is never silently treated as a match.
    """
    if not values:
        return True
    if not candidate:
        return False
    target = normalise_text(candidate)
    return any(
        target == normalise_text(v)
        or target in normalise_text(v)
        or normalise_text(v) in target
        for v in values
    )


def check_restrictions(
    rules: list[RestrictionRule],
    university: str,
    scope: StudentScope,
) -> RestrictionCheck:
    """Decide open / check / closed for one university and one student."""
    result = RestrictionCheck()
    if not university:
        return result

    relevant = [
        r for r in rules if r.active and same_university(r.university, university)
    ]
    if not relevant:
        # No rule mentions this university, so we hold no partner information
        # saying it is restricted. That is 'open' in the same sense the
        # current build uses it.
        return result

    worst = Status.open
    details: list[str] = []
    matched: list[RestrictionRule] = []
    needs_district = False

    for rule in relevant:
        status = Status.check if rule.kind is RuleKind.check else Status.closed
        applies = True
        unknown_scope = False

        # Level, subject and intake scoping. One rule throughout: if the
        # rule is scoped on an axis and the student's value on that axis is
        # blank, we cannot rule the student in or out - so the answer is
        # 'check', never 'closed' and never a silent skip.
        for axis_values, student_value in (
            (rule.levels, scope.level),
            (rule.subjects, scope.subject),
            (rule.intakes, scope.intake),
        ):
            if not axis_values:
                continue
            if not student_value:
                unknown_scope = True
            elif not _scope_hits(axis_values, student_value):
                applies = False
                break

        if not applies:
            continue

        if rule.regions or rule.except_regions:
            if not scope.home_district:
                # THE RULE THAT MUST NOT BE SOFTENED.
                # We never tell a student a door is shut on a detail we do
                # not have. Missing home district downgrades to 'check'.
                unknown_scope = True
                needs_district = True
            else:
                if _scope_hits(rule.except_regions, scope.home_district):
                    continue  # explicitly carved out
                if rule.regions and not _scope_hits(rule.regions, scope.home_district):
                    continue  # the rule is about other districts

        if unknown_scope:
            status = Status.check

        matched.append(rule)
        if rule.note:
            details.append(rule.note)
        if status is Status.closed and worst is not Status.closed:
            worst = Status.closed
        elif status is Status.check and worst is Status.open:
            worst = Status.check

    if not matched:
        return result

    result.status = worst
    result.matched = matched
    result.needs_home_district = needs_district
    result.detail = " ".join(details).strip()

    if worst is Status.closed:
        # Wording matters here. This is partner information, not published
        # university policy, and it must never be stated as the latter.
        result.message = (
            "Not available through NextED for this intake."
        )
        result.needs_counsellor = True
    elif worst is Status.check:
        result.message = (
            "A counsellor needs to confirm this one for you."
            if not needs_district
            else "We need your home district before we can confirm this one."
        )
        result.needs_counsellor = True

    return result


def restriction_facts(
    rules: list[RestrictionRule],
    universities: list[str],
    scope: StudentScope,
) -> list[str]:
    """Settled-fact lines for the counsellor's prompt.

    Each line is already decided. The model is told not to contradict,
    soften or re-check them.
    """
    lines: list[str] = []
    seen: set[str] = set()
    for name in universities:
        key = university_key(name)
        if not key or key in seen:
            continue
        seen.add(key)
        check = check_restrictions(rules, name, scope)
        if check.status is Status.closed:
            lines.append(f"CLOSED - {name}: {check.message} {check.detail}".strip())
        elif check.status is Status.check:
            lines.append(f"UNCERTAIN - {name}: {check.message} {check.detail}".strip())
    return lines


def universities_in(rules: list[RestrictionRule]) -> list[str]:
    """Every distinct university the partner list mentions."""
    out: list[str] = []
    seen: set[str] = set()
    for rule in rules:
        if not rule.active:
            continue
        key = university_key(rule.university)
        if key and key not in seen:
            seen.add(key)
            out.append(rule.university)
    return out


def mentions(text: str, university: str) -> bool:
    """Does this text really name this university?

    Two traps make a naive substring check dangerous here, and both produce
    the same harm: telling a student a university is closed when the reply
    was about a different one.

      * a shorter name sits inside a longer one - "Example University"
        inside "Example University of Technology"
      * a name sits inside an unrelated word

    So: whole-word matching, and a match is rejected when it runs straight
    on into a longer institution name.
    """
    if not text or not university:
        return False

    words = [w for w in re.split(r"\s+", university.strip()) if w]
    if not words:
        return False

    pattern = r"\b" + r"[\s,]+".join(re.escape(w) for w in words) + r"\b"
    for match in re.finditer(pattern, text, flags=re.IGNORECASE):
        tail = text[match.end(): match.end() + 40]
        # "... University of Technology" is not "... University".
        if re.match(r"\s+of\s+[A-Z]", tail):
            continue
        return True
    return False


def flag_closed(
    reply_text: str,
    rules: list[RestrictionRule],
    scope: StudentScope,
) -> list[dict]:
    """Enforcement, after the model has spoken.

    A prompt is a request. This is the part that cannot be talked out of:
    whatever the model wrote, every restricted university it mentioned is
    surfaced next to the answer.

    Longest names are tested first and their span is then consumed, so a
    rule about "Oxford" can never fire on a reply about "Oxford Brookes".
    """
    found: list[dict] = []
    if not reply_text:
        return found

    remaining = reply_text
    for name in sorted(universities_in(rules), key=len, reverse=True):
        if not mentions(remaining, name):
            continue
        check = check_restrictions(rules, name, scope)
        if check.status is Status.closed:
            found.append(
                {
                    "university": name,
                    "message": check.message,
                    "detail": check.detail,
                }
            )
        # Blank out what we matched so a shorter name cannot match inside it.
        words = [w for w in re.split(r"\s+", name.strip()) if w]
        pattern = r"\b" + r"[\s,]+".join(re.escape(w) for w in words) + r"\b"
        remaining = re.sub(pattern, " ", remaining, flags=re.IGNORECASE)

    return found
