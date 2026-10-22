"""Scholarship Finding.

load -> understand -> search ours -> (research if thin) -> merge
     -> VERDICT IN CODE -> credit -> phrase -> sort -> gap

By the time the model is called every verdict is already final. Its only
job is turning the facts into readable sentences, and if it fails the raw
facts ship instead.
"""
from __future__ import annotations

from datetime import datetime, timezone

from app.core.eligibility import Verdict
from app.core.freshness import can_state_plainly
from app.core.gaps import biggest_gap
from app.graphs import nodes
from app.graphs.runner import Graph
from app.kb.retrieve import relevant_only, search_scholarships as personal_search

_ORDER = {Verdict.eligible: 0, Verdict.borderline: 1, Verdict.not_eligible: 2}


def _label(row) -> str:
    if getattr(row, "verified_by_staff", False):
        return "VERIFIED"
    source = getattr(row, "source", None)
    if source is None:
        return "UNCONFIRMED"
    age = (datetime.now(timezone.utc) - source.fetched_at).total_seconds()
    return "FOUND JUST NOW" if age < 300 else "FROM THE PROVIDER'S PAGE"


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
    phrased = state.get("phrased") or {}
    pairs = state.get("eligibility_pairs") or []

    rows = []
    for row, result in pairs:
        rows.append(
            {
                "id": row.id,
                "title": row.title,
                "provider": row.provider,
                "country": row.country,
                "level": row.level,
                "amount": _fact_out(row.amount),
                "deadline": _fact_out(row.deadline),
                "officialUrl": row.official_url,
                "sourceLabel": _label(row),
                "verdict": result.verdict.value,
                # A failed phrasing never loses a verdict.
                "reasons": phrased.get(row.id) or result.facts,
                "missingFields": result.missing_fields,
                "_order": _ORDER[result.verdict],
            }
        )

    rows.sort(key=lambda r: r["_order"])
    for row in rows:
        row.pop("_order", None)

    gap = biggest_gap(state["profile"], list(state.get("candidates") or []))
    return {
        "results": rows,
        "gap": (
            {
                "field": gap.field,
                "message": gap.message,
                "unlocks": gap.unlocks,
            }
            if gap
            else None
        ),
    }


def build() -> Graph:
    graph = Graph("scholarships")
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
    graph.add("compute_eligibility", nodes.compute_eligibility)
    graph.add("check_quota", nodes.check_quota)
    graph.add("phrase", nodes.phrase)
    graph.add("assemble", _assemble)
    return graph
