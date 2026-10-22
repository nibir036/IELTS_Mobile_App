"""End-to-end tests for the three features.

No FastAPI, no network, no API key. A scripted model and a fake fetcher
stand in, which means these run anywhere and assert exact outcomes.
"""
from __future__ import annotations

import asyncio
import json
import pathlib
import shutil
import tempfile

from app.api.service import Counsellor
from app.config import Settings
from app.core.catalogue import Course, Scholarship, Source, make_fact
from app.core.profile import StudentProfile
from app.store.json_store import Store
from app.tools.fetch import FakePageFetcher, FetchPolicy, html_to_text, url_is_safe
from app.tools.search_web import FakeWebSearch, SearchHit

ROOT = pathlib.Path(__file__).resolve().parents[1]
PAGES = ROOT / "examples" / "pages"


# ------------------------------------------------------------- scripted model
from app.providers.demo import DemoLLM as ScriptedLLM  # noqa: E402


# ------------------------------------------------------------------- harness
def _settings(tmp: str, **kw) -> Settings:
    base = dict(
        app_env="test",
        data_dir=tmp,
        seed_dir="",
        restrictions_file=str(ROOT / "examples" / "restrictions.sample.json"),
        daily_ai_limit=30,
        research_enabled=True,
        allowed_domains=("example.ac.uk",),
        max_searches=2,
        max_fetches=3,
    )
    base.update(kw)
    return Settings(**base)


def _build(tmp: str, llm=None, search=None, **kw) -> Counsellor:
    settings = _settings(tmp, **kw)
    store = Store.open(
        settings.data_dir,
        settings.restrictions_file,
        settings.seed_dir,
        settings.daily_ai_limit,
    )
    fetcher = FakePageFetcher(
        directory=PAGES,
        mapping={
            "https://example.ac.uk/ai": "course-good.html",
            "https://example.ac.uk/business": "course-vague.html",
            "https://example.ac.uk/scholarship": "scholarship.html",
        },
    )
    web = search or FakeWebSearch(
        results={"*": [SearchHit(url="https://example.ac.uk/ai", title="MSc AI")]}
    )
    return Counsellor(settings, store, llm or ScriptedLLM(), web, fetcher)


def _profile(name: str) -> StudentProfile:
    raw = json.loads((ROOT / "examples" / "students" / f"{name}.json").read_text())
    return StudentProfile.model_validate(raw)


def _run(coro):
    return asyncio.run(coro)


class _Tmp:
    def __enter__(self):
        self.path = tempfile.mkdtemp()
        return self.path

    def __exit__(self, *exc):
        shutil.rmtree(self.path, ignore_errors=True)


# ============================================================ the fetch gate
def test_the_gate_refuses_anything_off_the_allowlist():
    policy = FetchPolicy(allowed_domains=("ac.uk",))
    ok, why = url_is_safe("https://evil.com/page", policy)
    assert not ok and "allowlist" in why


def test_the_gate_is_not_fooled_by_a_lookalike_domain():
    policy = FetchPolicy(allowed_domains=("ac.uk",))
    ok, _ = url_is_safe("https://evil-ac.uk.attacker.com/page", policy)
    assert not ok


def test_the_gate_refuses_plain_http():
    policy = FetchPolicy(allowed_domains=("ac.uk",))
    ok, why = url_is_safe("http://bristol.ac.uk/x", policy)
    assert not ok and "https" in why


def test_the_gate_blocks_internal_addresses():
    policy = FetchPolicy(allowed_domains=("localhost", "ac.uk"))
    ok, why = url_is_safe("https://localhost/admin", policy)
    assert not ok and "public" in why


def test_html_becomes_readable_text():
    html = (ROOT / "examples" / "pages" / "course-good.html").read_text()
    text = html_to_text(html)
    assert "IELTS score of 6.5" in text
    assert "<p>" not in text
    assert "£24,500" in text


# ========================================================= course finding
def test_courses_researches_when_we_hold_nothing():
    with _Tmp() as tmp:
        service = _build(tmp)
        assert len(service.store.courses) == 0

        out = _run(service.courses("s1", _profile("strong"), "msc artificial intelligence"))

        assert out["courses"], "should have gone and found something"
        first = out["courses"][0]
        assert first["title"] == "MSc Artificial Intelligence"
        assert first["sourceLabel"] == "FOUND JUST NOW"
        assert first["officialUrl"] == "https://example.ac.uk/ai"
        # read off the page, with its evidence
        assert first["minIelts"]["value"] == 6.5
        assert first["minIelts"]["confirmed"] is True
        assert first["deadline"]["value"] == "2027-01-15"


def test_what_was_found_is_written_back_for_the_next_student():
    with _Tmp() as tmp:
        service = _build(tmp)
        _run(service.courses("s1", _profile("strong"), "msc artificial intelligence"))
        assert len(service.store.courses) == 1

        # a second service over the same directory starts with it already there
        again = _build(tmp)
        assert len(again.store.courses) == 1
        assert next(iter(again.store.courses.values())).title == "MSc Artificial Intelligence"


def test_an_invented_requirement_is_thrown_away():
    """The vague page states no IELTS score. The model claims one anyway."""
    with _Tmp() as tmp:
        search = FakeWebSearch(
            results={"*": [SearchHit(url="https://example.ac.uk/business", title="MA")]}
        )
        service = _build(tmp, search=search)
        out = _run(service.courses("s1", _profile("borderline"), "business management"))

        assert out["courses"]
        course = out["courses"][0]
        assert course["title"] == "MA Business Management"
        # the course survives; the unbacked number does not
        assert course["minIelts"] is None


def test_a_closed_university_is_pushed_down_not_hidden():
    with _Tmp() as tmp:
        service = _build(tmp)
        store = service.store
        store.courses["c1"] = Course(
            id="c1", title="MSc Open Course", university="Some Other University",
            country="United Kingdom", level="Masters", subject="Computer Science",
            source=Source(url="https://example.ac.uk/a"),
        )
        store.courses["c2"] = Course(
            id="c2", title="MSc Closed Course",
            university="Example Metropolitan University",
            country="United Kingdom", level="Masters", subject="Computer Science",
            source=Source(url="https://example.ac.uk/b"),
        )
        out = _run(service.courses("s1", _profile("strong"), "computer science"))

        titles = [c["title"] for c in out["courses"]]
        assert "MSc Closed Course" in titles          # never hidden
        assert titles.index("MSc Closed Course") == len(titles) - 1  # but last
        closed = [c for c in out["courses"] if c["title"] == "MSc Closed Course"][0]
        assert closed["restriction"]["status"] == "closed"
        assert "NextED" in closed["restriction"]["message"]


def test_a_stale_deadline_is_shown_but_not_asserted():
    from datetime import datetime, timedelta, timezone

    with _Tmp() as tmp:
        service = _build(tmp, research_enabled=False)
        old = datetime.now(timezone.utc) - timedelta(days=60)
        course = Course(
            id="c1", title="MSc Stale", university="Some Other University",
            country="United Kingdom", level="Masters", subject="Computer Science",
            source=Source(url="https://example.ac.uk/a"),
        )
        course.deadline = make_fact(
            "2027-01-15", "deadline", "https://example.ac.uk/a",
            "The deadline is 15 January 2027.", checked_at=old,
        )
        service.store.courses["c1"] = course

        out = _run(service.courses("s1", _profile("strong"), "computer science"))
        deadline = out["courses"][0]["deadline"]
        assert deadline["value"] == "2027-01-15"      # still shown
        assert deadline["confirmed"] is False         # but not asserted
        assert "check this" in deadline["note"].lower()
        assert deadline["sourceUrl"]


# ==================================================== scholarship finding
def test_scholarships_verdicts_are_decided_in_code():
    with _Tmp() as tmp:
        search = FakeWebSearch(
            results={"*": [SearchHit(url="https://example.ac.uk/scholarship", title="GF")]}
        )
        service = _build(tmp, search=search)

        strong = _run(service.scholarships("s1", _profile("strong"), "scholarship"))
        assert strong["scholarships"][0]["verdict"] == "Eligible"   # band 7.5 vs 7.0

        borderline = _run(service.scholarships("s2", _profile("borderline"), "scholarship"))
        assert borderline["scholarships"][0]["verdict"] == "Borderline"  # 6.5 vs 7.0


def test_a_failed_phrasing_never_loses_a_verdict():
    with _Tmp() as tmp:
        search = FakeWebSearch(
            results={"*": [SearchHit(url="https://example.ac.uk/scholarship", title="GF")]}
        )
        llm = ScriptedLLM(phrase=RuntimeError("model is down"))
        service = _build(tmp, llm=llm, search=search)

        out = _run(service.scholarships("s1", _profile("strong"), "scholarship"))
        row = out["scholarships"][0]
        assert row["verdict"] == "Eligible"           # the verdict survived
        assert row["reasons"]                         # raw facts shipped
        assert not row["reasons"][0].startswith("PHRASED")


def test_phrasing_is_used_when_it_works():
    """When the model phrases successfully, its wording is what ships."""
    with _Tmp() as tmp:
        search = FakeWebSearch(
            results={"*": [SearchHit(url="https://example.ac.uk/scholarship", title="GF")]}
        )
        # An explicit override, so we can tell the model's wording apart from
        # the raw facts it would fall back to.
        llm = ScriptedLLM()
        service = _build(tmp, llm=llm, search=search)

        first = _run(service.scholarships("s1", _profile("strong"), "scholarship"))
        row_id = first["scholarships"][0]["id"]

        llm.overrides["phrase"] = {
            "items": [{"id": row_id, "reasons": ["Your IELTS comfortably clears this one."]}]
        }
        out = _run(service.scholarships("s1", _profile("strong"), "scholarship"))
        assert out["scholarships"][0]["reasons"] == [
            "Your IELTS comfortably clears this one."
        ]


def test_a_thin_profile_gets_borderline_and_a_gap_to_fill():
    with _Tmp() as tmp:
        search = FakeWebSearch(
            results={"*": [SearchHit(url="https://example.ac.uk/scholarship", title="GF")]}
        )
        service = _build(tmp, search=search)
        out = _run(service.scholarships("s3", _profile("thin"), "scholarship"))

        row = out["scholarships"][0]
        assert row["verdict"] == "Borderline"         # unknown, not rejected
        assert "ieltsBand" in row["missingFields"]
        assert out["gap"] is not None
        assert "Add" in out["gap"]["message"]


# ============================================================= counsellor
def test_the_counsellor_answers_and_knows_the_profile():
    with _Tmp() as tmp:
        service = _build(tmp)
        out = _run(
            service.counsellor("s1", _profile("strong"), "What should I think about?")
        )
        assert out["reply"]
        assert out["usage"]["used"] == 1
        assert "mistakes" in out["disclaimer"].lower()


def test_the_fee_question_returns_the_approved_text_and_spends_nothing():
    from app.core.policy import fee_response

    with _Tmp() as tmp:
        service = _build(tmp)
        for question in ("how much is your file opening fee?",
                         "can you tell me the cost of working with nexted?",
                         "is your service free?"):
            out = _run(service.counsellor("s1", _profile("strong"), question))
            assert out["reply"] == fee_response(service.settings.office_phone_display), question
            assert "office" in out
        assert out["usage"]["used"] == 0      # no model was called


def test_reaching_a_counsellor_gets_the_real_office_and_nothing_invented():
    with _Tmp() as tmp:
        service = _build(tmp)
        out = _run(
            service.counsellor("s1", _profile("strong"), "How can I get in touch with a counselor?")
        )
        assert out["usage"]["used"] == 0      # fixed text, no model
        assert "office" in out
        reply = out["reply"].lower()
        assert service.settings.office_phone_display in out["reply"]
        for invented in ("email", "schedul", "book an", "will contact", "reach out", "whatsapp"):
            assert invented not in reply, invented


def test_a_restricted_university_the_model_mentioned_is_flagged():
    llm = ScriptedLLM(
        counsellor={
            "reply": "You could consider Example Metropolitan University for computing."
        }
    )
    with _Tmp() as tmp:
        service = _build(tmp, llm=llm)
        out = _run(service.counsellor("s1", _profile("strong"), "any suggestions?"))
        assert len(out["restricted"]) == 1
        assert out["restricted"][0]["university"] == "Example Metropolitan University"
        assert "office" in out


# ================================================================== quota
def test_the_daily_cap_is_enforced_and_reported():
    from app.errors import AiLimitReached

    with _Tmp() as tmp:
        service = _build(tmp, daily_ai_limit=2)
        _run(service.counsellor("s1", _profile("strong"), "hello there"))
        _run(service.counsellor("s1", _profile("strong"), "hello again"))
        try:
            _run(service.counsellor("s1", _profile("strong"), "one more"))
        except AiLimitReached as exc:
            assert exc.extra["usage"]["left"] == 0
            return
        raise AssertionError("the third call should have been refused")


def test_the_cap_is_per_student():
    with _Tmp() as tmp:
        service = _build(tmp, daily_ai_limit=1)
        _run(service.counsellor("s1", _profile("strong"), "hello"))
        out = _run(service.counsellor("s2", _profile("strong"), "hello"))
        assert out["usage"]["used"] == 1


def test_research_is_skipped_when_no_search_provider_is_configured():
    from app.tools.search_web import NoWebSearch

    with _Tmp() as tmp:
        service = _build(tmp, search=NoWebSearch())
        out = _run(service.courses("s1", _profile("strong"), "anything at all"))
        assert out["courses"] == []
        assert out["usage"]["used"] >= 0      # nothing crashed


def test_the_research_budget_is_respected():
    with _Tmp() as tmp:
        hits = [SearchHit(url=f"https://example.ac.uk/ai?p={i}") for i in range(10)]
        search = FakeWebSearch(results={"*": hits})
        service = _build(tmp, search=search, max_fetches=2)
        service.fetcher.mapping = {h.url: "course-good.html" for h in hits}

        _run(service.courses("s1", _profile("strong"), "msc ai"))
        assert len(service.fetcher.calls) <= 2


# ================================================================ graphs
def test_all_three_graphs_are_wired_and_run_their_steps():
    with _Tmp() as tmp:
        service = _build(tmp)
        for graph in (service._counsellor, service._courses, service._scholarships):
            assert graph.steps, f"{graph.name} has no steps"
            names = [s.name for s in graph.steps]
            assert len(names) == len(set(names)), f"{graph.name} has duplicate nodes"


def test_the_fixed_reply_branch_skips_the_model_nodes():
    with _Tmp() as tmp:
        service = _build(tmp)
        llm = service.llm
        _run(service.counsellor("s1", _profile("strong"), "what is your file opening fee"))
        assert "counsellor" not in getattr(llm, "calls", [])


# =================================================== cost: avoiding calls
def test_an_unchanged_page_costs_no_model_call():
    """The biggest saving available: re-reading a page that has not moved."""
    with _Tmp() as tmp:
        llm = ScriptedLLM()
        service = _build(tmp, llm=llm)

        _run(service.courses("s1", _profile("strong"), "msc artificial intelligence"))
        first = llm.calls.count("extract")
        assert first == 1

        _run(service.courses("s1", _profile("strong"), "msc artificial intelligence"))
        assert llm.calls.count("extract") == first, (
            "the page was identical, so it should not have been extracted again"
        )


def test_a_page_with_no_requirement_wording_is_not_sent_to_the_model():
    from app.tools.extract import worth_extracting
    from app.tools.fetch import Page

    listing = Page(
        url="https://example.ac.uk/courses",
        status=200,
        text="Browse our courses. " * 40,
    )
    assert not worth_extracting(listing)

    real = Page(
        url="https://example.ac.uk/ai",
        status=200,
        text="Entry requirements. Applicants need an overall IELTS score of 6.5. " * 5,
    )
    assert worth_extracting(real)


def test_the_small_jobs_go_to_the_cheap_model():
    """understand, plan and extract are routed to FAST_MODEL."""
    seen: list[tuple[str, bool]] = []

    class Watcher(ScriptedLLM):
        async def complete_json(self, system, user, schema=None, *, fast=False, label=""):
            seen.append((label, fast))
            return await super().complete_json(
                system, user, schema, fast=fast, label=label
            )

    with _Tmp() as tmp:
        service = _build(tmp, llm=Watcher())
        _run(service.courses("s1", _profile("strong"), "msc artificial intelligence"))

    routing = dict(seen)
    assert routing["understand"] is True
    assert routing["plan"] is True
    assert routing["extract"] is True      # safe: evidence checking catches it
    assert routing["rank"] is False        # the one worth the better model


# ================================================= the graph state schema
def test_every_state_key_is_declared_on_graphstate():
    """LangGraph builds one channel per ANNOTATED key.

    A key that is not declared is dropped between nodes, so the next node
    sees nothing. That failure is silent in the sequential runner and only
    shows up once LangGraph is installed - which is exactly how it got
    shipped once. This checks the two can never drift apart again.
    """
    from app.graphs.runner import GraphState

    declared = set(GraphState.__annotations__)

    with _Tmp() as tmp:
        service = _build(tmp)
        seen: set[str] = set()

        for which in ("counsellor", "courses", "scholarships"):
            if which == "counsellor":
                _run(service.counsellor("s1", _profile("strong"), "hello there"))
            else:
                _run(getattr(service, which)("s1", _profile("strong"), "computer science"))

        # rebuild the states the service hands in, plus everything the
        # graphs put back, and check the lot
        base = service._base_state("s1", _profile("strong"))
        seen |= set(base)
        seen |= {"query", "kind", "message", "history"}

        for graph, kind in (
            (service._counsellor, "course"),
            (service._courses, "course"),
            (service._scholarships, "scholarship"),
        ):
            state = dict(base)
            state.update(
                {"query": "x", "kind": kind, "message": "hello", "history": []}
            )
            state = _run(graph.run(state, prefer_langgraph=False))
            seen |= set(state)

    missing = sorted(seen - declared)
    assert not missing, (
        "these state keys are not declared on GraphState, so LangGraph "
        f"would drop them between nodes: {missing}"
    )


def test_every_graph_is_well_formed():
    with _Tmp() as tmp:
        service = _build(tmp)
        for graph in (service._counsellor, service._courses, service._scholarships):
            assert graph.check() == []


# ------------------------------------------------- the research budget

def _bare_store(tmp: str) -> Store:
    return Store.open(pathlib.Path(tmp) / "data", "", "", 30)


def test_a_refused_host_does_not_cost_a_fetch():
    """Four league-table results must not exhaust the budget.

    The gate refuses anything off the allowlist. If that refusal still
    spent a fetch, a search returning four aggregator sites would use up
    the whole budget and never read a university page - which is exactly
    what happened in the field before this check moved earlier.
    """
    from app.core.budget import ResearchBudget
    from app.graphs.nodes import research
    from app.tools.fetch import PageFetcher

    class Search:
        name = "stub"

        async def search(self, query, sites=(), limit=5):
            return [
                SearchHit(url="https://www.whatuni.com/advice/x", title="advice"),
                SearchHit(url="https://www.topuniversities.com/y", title="table"),
                SearchHit(url="https://www.studyportals.com/z", title="portal"),
            ]

    budget = ResearchBudget(max_searches=1, max_fetches=3)
    with tempfile.TemporaryDirectory() as tmp:
        out = asyncio.run(research({
            "budget": budget,
            "web_search": Search(),
            "fetcher": PageFetcher(FetchPolicy(allowed_domains=("ac.uk",))),
            "llm": None,
            "store": _bare_store(tmp),
            "kind": "course",
            "constraints": {"country": "United Kingdom"},
            "planned_queries": [{"query": "msc computer science"}],
        }))

    assert budget.fetches_used == 0, "a refused host must not spend a fetch"
    assert out["budget_summary"]["off_allowlist"] == 3
    assert not out["researched"]


def test_the_search_is_restricted_to_hosts_we_may_read():
    """Unrestricted queries return advice sites; the gate then refuses them.

    Asking the search engine for an allowed host up front is what turns a
    wasted budget into a useful one, so the site filter must reach the
    searcher even when the planner did not supply one.
    """
    from app.core.budget import ResearchBudget
    from app.graphs.nodes import research

    seen: list[str] = []

    class Search:
        name = "stub"

        async def search(self, query, sites=(), limit=5):
            seen.append(tuple(sites))
            return []

    fetcher = FakePageFetcher(directory=PAGES, mapping={})
    fetcher.policy = FetchPolicy(allowed_domains=("ac.uk", "gov.uk"))

    with tempfile.TemporaryDirectory() as tmp:
        asyncio.run(research({
            "budget": ResearchBudget(max_searches=2, max_fetches=2),
            "web_search": Search(),
            "fetcher": fetcher,
            "llm": None,
            "store": _bare_store(tmp),
            "kind": "course",
            "constraints": {},
            "planned_queries": [
                {"query": "msc computer science"},            # planner gave none
                {"query": "chevening award", "site": "gov.uk"},  # planner chose
            ],
        }))

    # no site from the planner -> offer every host the gate would allow,
    # so the funding bodies are not quietly excluded
    assert seen[0] == ("ac.uk", "gov.uk"), seen
    # the planner named one -> respect it
    assert seen[1] == ("gov.uk",), seen


def test_the_students_own_words_are_searched_first():
    """A rewritten query loses the thing that made it work.

    "msc computer science" lands on course pages. The same intent rebuilt
    from the profile as "Computer Science Masters course United Kingdom
    entry requirements" lands on advice PDFs and blog posts, because the
    search engine matches meaning and the padding words outvote the
    subject. So the student's own text is always query number one.
    """
    from app.graphs.nodes import plan_searches

    class Planner:
        name = "stub"

        async def complete_json(self, system, user, schema=None, **kw):
            return {"queries": [{"query": "MSc Computer Science UK universities"}]}

    out = asyncio.run(plan_searches({
        "llm": Planner(),
        "kind": "course",
        "query": "msc computer science",
        "constraints": {"subject": "Computer Science", "level": "Masters",
                        "country": "United Kingdom"},
    }))
    texts = [q["query"] for q in out["planned_queries"]]

    assert texts[0] == "msc computer science", texts
    assert not any("entry requirements" in t.lower() for t in texts), texts


def test_a_planner_that_says_nothing_still_searches_the_students_words():
    """The model failing must not turn into a padded fallback query."""
    from app.graphs.nodes import plan_searches

    class Broken:
        name = "stub"

        async def complete_json(self, system, user, schema=None, **kw):
            raise RuntimeError("no")

    out = asyncio.run(plan_searches({
        "llm": Broken(),
        "kind": "course",
        "query": "msc computer science",
        "constraints": {"subject": "Computer Science", "level": "Masters",
                        "country": "United Kingdom"},
    }))

    assert [q["query"] for q in out["planned_queries"]] == ["msc computer science"]


def test_a_silent_query_still_gets_a_plain_search():
    """No words and no plan: the profile alone, with no padding."""
    from app.graphs.nodes import plan_searches

    class Empty:
        name = "stub"

        async def complete_json(self, system, user, schema=None, **kw):
            return {"queries": []}

    out = asyncio.run(plan_searches({
        "llm": Empty(),
        "kind": "course",
        "query": "",
        "constraints": {"subject": "Computer Science", "level": "Masters"},
    }))
    texts = [q["query"] for q in out["planned_queries"]]

    assert texts == ["Computer Science Masters"], texts


def test_the_planner_copes_with_the_shapes_small_models_actually_return():
    """`json_object` guarantees valid JSON, not our schema.

    Every one of these came back from a real model where the schema asked
    for {"queries": [{"query": ...}]}. Rejecting them cost a planning call
    and produced no searches, which looked exactly like the model working.
    """
    from app.graphs.nodes import _as_query_list

    want = [{"query": "msc computer science", "site": ""}]

    assert _as_query_list({"queries": [{"query": "msc computer science"}]}) == want
    assert _as_query_list({"searches": ["msc computer science"]}) == want
    assert _as_query_list({"query": "msc computer science"}) == want
    assert _as_query_list(["msc computer science"]) == want
    assert _as_query_list([{"q": "msc computer science"}]) == want
    # and nothing usable stays nothing, rather than becoming an empty search
    assert _as_query_list({"result": "ok"}) == []
    assert _as_query_list("nonsense") == []


def test_a_page_is_not_discarded_for_a_missing_found_flag():
    """The model named a course; that is a find whether or not it said so.

    A smaller model that returns the right content without the `found`
    key had its whole page thrown away - the page was read, the model was
    paid for, and the result was silently dropped.
    """
    from app.tools.extract import extract_from_page
    from app.tools.fetch import Page

    page = Page(
        url="https://example.ac.uk/msc-cs",
        status=200,
        text="MSc Computer Science at Example University. "
             "Entry requirements: IELTS 6.5 overall. " * 10,
        content_hash="abc123",
    )

    class NoFoundKey:
        name = "stub"

        async def complete_json(self, system, user, schema=None, **kw):
            return {
                "title": "MSc Computer Science",
                "university": "Example University",
                "level": "Masters",
                "fields": [{
                    "name": "min_ielts",
                    "value": 6.5,
                    "evidence": "Entry requirements: IELTS 6.5 overall.",
                }],
            }

    out = asyncio.run(extract_from_page(NoFoundKey(), page, kind="course"))

    assert out.found is True
    assert out.title == "MSc Computer Science"
    assert [f.name for f in out.kept] == ["min_ielts"]


def test_an_explicit_found_false_is_still_obeyed():
    """Inferring must not override a model that actually answered."""
    from app.tools.extract import extract_from_page
    from app.tools.fetch import Page

    page = Page(
        url="https://example.ac.uk/blog",
        status=200,
        text="Entry requirements vary by course. " * 30,
        content_hash="def456",
    )

    class SaysNo:
        name = "stub"

        async def complete_json(self, system, user, schema=None, **kw):
            return {"found": False, "title": "Our blog", "university": "Example"}

    assert asyncio.run(extract_from_page(SaysNo(), page, kind="course")).found is False


def test_no_search_is_made_with_nothing_left_to_read_it_with():
    """A search with no fetch budget is billed and then thrown away.

    MAX_FETCHES=4 against three planned queries meant the first search
    consumed the whole page budget and the next two were paid for,
    returned results, and had every one of them dropped unread.
    """
    from app.core.budget import ResearchBudget
    from app.graphs.nodes import research
    from app.tools.fetch import FakePageFetcher, FetchPolicy

    searched: list[str] = []

    class Search:
        name = "stub"

        async def search(self, query, sites=(), limit=5):
            searched.append(query)
            return []

    fetcher = FakePageFetcher(directory=PAGES, mapping={})
    fetcher.policy = FetchPolicy(allowed_domains=("ac.uk",))

    budget = ResearchBudget(max_searches=3, max_fetches=1)
    budget.spend_fetch()                      # budget already gone

    with tempfile.TemporaryDirectory() as tmp:
        asyncio.run(research({
            "budget": budget,
            "web_search": Search(),
            "fetcher": fetcher,
            "llm": None,
            "store": _bare_store(tmp),
            "kind": "course",
            "constraints": {},
            "planned_queries": [
                {"query": "one"}, {"query": "two"}, {"query": "three"},
            ],
        }))

    assert searched == [], searched
    assert budget.searches_used == 0


def test_a_ranking_scored_under_another_name_is_still_a_ranking():
    """The id came back right and the score came back as "score".

    Every result then displayed as "match 0" and the model's ordering was
    thrown away, while the logs showed the ranking call succeeding.
    """
    from app.graphs.nodes import rank

    def course(row_id: str, title: str) -> Course:
        return Course(id=row_id, title=title, university="Example University",
                      country="United Kingdom", level="Masters",
                      subject="Computer Science")

    rows = [course("a", "MSc Computer Science"), course("b", "MSc Data Science")]

    class Renamer:
        name = "stub"

        async def complete_json(self, system, user, schema=None, **kw):
            return {"results": [
                {"course_id": "a", "score": 92, "reason": "Matches the subject."},
                {"course_id": "b", "relevance": 0.4, "explanation": "Adjacent."},
            ]}

    out = asyncio.run(rank({
        "llm": Renamer(),
        "candidates": rows,
        "profile": StudentProfile(name="T"),
        "query": "msc computer science",
    }))

    assert out["ranking"]["a"]["confidence"] == 92
    assert out["ranking"]["a"]["why"] == "Matches the subject."
    # 0-1 scores are a common reading of "score this match"
    assert out["ranking"]["b"]["confidence"] == 40


def test_a_course_search_does_not_go_to_the_funding_bodies():
    """A course is taught by a university; an award is given by a funder.

    A live course search spent its whole page budget on British Council
    scholarship listings, two 403s and a robots.txt block. The fetch gate
    still allows those hosts - this only aims the search.
    """
    from app.core.budget import ResearchBudget
    from app.graphs.nodes import research
    from app.tools.fetch import FakePageFetcher, FetchPolicy

    seen: list[tuple] = []

    class Search:
        name = "stub"

        async def search(self, query, sites=(), limit=5):
            seen.append(tuple(sites))
            return []

    def run(kind: str):
        fetcher = FakePageFetcher(directory=PAGES, mapping={})
        fetcher.policy = FetchPolicy(
            allowed_domains=("ac.uk", "chevening.org", "britishcouncil.org"),
            funding_domains=("chevening.org", "britishcouncil.org"),
        )
        with tempfile.TemporaryDirectory() as tmp:
            asyncio.run(research({
                "budget": ResearchBudget(max_searches=1, max_fetches=2),
                "web_search": Search(),
                "fetcher": fetcher,
                "llm": None,
                "store": _bare_store(tmp),
                "kind": kind,
                "constraints": {},
                "planned_queries": [{"query": "computer science"}],
            }))

    run("course")
    assert seen[0] == ("ac.uk",), seen

    run("scholarship")
    assert seen[1] == ("ac.uk", "chevening.org", "britishcouncil.org"), seen


def test_rows_stored_under_an_older_rule_are_tidied_on_load():
    """A catalogue that fills itself keeps what it was given at the time.

    Three page-title rows and one guide article were stored before the
    rules that reject them existed, and would have been offered to every
    future student. Nothing is rewritten on disk - they are simply not
    offered, and research will find the real page again.
    """
    with tempfile.TemporaryDirectory() as tmp:
        data = pathlib.Path(tmp) / "data"
        data.mkdir()
        (data / "courses.json").write_text(json.dumps([
            {"id": "a", "title": "MSc Computer Science | University of Suffolk",
             "university": "University of Suffolk", "country": "United Kingdom",
             "level": ""},
            {"id": "b", "title": "What is an MSc in Computer Science? 2026 Guide",
             "university": "Walbrook", "country": "United Kingdom"},
        ]))
        store = Store.open(data, "", "", 30)

    assert "b" not in store.courses, "a guide article is not a course"
    assert store.courses["a"].title == "MSc Computer Science"
    # the level was in the title all along
    assert store.courses["a"].level == "Masters"


def test_a_fix_to_extraction_reaches_pages_already_read():
    """Skipping an unchanged page is cheap, and it freezes the row.

    Three courses were stored while the evidence search was dropping
    every tuition and deadline. The fix could never reach them: the
    pages had not changed, so they were reused from storage for every
    future student, permanently factless.
    """
    from app.core.catalogue import Course, Source
    from app.tools.extract import EXTRACTOR_VERSION

    with tempfile.TemporaryDirectory() as tmp:
        store = _bare_store(tmp)

        stale = Course(id="old", title="MSc Computer Science",
                       university="University of Suffolk",
                       country="United Kingdom", level="Masters")
        stale.source = Source(url="https://www.uos.ac.uk/study/msc-computer-science/",
                              content_hash="same-page",
                              extractor=EXTRACTOR_VERSION - 1)
        store.upsert_course(stale)

        # same page, older rules -> read it again
        assert store.find_by_content_hash("same-page", "course") is None

        stale.source.extractor = EXTRACTOR_VERSION
        # same page, current rules -> reuse it, no model call
        assert store.find_by_content_hash("same-page", "course") is not None


def test_the_extractor_version_survives_being_written_to_disk():
    """A version that resets to 0 on load re-reads every page forever."""
    from app.core.catalogue import Course, Source
    from app.tools.extract import EXTRACTOR_VERSION

    with tempfile.TemporaryDirectory() as tmp:
        data = pathlib.Path(tmp) / "data"
        store = Store.open(data, "", "", 30)
        row = Course(id="x", title="MSc Computer Science",
                     university="Example University", country="United Kingdom")
        row.source = Source(url="https://example.ac.uk/c", content_hash="h",
                            extractor=EXTRACTOR_VERSION)
        store.upsert_course(row)
        store.save_courses()

        reopened = Store.open(data, "", "", 30)

    assert reopened.courses["x"].source.extractor == EXTRACTOR_VERSION
    assert reopened.find_by_content_hash("h", "course") is not None


def test_the_counsellor_finds_its_answer_under_any_key():
    """The schema asks for `reply`; models answer under other words.

    A live counsellor run returned "I could not put an answer together
    just now" while the model's answer sat in the response under another
    name - the worst failure of the three, because the student is told
    there is no answer when there is one.
    """
    from app.graphs.counsellor import _reply_text

    answer = ("Apply this year: the September deadlines are still open "
              "and your IELTS is already above the usual requirement.")

    for shape in (
        {"reply": answer},
        {"answer": answer},
        {"response": answer},
        {"message": answer},
        {"reply": {"text": answer}},
        {"guidance": answer},                      # a key we never listed
        {"paragraphs": [answer, "Speak to a counsellor to confirm."]},
    ):
        assert answer[:30] in _reply_text(shape), shape

    # nothing usable stays nothing - we must not invent an answer
    assert _reply_text({"ok": True}) == ""
    assert _reply_text({"reply": ""}) == ""
    assert _reply_text({}) == ""


def test_the_daily_cap_is_not_spent_twice_by_a_fallback():
    """An AppError is an answer, not a graph failure.

    Under LangGraph, a student who had reached the cap raised inside a
    node, the runner treated it as a broken graph, and re-ran every node
    sequentially - checking and consuming the allowance a second time to
    arrive at the same refusal.
    """
    from app.errors import AiLimitReached
    from app.graphs.runner import Graph

    calls = {"n": 0}

    async def over_the_cap(state):
        calls["n"] += 1
        raise AiLimitReached(usage={"used": 30, "limit": 30})

    graph = Graph("test")
    graph.add("check_quota", over_the_cap)

    try:
        asyncio.run(graph.run({"trace_steps": []}))
    except AiLimitReached:
        pass
    else:
        raise AssertionError("the cap should have been reported")

    assert calls["n"] == 1, f"the node ran {calls['n']} times, not once"