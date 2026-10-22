#!/usr/bin/env python3
"""Try the three AI features from the command line. No server needed.

    python try.py                                  all three, default student
    python try.py counsellor "should I apply now?"
    python try.py courses "msc artificial intelligence"
    python try.py scholarships "masters funding"

    python try.py --student borderline courses "business"
    python try.py --list                           show the example students

Works with nothing configured: LLM_PROVIDER=echo needs no key, and with no
search provider the finders answer from whatever is already stored.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from app.config import get_settings  # noqa: E402
from app.core.profile import StudentProfile  # noqa: E402
from app.wiring import build_counsellor  # noqa: E402

DEMO_PAGES = {
    "https://example.ac.uk/ai": "course-good.html",
    "https://example.ac.uk/business": "course-vague.html",
    "https://example.ac.uk/scholarship": "scholarship.html",
}


def make_demo(service):
    """Swap in a fake web so the whole research path runs with no keys.

    Searches and fetches are faked; everything else - the gate's rules, the
    extractor, the evidence check, the verdicts, the write-back - is the
    real code.
    """
    from app.providers.demo import DemoLLM
    from app.tools.fetch import FakePageFetcher
    from app.tools.search_web import FakeWebSearch, SearchHit

    # Always, not just when the provider is 'echo'. The saved pages only
    # make sense to the scripted model, and calling a real provider here
    # would spend money to be told nothing.
    service.llm = DemoLLM()
    service.fetcher = FakePageFetcher(
        directory=ROOT / "examples" / "pages", mapping=DEMO_PAGES
    )
    service.web_search = FakeWebSearch(
        results={
            "scholarship": [SearchHit(url="https://example.ac.uk/scholarship",
                                      title="Global Futures Scholarship")],
            "business": [SearchHit(url="https://example.ac.uk/business",
                                   title="MA Business Management")],
            "*": [SearchHit(url="https://example.ac.uk/ai",
                            title="MSc Artificial Intelligence")],
        }
    )
    # Demo rows are invented. They must never end up in the real store,
    # where they would show up in live searches looking like real courses.
    from app.store.json_store import Store

    service.store = Store.open(
        data_dir=ROOT / "data-demo",
        restrictions_file=service.settings.restrictions_file,
        seed_dir="",
        daily_limit=service.settings.daily_ai_limit,
    )
    service.settings.research_enabled = True
    return service

STUDENTS = ROOT / "examples" / "students"

BOLD, DIM, OFF = "\033[1m", "\033[2m", "\033[0m"
GREEN, AMBER, RED = "\033[32m", "\033[33m", "\033[31m"


def setup_logging(verbose: bool) -> None:
    """Show what the service is doing.

    Without this nothing below WARNING is printed, so the reasons a search
    came back thin - a page refused, a field dropped for want of evidence,
    a ranking ignored - are invisible. They are the whole point of looking.
    """
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="  %(levelname)-7s %(name)s: %(message)s",
    )
    # these are noisy and not ours
    for noisy in ("httpx", "httpcore", "urllib3", "langsmith", "langgraph"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


def colour(text: str, code: str) -> str:
    return text if not sys.stdout.isatty() else f"{code}{text}{OFF}"


def load_student(name: str) -> StudentProfile:
    path = STUDENTS / f"{name}.json"
    if not path.exists():
        available = ", ".join(sorted(p.stem for p in STUDENTS.glob("*.json")))
        raise SystemExit(f"No student called {name!r}. Try one of: {available}")
    return StudentProfile.model_validate(json.loads(path.read_text()))


def rule(title: str) -> None:
    print()
    print(colour(f"── {title} " + "─" * max(0, 60 - len(title)), BOLD))


def show_fact(label: str, fact: dict | None) -> None:
    if not fact:
        return
    mark = colour("confirmed", GREEN) if fact["confirmed"] else colour("needs checking", AMBER)
    print(f"    {label}: {fact['value']}  [{mark}]")
    if fact.get("sourceUrl"):
        print(colour(f"      {fact['sourceUrl']}", DIM))


# ---------------------------------------------------------------- printers
def print_counsellor(out: dict) -> None:
    rule("AI Counsellor")
    print(out["reply"])
    for item in out.get("restricted") or []:
        print()
        print(colour(f"  ! {item['university']}: {item['message']}", RED))
        if item.get("detail"):
            print(colour(f"    {item['detail']}", DIM))
    if out.get("office"):
        office = out["office"]
        print()
        print(f"  {office['name']} — {office['address']}")
        print(f"  {office['phoneDisplay']}   {office['mapsUrl']}")
    print()
    print(colour(f"  usage: {out['usage']['used']}/{out['usage']['limit']}", DIM))


def print_courses(out: dict, searching: bool = False) -> None:
    rule("Course Finding")
    if out.get("searchNote"):
        print(colour(out["searchNote"], DIM))
        print()
    if not out["courses"]:
        _nothing(searching)
    for i, c in enumerate(out["courses"], 1):
        status = c["restriction"]["status"]
        tag = {"open": "", "check": colour(" [needs checking]", AMBER),
               "closed": colour(" [CLOSED via NextED]", RED)}[status]
        print(f"  {i}. {colour(c['title'], BOLD)} — {c['university']}{tag}")
        print(f"     {c['level']}  {c['country']}  ·  {colour(c['sourceLabel'], DIM)}"
              f"  ·  match {c['confidence']}")
        if c.get("why"):
            print(f"     {c['why']}")
        show_fact("tuition", c.get("tuition"))
        show_fact("IELTS", c.get("minIelts"))
        show_fact("deadline", c.get("deadline"))
        if status == "closed":
            print(colour(f"     {c['restriction']['message']}", RED))
        print()
    _print_tail(out)


def print_scholarships(out: dict, searching: bool = False) -> None:
    rule("Scholarship Finding")
    if out.get("searchNote"):
        print(colour(out["searchNote"], DIM))
        print()
    if not out["scholarships"]:
        _nothing(searching)
    for i, s in enumerate(out["scholarships"], 1):
        code = {"Eligible": GREEN, "Borderline": AMBER, "Not eligible": RED}[s["verdict"]]
        print(f"  {i}. {colour(s['title'], BOLD)} — {s['provider']}")
        print(f"     {colour(s['verdict'], code)}  ·  {colour(s['sourceLabel'], DIM)}")
        for reason in s["reasons"]:
            print(f"     · {reason}")
        show_fact("amount", s.get("amount"))
        show_fact("deadline", s.get("deadline"))
        if s.get("missingFields"):
            print(colour(f"     missing from your profile: {', '.join(s['missingFields'])}", DIM))
        print()
    if out.get("gap"):
        print(colour(f"  → {out['gap']['message']}", BOLD))
        print()
    _print_tail(out)


def _nothing(searching: bool = False) -> None:
    """Nothing to show - but the reason matters, and they differ."""
    if searching:
        print("  The search found pages, but none of them could be read and")
        print("  turned into a result. The log above says why for each one -")
        print("  a 403 means the site blocks automated readers, a timeout")
        print("  means it did not answer in time. Two ways to look closer:")
        print(colour("    python try.py --search \"<your query>\"", BOLD)
              + "   what the search returns")
        print(colour("    python try.py --page \"<a url from the log>\"", BOLD)
              + "  what one page yields")
        print()
        return
    print("  Nothing stored yet, and no web search is configured, so there is")
    print("  nothing honest to show. Two ways forward:")
    print(colour("    python try.py --demo courses \"msc ai\"", BOLD)
          + "   see the research path, offline")
    print("    set WEB_SEARCH_PROVIDER and WEB_SEARCH_API_KEY in .env  for the real web")
    print()


def _print_tail(out: dict) -> None:
    for change in out.get("changes") or []:
        print(colour(f"  * {change}", AMBER))
    for source in out.get("sources") or []:
        print(colour(f"  read: {source['url']}", DIM))
    if out.get("researchNote"):
        print(colour(f"  {out['researchNote']}", AMBER))
    print(colour(f"  usage: {out['usage']['used']}/{out['usage']['limit']}", DIM))


# -------------------------------------------------------------------- main
async def run(
    which: str, student: StudentProfile, text: str, student_id: str, demo: bool = False
) -> None:
    service = build_counsellor()
    if demo:
        service = make_demo(service)
    settings = service.settings

    rule("Setup")
    if demo:
        print(colour("  DEMO MODE: the web is faked from examples/pages/,", BOLD))
        print(colour("             everything else is the real code.", BOLD))
    print(f"  model:        {service.llm.name}"
          + ("" if service.llm.name != "echo"
             else colour("   (no key set — replies are stubs)", AMBER)))
    searching = settings.research_enabled and service.web_search.name != "none"
    print(f"  web research: {service.web_search.name}"
          + ("" if searching else colour("   (off — answers come from storage only)", AMBER)))
    print(f"  restrictions: {len(service.store.rules)} rule(s)"
          + ("" if service.store.rules
             else colour("   (none — restriction checking is off)", AMBER)))
    print(f"  stored:       {len(service.store.courses)} course(s), "
          f"{len(service.store.scholarships)} scholarship(s)")
    print(f"  student:      {student.name or student_id} "
          f"({student.preferred_country or 'no country'}, "
          f"IELTS {student.ielts_band or 'not given'}, "
          f"result {student.result or 'not given'})")

    if which in ("all", "counsellor"):
        print_counsellor(
            await service.counsellor(
                student_id, student, text or "What should I be thinking about?"
            )
        )
    if which in ("all", "courses"):
        print_courses(await service.courses(student_id, student, text), searching)
    if which in ("all", "scholarships"):
        print_scholarships(
            await service.scholarships(student_id, student, text), searching
        )

    print()


async def show_models() -> None:
    """Ask the provider what this key can actually use.

    A wrong or retired model name is the most common setup mistake, and it
    surfaces as an unhelpful 404 at the worst moment. This answers it.
    """
    from app.config import get_settings
    from app.providers.factory import build_llm

    settings = get_settings()
    rule("Models")
    print(f"  provider: {settings.llm_provider}")

    if settings.llm_provider not in {"groq", "gemini"}:
        print(colour("  Set LLM_PROVIDER to groq or gemini first.", AMBER))
        return

    try:
        llm = build_llm(settings)
    except Exception as exc:
        print(colour(f"  {exc}", RED))
        return

    models = await llm.list_models()
    if not models:
        print(colour("  Could not read the model list - check the key.", RED))
        return

    print(f"  {len(models)} available:\n")
    for name in models:
        print(f"    {name}")
    print()
    print(colour("  Put a large one in GROQ_MODEL / GEMINI_WRITING_MODEL,", BOLD))
    print(colour("  and the smallest in FAST_MODEL.", BOLD))


async def show_search(query: str) -> None:
    """Ask the configured search provider directly and show what came back.

    Worth having on its own: when a finder returns nothing, the cause is
    either that the search found nothing or that everything it found was
    off the allowlist, and those need opposite fixes. This separates them.
    """
    from app.tools.fetch import host_allowed

    service = build_counsellor()
    settings = service.settings
    allowed = tuple(settings.allowed_domains)

    rule("Search")
    print(f"  provider:  {service.web_search.name}")
    print(f"  allowlist: {', '.join(allowed) or '(empty - nothing can be read)'}")
    print(f"  query:     {query!r}")

    if service.web_search.name == "none":
        print(colour("\n  No provider configured. Set WEB_SEARCH_PROVIDER and "
                     "WEB_SEARCH_API_KEY.", AMBER))
        return

    hits = await service.web_search.search(query, allowed, limit=8)
    if not hits:
        print(colour("\n  Nothing came back. Either the query is too narrow for "
                     "the\n  allowlist, or the provider rejected the request - "
                     "check for\n  a 'web search http 4xx' line above.", AMBER))
        return

    print(f"\n  {len(hits)} result(s):\n")
    for hit in hits:
        ok = host_allowed(hit.url, allowed) if allowed else True
        mark = colour("readable", GREEN) if ok else colour("REFUSED", RED)
        print(f"    [{mark}] {hit.url}")
        if hit.title:
            print(colour(f"             {hit.title[:90]}", DIM))

    readable = sum(1 for h in hits if not allowed or host_allowed(h.url, allowed))
    print()
    if readable:
        print(colour(f"  {readable} of {len(hits)} can be read. "
                     f"The finders will use those.", BOLD))
    else:
        print(colour("  None of these can be read, so the finders have nothing to\n"
                     "  work with. Either widen ALLOWED_DOMAINS or the provider is\n"
                     "  ignoring the domain restriction.", RED))


async def show_page(url: str, kind: str = "course") -> None:
    """Fetch one page and show exactly what the extractor made of it.

    The finders drop a page for several different reasons - the gate
    refused it, there was no requirement wording on it, the model named
    nothing, the evidence check threw the facts away - and from the
    outside all of them look the same: no results. This separates them.
    """
    service = build_counsellor()

    rule("Page")
    print(f"  url:  {url}")
    print(f"  kind: {kind}")

    page = await service.fetcher.get(url)
    if not page.ok:
        print(colour(f"\n  Could not read it: "
                     f"{page.error or f'http {page.status}'}", RED))
        return
    print(f"  read: {len(page.text):,} characters of text")

    from app.tools.extract import extract_from_page, to_course, to_scholarship

    extraction = await extract_from_page(service.llm, page, kind=kind)
    if not extraction.found:
        print(colour("\n  The extractor found nothing on it. If no reason "
                     "appears above,\n  the model returned a shape the code "
                     "did not recognise.", AMBER))
        return

    print(f"\n  title:      {extraction.title or colour('(none)', RED)}")
    label = "university" if kind == "course" else "provider"
    value = extraction.university or extraction.provider
    print(f"  {label}: {value or colour('(none)', RED)}")
    print(f"  level:      {extraction.level or '(none)'}")
    print(f"  subject:    {extraction.subject or '(none)'}")

    if extraction.kept:
        print(colour("\n  Facts kept (the page states each one):", BOLD))
        for fact in extraction.kept:
            print(f"    {fact.name}: {fact.value}")
            print(colour(f"      \"{fact.evidence[:100]}\"", DIM))
    if extraction.dropped:
        print(colour("\n  Facts dropped (the page does not state them):", AMBER))
        for fact in extraction.dropped:
            print(f"    {fact.name}: {fact.value}")

    row = (to_course(extraction, "probe", "")
           if kind == "course" else to_scholarship(extraction, "probe", ""))
    print()
    if row is None:
        print(colour(f"  No {kind} row: a {kind} needs both a title and a "
                     f"{label}.", RED))
        print(colour("  The page was read and the model was paid for; the "
                     "result is dropped.", DIM))
    else:
        print(colour(f"  A {kind} row was built. A real run would store this.",
                     GREEN))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Try the three nextED AI features.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "feature",
        nargs="?",
        default="all",
        choices=["all", "counsellor", "courses", "scholarships"],
    )
    parser.add_argument("text", nargs="?", default="")
    parser.add_argument("--student", default="strong", help="a file in examples/students")
    parser.add_argument("--id", default="try-student-1", help="student id for the daily cap")
    parser.add_argument("--list", action="store_true", help="list the example students")
    parser.add_argument(
        "--models",
        action="store_true",
        help="ask your provider which models your key can use",
    )
    parser.add_argument(
        "--search",
        metavar="QUERY",
        help="ask the search provider directly and show which results are readable",
    )
    parser.add_argument(
        "--page",
        metavar="URL",
        help="fetch one page and show exactly what the extractor made of it",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="fake the web from examples/pages/ so the research path runs with no keys",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="show debug logging too"
    )
    args = parser.parse_args()
    setup_logging(args.verbose)

    if args.models:
        asyncio.run(show_models())
        return

    if args.search:
        asyncio.run(show_search(args.search))
        return

    if args.page:
        kind = "scholarship" if args.feature == "scholarships" else "course"
        asyncio.run(show_page(args.page, kind))
        return

    if args.list:
        print("Example students:")
        for path in sorted(STUDENTS.glob("*.json")):
            data = json.loads(path.read_text())
            print(f"  {path.stem:12} {data.get('highestLevel', '?'):12} "
                  f"IELTS {data.get('ieltsBand') or '-':8} "
                  f"result {data.get('result') or '-':10} "
                  f"{data.get('preferredCountry') or '-'}")
        return

    asyncio.run(
        run(args.feature, load_student(args.student), args.text, args.id, args.demo)
    )


if __name__ == "__main__":
    main()