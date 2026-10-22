"""Course Finding.

load -> understand -> search ours -> (research if thin) -> merge
     -> restrictions in code -> credit -> rank -> validate -> sort & label
"""
from __future__ import annotations

from datetime import datetime, timezone

from app.core.freshness import can_state_plainly
from app.core.restrictions import Status
from app.graphs import nodes
from app.graphs.runner import Graph
from app.kb.retrieve import relevant_only, search_courses as personal_search

# Closed sorts last, but is never hidden: a student who had that university
# in mind and cannot find it concludes the app is broken.
_RANK = {Status.open: 0, Status.check: 1, Status.closed: 2}


def _label(row) -> str:
    if getattr(row, "verified_by_staff", False):
        return "VERIFIED"
    source = getattr(row, "source", None)
    if source is None:
        return "UNCONFIRMED"
    age = (datetime.now(timezone.utc) - source.fetched_at).total_seconds()
    return "FOUND JUST NOW" if age < 300 else "FROM THE UNIVERSITY'S PAGE"


def _fact_out(fact) -> dict | None:
    if fact is None:
        return None
    confirmed = can_state_plainly(fact)
    return {
        "value": fact.value,
        "confirmed": confirmed,
        "sourceUrl": fact.source_url,
        "note": "" if confirmed else "Please check this on their page - it may have changed.",
    }


async def _assemble(state: dict) -> dict:
    ranking = state.get("ranking") or {}
    pairs = state.get("restricted_pairs") or []

    rows = []
    for row, check in pairs:
        scored = ranking.get(row.id, {})
        rows.append(
            {
                "id": row.id,
                "title": row.title,
                "university": row.university,
                "country": row.country,
                "level": row.level,
                "subject": row.subject,
                "duration": row.duration,
                "intake": row.intake,
                "tuition": _fact_out(row.tuition),
                "minIelts": _fact_out(row.min_ielts),
                "deadline": _fact_out(row.deadline),
                "officialUrl": row.official_url,
                "sourceLabel": _label(row),
                "confidence": scored.get("confidence", 0),
                "why": scored.get("why", ""),
                "restriction": {
                    "status": check.status.value,
                    "message": check.message,
                    "detail": check.detail,
                    "needsCounsellor": check.needs_counsellor,
                },
                "_rank": _RANK.get(check.status, 0),
            }
        )

    rows.sort(key=lambda r: (r["_rank"], -r["confidence"]))
    # The same programme read from two pages (course directory + department
    # page) is one course to the student: keep the best-ranked copy.
    unique, seen = [], set()
    for row in rows:
        row.pop("_rank", None)
        key = (" ".join(str(row.get("title", "")).lower().split()),
               " ".join(str(row.get("university", "")).lower().split()))
        if key in seen:
            continue
        seen.add(key)
        unique.append(row)

    return {"results": unique[:12]}


def build() -> Graph:
    graph = Graph("courses")
    graph.add("load_context", nodes.load_context)
    graph.add("understand", nodes.understand)
    graph.add(
        "search_local",
        personal_search,  # keywords + this student's vector search
        router=nodes.route_after_local_search,
    )
    graph.add("plan_searches", nodes.plan_searches)
    graph.add("research", nodes.research)
    graph.add("merge", nodes.merge)
    # Off-subject or wrong-level rows never reach the student.
    graph.add("relevant_only", relevant_only)
    graph.add("apply_restrictions", nodes.apply_restrictions)
    graph.add("check_quota", nodes.check_quota)
    graph.add("rank", nodes.rank)
    graph.add("assemble", _assemble)
    return graph
