"""Where discovered rows live until PostgreSQL arrives.

JSON files on disk, loaded once and written back when something changes.
The interface is what the Postgres version will have to provide, so moving
over later is a swap of this one class.

The daily cap lives here too, with the Asia/Dhaka day logic carried over
from the current build: if the stored date is not today's Dhaka date the
count is treated as zero, so nothing has to run at midnight.
"""
from __future__ import annotations

import json
import logging
import pathlib
import threading
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

from app.core.catalogue import Course, Scholarship, Source
from app.core.freshness import Fact, FieldClass
from app.core.restrictions import RestrictionRule, university_key

log = logging.getLogger(__name__)

DHAKA = timezone(timedelta(hours=6))  # UTC+6, no daylight saving


def dhaka_day(now: datetime | None = None) -> str:
    return (now or datetime.now(timezone.utc)).astimezone(DHAKA).strftime("%Y-%m-%d")


def next_reset(now: datetime | None = None) -> datetime:
    local = (now or datetime.now(timezone.utc)).astimezone(DHAKA)
    tomorrow = (local + timedelta(days=1)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return tomorrow.astimezone(timezone.utc)


@dataclass
class AiUsage:
    used: int
    limit: int
    left: int
    resets_at: str

    def as_dict(self) -> dict:
        return {
            "used": self.used,
            "limit": self.limit,
            "left": self.left,
            "resetsAt": self.resets_at,
        }


# --------------------------------------------------------------- (de)serialise
def _fact_to_json(fact: Fact | None) -> dict | None:
    if fact is None:
        return None
    return {
        "value": fact.value,
        "field_class": fact.field_class.value,
        "source_url": fact.source_url,
        "evidence": fact.evidence,
        "checked_at": fact.checked_at.isoformat() if fact.checked_at else None,
        "confirmed_unchanged_at": (
            fact.confirmed_unchanged_at.isoformat()
            if fact.confirmed_unchanged_at
            else None
        ),
    }


def _fact_from_json(raw: dict | None) -> Fact | None:
    if not raw:
        return None

    def when(key: str):
        value = raw.get(key)
        return datetime.fromisoformat(value) if value else None

    return Fact(
        value=raw.get("value"),
        field_class=FieldClass(raw.get("field_class", "descriptive")),
        source_url=raw.get("source_url", ""),
        evidence=raw.get("evidence", ""),
        checked_at=when("checked_at"),
        confirmed_unchanged_at=when("confirmed_unchanged_at"),
    )


def _source_to_json(source: Source | None) -> dict | None:
    if source is None:
        return None
    return {
        "url": source.url,
        "fetched_at": source.fetched_at.isoformat(),
        "title": source.title,
        "content_hash": source.content_hash,
        "extractor": getattr(source, "extractor", 0),
    }


def _source_from_json(raw: dict | None) -> Source | None:
    if not raw:
        return None
    return Source(
        url=raw.get("url", ""),
        fetched_at=datetime.fromisoformat(raw["fetched_at"])
        if raw.get("fetched_at")
        else datetime.now(timezone.utc),
        title=raw.get("title", ""),
        content_hash=raw.get("content_hash", ""),
        # absent on rows written before versioning, which is exactly the
        # set of rows that need re-reading, so 0 is the right default
        extractor=int(raw.get("extractor", 0) or 0),
    )


def course_to_json(c: Course) -> dict:
    return {
        "id": c.id, "title": c.title, "university": c.university,
        "country": c.country, "level": c.level, "subject": c.subject,
        "duration": c.duration, "intake": c.intake,
        "tuition": _fact_to_json(c.tuition),
        "min_ielts": _fact_to_json(c.min_ielts),
        "min_gpa": _fact_to_json(c.min_gpa),
        "deadline": _fact_to_json(c.deadline),
        "official_url": c.official_url,
        "source": _source_to_json(c.source),
        "verified_by_staff": c.verified_by_staff,
    }


def course_from_json(raw: dict) -> Course:
    return Course(
        id=raw.get("id") or uuid.uuid4().hex,
        title=raw.get("title", ""), university=raw.get("university", ""),
        country=raw.get("country", ""), level=raw.get("level", ""),
        subject=raw.get("subject", ""), duration=raw.get("duration", ""),
        intake=raw.get("intake", ""),
        tuition=_fact_from_json(raw.get("tuition")),
        min_ielts=_fact_from_json(raw.get("min_ielts")),
        min_gpa=_fact_from_json(raw.get("min_gpa")),
        deadline=_fact_from_json(raw.get("deadline")),
        official_url=raw.get("official_url", ""),
        source=_source_from_json(raw.get("source")),
        verified_by_staff=bool(raw.get("verified_by_staff")),
    )


def scholarship_to_json(s: Scholarship) -> dict:
    return {
        "id": s.id, "title": s.title, "provider": s.provider,
        "country": s.country, "level": s.level,
        "amount": _fact_to_json(s.amount),
        "deadline": _fact_to_json(s.deadline),
        "min_ielts": _fact_to_json(s.min_ielts),
        "min_gpa": _fact_to_json(s.min_gpa),
        "nationalities": list(s.nationalities),
        "official_url": s.official_url,
        "source": _source_to_json(s.source),
        "verified_by_staff": s.verified_by_staff,
    }


def scholarship_from_json(raw: dict) -> Scholarship:
    return Scholarship(
        id=raw.get("id") or uuid.uuid4().hex,
        title=raw.get("title", ""), provider=raw.get("provider", ""),
        country=raw.get("country", ""), level=raw.get("level", ""),
        amount=_fact_from_json(raw.get("amount")),
        deadline=_fact_from_json(raw.get("deadline")),
        min_ielts=_fact_from_json(raw.get("min_ielts")),
        min_gpa=_fact_from_json(raw.get("min_gpa")),
        nationalities=tuple(raw.get("nationalities") or ()),
        official_url=raw.get("official_url", ""),
        source=_source_from_json(raw.get("source")),
        verified_by_staff=bool(raw.get("verified_by_staff")),
    )


# ------------------------------------------------------------------- the store
@dataclass
class Store:
    data_dir: pathlib.Path
    daily_limit: int = 30

    courses: dict[str, Course] = field(default_factory=dict)
    scholarships: dict[str, Scholarship] = field(default_factory=dict)
    rules: list[RestrictionRule] = field(default_factory=list)
    usage: dict[str, dict] = field(default_factory=dict)
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    # -------------------------------------------------------------- loading
    @classmethod
    def open(
        cls,
        data_dir: str | pathlib.Path,
        restrictions_file: str | pathlib.Path = "",
        seed_dir: str | pathlib.Path = "",
        daily_limit: int = 30,
    ) -> "Store":
        directory = pathlib.Path(data_dir)
        directory.mkdir(parents=True, exist_ok=True)
        store = cls(data_dir=directory, daily_limit=daily_limit)

        store.courses = {
            c.id: c for c in store._tidy(
                store._read_list("courses.json", course_from_json)
            )
        }
        store.scholarships = {
            s.id: s for s in store._read_list("scholarships.json", scholarship_from_json)
        }
        store.usage = store._read_dict("usage.json")

        # A seed directory is optional - it is only a convenience for trying
        # the service out. The catalogue normally fills itself.
        if seed_dir and not store.courses and not store.scholarships:
            store._load_seed(pathlib.Path(seed_dir))

        if restrictions_file:
            store.load_restrictions(restrictions_file)
        return store

    @staticmethod
    def _tidy(rows: list) -> list:
        """Apply today's rules to rows stored under yesterday's.

        A catalogue that fills itself keeps whatever it was given at the
        time, so a rule added later never reaches the rows already in it:
        three page-title rows and one guide article stayed in the results
        for every future student. Rules that only decide what a row IS -
        not what it says - can be re-applied safely on the way in.

        Nothing is rewritten on disk here. A row dropped now is simply not
        offered; if it is still out there, research will find it again and
        store it correctly.
        """
        from app.core.eligibility import level_in_text
        from app.tools.extract import clean_title, looks_like_an_article

        kept, dropped, tidied, levelled = [], 0, 0, 0
        for row in rows:
            source = getattr(row, "source", None)
            url = getattr(source, "url", "") or getattr(row, "official_url", "")
            title = clean_title(row.title, getattr(row, "university", ""))
            if looks_like_an_article(title, url):
                dropped += 1
                continue
            if title != row.title:
                row.title = title
                tidied += 1
            # "MSc Computer Science" states its own level. A row stored
            # before that was read still has it in the title.
            if not getattr(row, "level", "") and hasattr(row, "level"):
                level = level_in_text(title)
                if level:
                    row.level = level
                    levelled += 1
            kept.append(row)

        if dropped or tidied or levelled:
            log.info(
                "catalogue tidied on load: %s title(s) cleaned, %s level(s) "
                "filled in, %s row(s) dropped as not a course",
                tidied, levelled, dropped,
            )
        return kept

    def _read_list(self, name: str, parse) -> list:
        path = self.data_dir / name
        if not path.exists():
            return []
        try:
            return [parse(r) for r in json.loads(path.read_text(encoding="utf-8"))]
        except (OSError, json.JSONDecodeError, TypeError) as exc:
            log.warning("could not read %s: %s", name, exc)
            return []

    def _read_dict(self, name: str) -> dict:
        path = self.data_dir / name
        if not path.exists():
            return {}
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}

    def _load_seed(self, seed: pathlib.Path) -> None:
        for name, parse, target in (
            ("courses.json", course_from_json, self.courses),
            ("scholarships.json", scholarship_from_json, self.scholarships),
        ):
            path = seed / name
            if not path.exists():
                continue
            try:
                for raw in json.loads(path.read_text(encoding="utf-8")):
                    row = parse(raw)
                    target[row.id] = row
            except (OSError, json.JSONDecodeError, TypeError) as exc:
                log.warning("could not read seed %s: %s", name, exc)

    def load_restrictions(self, path: str | pathlib.Path) -> int:
        """The one file that has to come from nextED."""
        file = pathlib.Path(path)
        if not file.exists():
            log.warning(
                "No restriction list at %s - restriction checking is OFF until "
                "one is supplied.", file,
            )
            self.rules = []
            return 0
        try:
            raw = json.loads(file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            log.error("could not read the restriction list: %s", exc)
            self.rules = []
            return 0
        if isinstance(raw, dict):
            raw = raw.get("rules") or raw.get("restrictions") or []
        self.rules = [RestrictionRule.from_row(r) for r in raw if isinstance(r, dict)]
        log.info("loaded %s restriction rule(s)", len(self.rules))
        return len(self.rules)

    @property
    def restrictions_active(self) -> bool:
        return bool(self.rules)

    # -------------------------------------------------------------- writing
    def _write(self, name: str, payload) -> None:
        path = self.data_dir / name
        tmp = path.with_suffix(".tmp")
        try:
            tmp.write_text(
                json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8"
            )
            tmp.replace(path)
        except OSError as exc:
            log.warning("could not write %s: %s", name, exc)

    def save_courses(self) -> None:
        self._write("courses.json", [course_to_json(c) for c in self.courses.values()])

    def save_scholarships(self) -> None:
        self._write(
            "scholarships.json",
            [scholarship_to_json(s) for s in self.scholarships.values()],
        )

    def save_usage(self) -> None:
        self._write("usage.json", self.usage)

    # ------------------------------------------------------------ catalogue
    def course_key(self, course: Course) -> str:
        from app.core.numbers import normalise_text

        return f"{university_key(course.university)}|{normalise_text(course.title)}"

    def upsert_course(self, course: Course) -> Course:
        """Merge by university+title so re-reading a page updates, not duplicates."""
        with self._lock:
            key = self.course_key(course)
            for existing in self.courses.values():
                if self.course_key(existing) == key:
                    for name in ("tuition", "min_ielts", "min_gpa", "deadline"):
                        new = getattr(course, name)
                        if new is not None:
                            setattr(existing, name, new)
                    existing.official_url = course.official_url or existing.official_url
                    existing.source = course.source or existing.source
                    return existing
            self.courses[course.id] = course
            return course

    def upsert_scholarship(self, item: Scholarship) -> Scholarship:
        from app.core.numbers import normalise_text

        with self._lock:
            key = normalise_text(item.title)
            for existing in self.scholarships.values():
                if normalise_text(existing.title) == key:
                    for name in ("amount", "min_ielts", "min_gpa", "deadline"):
                        new = getattr(item, name)
                        if new is not None:
                            setattr(existing, name, new)
                    existing.official_url = item.official_url or existing.official_url
                    existing.source = item.source or existing.source
                    if item.nationalities:
                        existing.nationalities = item.nationalities
                    return existing
            self.scholarships[item.id] = item
            return item

    def find_by_content_hash(self, content_hash: str, kind: str):
        """A row we built from this exact page content, unchanged since.

        When this hits, the page has not changed since we last read it, so
        there is nothing to re-extract - the most valuable saving available,
        because it removes a model call entirely at no cost to accuracy.
        """
        from app.tools.extract import EXTRACTOR_VERSION

        if not content_hash:
            return None
        rows = self.courses if kind == "course" else self.scholarships
        for row in rows.values():
            if not row.source or row.source.content_hash != content_hash:
                continue
            # Same page, older rules. Re-read it: the saving is not worth
            # serving a row we now know was built wrongly, and the page
            # will not change just because our reading of it did.
            if getattr(row.source, "extractor", 0) < EXTRACTOR_VERSION:
                log.info(
                    "re-reading %s: stored under extractor v%s, now v%s",
                    row.source.url, getattr(row.source, "extractor", 0),
                    EXTRACTOR_VERSION,
                )
                return None
            return row
        return None

    # ---------------------------------------------------------- daily cap
    def read_usage(self, student_id: str, now: datetime | None = None) -> AiUsage:
        """Read only - never spends anything."""
        row = self.usage.get(student_id) or {}
        used = int(row.get("used", 0)) if row.get("day") == dhaka_day(now) else 0
        return AiUsage(
            used=used,
            limit=self.daily_limit,
            left=max(0, self.daily_limit - used),
            resets_at=next_reset(now).isoformat(),
        )

    def consume_ai(self, student_id: str, now: datetime | None = None) -> AiUsage:
        """Check and increment.

        Called inside the handler immediately before the first model call,
        after the database work - so a search that never reaches a model
        does not cost the student a credit.
        """
        from app.errors import AiLimitReached

        with self._lock:
            today = dhaka_day(now)
            row = self.usage.get(student_id) or {}
            used = int(row.get("used", 0)) if row.get("day") == today else 0
            # 0 = no daily limit (still counted, never refused).
            if self.daily_limit > 0 and used >= self.daily_limit:
                usage = AiUsage(
                    used=used, limit=self.daily_limit, left=0,
                    resets_at=next_reset(now).isoformat(),
                )
                raise AiLimitReached(usage=usage.as_dict())
            used += 1
            self.usage[student_id] = {"day": today, "used": used}
        self.save_usage()
        return AiUsage(
            used=used,
            limit=self.daily_limit,
            left=max(0, self.daily_limit - used),
            resets_at=next_reset(now).isoformat(),
        )