"""The three features, callable without FastAPI.

The API routers are thin wrappers over these three functions. Keeping them
separate is what lets the whole service be tested with nothing installed
but pydantic - and it means the Node side could import this directly if it
ever ran Python.
"""
from __future__ import annotations

import asyncio
import logging
from typing import AsyncIterator

from app.config import Settings
from app.core.budget import ResearchBudget
from app.core.profile import StudentProfile
from app.graphs import counsellor as counsellor_graph
from app.graphs import courses as courses_graph
from app.graphs import scholarships as scholarships_graph
from app.store.json_store import Store
from app.tracing import span

log = logging.getLogger(__name__)


class Counsellor:
    """Holds the wiring. Built once at startup."""

    def __init__(
        self,
        settings: Settings,
        store: Store,
        llm,
        web_search,
        fetcher,
        kb=None,
        embedder=None,
    ) -> None:
        self.settings = settings
        self.store = store
        self.llm = llm
        self.web_search = web_search
        self.fetcher = fetcher
        self.kb = kb              # PostgreSQL + pgvector, or None
        self.embedder = embedder
        self._bg: set[asyncio.Task] = set()
        self._counsellor = counsellor_graph.build()
        self._courses = courses_graph.build()
        self._scholarships = scholarships_graph.build()

    # ------------------------------------------------------------------
    def _budget(self) -> ResearchBudget:
        return ResearchBudget(
            max_searches=self.settings.max_searches,
            max_fetches=self.settings.max_fetches,
            max_seconds=self.settings.max_research_seconds,
        )

    def _base_state(self, student_id: str, profile: StudentProfile) -> dict:
        return {
            "student_id": student_id,
            "profile": profile,
            "store": self.store,
            "llm": self.llm,
            "web_search": self.web_search,
            "fetcher": self.fetcher,
            "kb": self.kb if (self.kb and self.kb.ready) else None,
            "embedder": self.embedder,
            "settings": self.settings,
            "budget": self._budget(),
            "research_enabled": (
                self.settings.research_enabled
                and getattr(self.web_search, "name", "none") != "none"
            ),
        }

    def _office(self) -> dict:
        s = self.settings
        return {
            "name": s.office_name,
            "address": s.office_address,
            "phoneDisplay": s.office_phone_display,
            "telLink": f"tel:{s.office_phone_e164}",
            "mapsUrl": s.office_maps_url,
        }

    # ------------------------------------------------- knowledge base upkeep
    def _later(self, coro) -> None:
        """Run database upkeep after the answer has gone, never in its way."""
        task = asyncio.create_task(coro)
        self._bg.add(task)
        task.add_done_callback(self._bg.discard)

    async def _after_search(self, student_id: str, kind: str, query: str, rows: list[dict]) -> None:
        kb = self.kb
        if not kb or not kb.ready:
            return
        try:
            from app.kb.ingest import sync_store

            # Whatever research found goes into PostgreSQL with a vector,
            # so the next student (and every other process) has it.
            await sync_store(kb, self.store, self.embedder)
            await kb.record_search(student_id, kind, query, [r.get("id", "") for r in rows])
        except Exception as exc:  # noqa: BLE001
            log.warning("knowledge base upkeep failed: %s", exc)

    async def _remember(self, student_id: str, message: str, reply: str, meta: dict | None = None) -> None:
        """Save the exchange to the student's one thread (before answering,
        so a quick next message already sees it), then refresh the long-term
        memory in the background."""
        kb = self.kb
        if not kb or not kb.ready:
            return
        try:
            await kb.add_message(student_id, "student", message)
            if reply:
                await kb.add_message(student_id, "counsellor", reply, meta or {})
        except Exception as exc:  # noqa: BLE001
            log.warning("saving the conversation failed: %s", exc)
            return
        self._later(self._update_memory(student_id))

    # Long-term memory: the counsellor reads the last 14 messages word for
    # word; once more than this many older ones pile up, they are folded
    # into a running summary that is kept for good.
    MEMORY_KEEP_RECENT = 14
    MEMORY_FOLD_AT = 10

    async def _update_memory(self, student_id: str) -> None:
        kb = self.kb
        try:
            summary, upto = await kb.memory(student_id)
            newer = await kb.messages_after(student_id, upto, limit=200)
            older = newer[: max(0, len(newer) - self.MEMORY_KEEP_RECENT)]
            if len(older) < self.MEMORY_FOLD_AT:
                return
            transcript = "\n".join(
                f"{'Student' if m['role'] in ('student', 'user') else 'Counsellor'}: {m['content'][:1200]}"
                for m in older
            )
            data = await self.llm.complete_json(
                "You keep a nextED counsellor's long-term notes about one student. Merge the "
                "existing notes with the new conversation. Keep: goals, preferred countries, "
                "subjects and levels, results and scores mentioned, budget or funding concerns, "
                "decisions made, worries, what nextED suggested, and open next steps. Drop "
                "small talk. Plain short bullet lines, under 220 words. Return JSON {\"summary\": \"...\"}.",
                f"Existing notes:\n{summary or '(none)'}\n\nNew conversation:\n{transcript}",
                {"type": "object", "properties": {"summary": {"type": "string"}}, "required": ["summary"]},
                fast=True, label="memory",
            )
            text = str((data or {}).get("summary") or "").strip()
            if text:
                await kb.save_memory(student_id, text, int(older[-1]["id"]))
                log.info("long-term memory updated (%s messages folded)", len(older))
        except Exception as exc:  # noqa: BLE001
            log.info("memory update skipped: %s", type(exc).__name__)

    async def thread(self, student_id: str) -> dict:
        """The student's saved conversation, for the app to show on open."""
        kb = self.kb
        if not kb or not kb.ready:
            return {"messages": [], "saved": False}
        rows = await kb.thread(student_id)
        return {"messages": rows, "saved": True}

    async def clear_thread(self, student_id: str) -> dict:
        if self.kb and self.kb.ready:
            await self.kb.clear_thread(student_id)
        return {"cleared": True}

    def _with_debug(self, out: dict, result: dict) -> dict:
        """Outside production: how the answer was reached, for testing."""
        if self.settings.is_production:
            return out
        from app.kb.retrieve import topic_words

        c = result.get("constraints") or {}
        out["debug"] = {
            "understood": {k: c.get(k) for k in ("subject", "level", "country", "keywords") if c.get(k)},
            "topic": topic_words(result),
            "searchTier": result.get("search_tier", ""),
            "planned": [q.get("query") for q in result.get("planned_queries") or []],
            "research": result.get("budget_summary") or {},
        }
        return out

    def _usage(self, state: dict, student_id: str) -> dict:
        # A fixed reply spends no credit, so read rather than assume.
        return state.get("usage") or self.store.read_usage(student_id).as_dict()

    # ------------------------------------------------------- 1. counsellor
    async def counsellor(
        self,
        student_id: str,
        profile: StudentProfile,
        message: str,
        history: list[dict] | None = None,
    ) -> dict:
        state = self._base_state(student_id, profile)
        state.update({"message": message, "history": history or [], "query": message})

        with span("counsellor", student="[redacted]"):
            result = await self._counsellor.run(state)
        body = self._counsellor_body(result, profile, student_id)
        await self._remember(student_id, message, result.get("reply", ""), self._meta(body))
        return body

    @staticmethod
    def _meta(body: dict) -> dict:
        """What the app should still see next to this reply after a reload."""
        meta = {}
        if body.get("profileUpdates"):
            meta["profileUpdates"] = body["profileUpdates"]
            meta["profileUpdateLabels"] = body.get("profileUpdateLabels") or {}
        if body.get("office"):
            meta["office"] = body["office"]
        if body.get("actions"):
            meta["actions"] = body["actions"]
        return meta

    def _counsellor_body(self, result: dict, profile: StudentProfile, student_id: str) -> dict:
        body = {
            "reply": result.get("reply", ""),
            "restricted": result.get("restricted", []),
            "needsHomeDistrict": bool(
                not profile.home_district and self.store.restrictions_active
            ),
            "usage": self._usage(result, student_id),
            "disclaimer": self.settings.disclaimer,
        }
        if result.get("show_contact"):
            body["office"] = self._office()
        if result.get("actions"):
            # Buttons the app draws under the reply: course_finder,
            # scholarship_finder, complete_profile, call_office, office_location.
            body["actions"] = list(result["actions"])
        if result.get("profile_updates"):
            # Validated in the tool; the API server writes them to the
            # student's profile and the app shows "saved to your profile".
            from app.graphs.counsellor_tools import LABELS, missing_fields

            body["profileUpdates"] = dict(result["profile_updates"])
            body["profileUpdateLabels"] = {k: LABELS.get(k, k) for k in result["profile_updates"]}
            body["profileComplete"] = not missing_fields(result.get("profile") or profile, result["profile_updates"])
        return body

    async def counsellor_stream(
        self,
        student_id: str,
        profile: StudentProfile,
        message: str,
        history: list[dict] | None = None,
    ) -> AsyncIterator[tuple[str, object]]:
        """Same as counsellor(), but yields ("token", text) while the reply
        is being written, then ("done", body) with everything else."""
        state = self._base_state(student_id, profile)
        state.update({"message": message, "history": history or [], "query": message})
        result: dict = {}
        with span("counsellor", student="[redacted]"):
            async for kind, value in self._counsellor.stream(state):
                if kind == "token":
                    yield ("token", value)
                else:
                    result = value  # type: ignore[assignment]
        body = self._counsellor_body(result, profile, student_id)
        await self._remember(student_id, message, result.get("reply", ""), self._meta(body))
        yield ("done", body)

    # ----------------------------------------------------------- 2. courses
    async def courses(
        self, student_id: str, profile: StudentProfile, query: str = ""
    ) -> dict:
        state = self._base_state(student_id, profile)
        state.update({"query": query, "kind": "course"})

        with span("courses", student="[redacted]"):
            result = await self._courses.run(state)
        self._later(self._after_search(student_id, "course", query, result.get("results", [])))

        out = {
            "courses": result.get("results", []),
            "searchNote": result.get("search_note", ""),
            "needsHomeDistrict": bool(result.get("needs_home_district")),
            "sources": result.get("sources", []),
            "changes": result.get("changes", []),
            "researchNote": result.get("budget_note", ""),
            "usage": self._usage(result, student_id),
            "disclaimer": self.settings.disclaimer,
        }
        return self._with_debug(out, result)

    # ------------------------------------------------------ 3. scholarships
    async def scholarships(
        self, student_id: str, profile: StudentProfile, query: str = ""
    ) -> dict:
        state = self._base_state(student_id, profile)
        state.update({"query": query, "kind": "scholarship"})

        with span("scholarships", student="[redacted]"):
            result = await self._scholarships.run(state)
        self._later(self._after_search(student_id, "scholarship", query, result.get("results", [])))

        out = {
            "scholarships": result.get("results", []),
            "searchNote": result.get("search_note", ""),
            "gap": result.get("gap"),
            "sources": result.get("sources", []),
            "changes": result.get("changes", []),
            "researchNote": result.get("budget_note", ""),
            "usage": self._usage(result, student_id),
            "disclaimer": self.settings.disclaimer,
        }
        return self._with_debug(out, result)
