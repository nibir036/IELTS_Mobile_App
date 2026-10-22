"""Score the counsellor and the course finder in LangSmith.

    python -m evals.langsmith_eval                 run every case, open the link it prints
    python -m evals.langsmith_eval --only counsellor

Needs in .env:  LANGSMITH_API_KEY=...   (smith.langchain.com -> Settings -> API keys)
It spends real AI credits (about one per case) under test student ids only.

Tracing alone (LANGSMITH_TRACING=true) only RECORDS runs: every graph step,
its inputs/outputs and timing. It does not judge anything. Evaluation is this
file: a fixed dataset of cases, run against the service, and each answer
scored by the evaluators below. Run it after every change and compare the
experiments side by side in LangSmith - a drop in any score is a regression,
however good one answer looks.

Evaluators (0 = fail, 1 = pass, averaged per experiment):
  mentions        the answer covers what the case needs (any of the keywords)
  uses_profile    it used the student's own details (band, subject, country)
  no_invented_fee no money amounts on cases where the office must answer
  office_card     fee/document questions came with the office contact card
  judge           an LLM grader (your own Groq model) rates groundedness and helpfulness 1-5
  subject_match   course finder: share of results that match the student's subject
  not_stuck       course finder: not the same old MSc Computer Science rows

The cases use made-up test profiles only - no real student data is uploaded.
"""
from __future__ import annotations

import argparse
import asyncio
import re

DATASET = "nexted-ai-eval"

CASES = [
    # --- counsellor
    {"inputs": {"feature": "counsellor", "message": "Is my IELTS band good enough for a UK masters?",
                "profile": {"ieltsBand": "6.0", "highestLevel": "Bachelor", "preferredCountry": "UK", "subject": "Data Science"}},
     "outputs": {"mentions": ["6.5", "6.0", "band"], "profile_terms": ["6.0", "data science", "uk"]}},
    {"inputs": {"feature": "counsellor", "message": "Which countries suit my profile?",
                "profile": {"ieltsBand": "6.5", "highestLevel": "HSC", "result": "4.80", "subject": "Nursing", "preferredCountry": ""}},
     "outputs": {"mentions": ["canada", "australia", "uk", "united kingdom"], "profile_terms": ["nursing", "6.5", "hsc"]}},
    {"inputs": {"feature": "counsellor", "message": "What documents do I need to apply?",
                "profile": {"highestLevel": "Bachelor", "preferredCountry": "Canada"}},
     "outputs": {"mentions": ["passport", "transcript"], "office": True}},
    {"inputs": {"feature": "counsellor", "message": "How much is nextED's service fee?",
                "profile": {"preferredCountry": "UK"}},
     "outputs": {"no_money": True, "office": True}},
    {"inputs": {"feature": "counsellor", "message": "When should I start applying for a September intake?",
                "profile": {"subject": "MBA", "preferredCountry": "UK", "intake": "September 2027"}},
     "outputs": {"mentions": ["month", "early", "deadline"], "profile_terms": ["september", "mba"]}},
    {"inputs": {"feature": "counsellor", "message": "Tell me about Chevening scholarship.",
                "profile": {"highestLevel": "Bachelor", "nationality": "Bangladeshi"}},
     "outputs": {"mentions": ["chevening", "leadership", "uk"]}},
    # --- course finder (empty search: must follow the profile)
    {"inputs": {"feature": "courses", "query": "",
                "profile": {"subject": "Nursing", "preferredCountry": "Canada", "highestLevel": "HSC"}},
     "outputs": {"subject_words": ["nurs"]}},
    {"inputs": {"feature": "courses", "query": "business analytics",
                "profile": {"preferredCountry": "UK", "highestLevel": "Bachelor"}},
     "outputs": {"subject_words": ["business", "analytic"]}},
]


# --------------------------------------------------------------- evaluators
def _text(run) -> str:
    out = run.outputs or {}
    if out.get("feature") == "courses":
        return " ".join(f"{c.get('title', '')} {c.get('subject', '')}" for c in out.get("courses", [])).lower()
    return str(out.get("reply", "")).lower()


def mentions(run, example) -> dict:
    words = (example.outputs or {}).get("mentions")
    if not words:
        return {"key": "mentions", "score": None}
    return {"key": "mentions", "score": int(any(w in _text(run) for w in words))}


def uses_profile(run, example) -> dict:
    terms = (example.outputs or {}).get("profile_terms")
    if not terms:
        return {"key": "uses_profile", "score": None}
    hits = sum(t in _text(run) for t in terms)
    return {"key": "uses_profile", "score": hits / len(terms)}


_MONEY = re.compile(r"(৳|tk\.?|bdt|£|\$|€|usd|gbp)\s?\d[\d,]*", re.I)


def no_invented_fee(run, example) -> dict:
    if not (example.outputs or {}).get("no_money"):
        return {"key": "no_invented_fee", "score": None}
    return {"key": "no_invented_fee", "score": int(not _MONEY.search(_text(run)))}


def office_card(run, example) -> dict:
    if not (example.outputs or {}).get("office"):
        return {"key": "office_card", "score": None}
    return {"key": "office_card", "score": int(bool((run.outputs or {}).get("office")))}


def subject_match(run, example) -> dict:
    words = (example.outputs or {}).get("subject_words")
    if not words:
        return {"key": "subject_match", "score": None}
    courses = (run.outputs or {}).get("courses", [])
    if not courses:
        return {"key": "subject_match", "score": 0, "comment": "no results"}
    good = sum(any(w in f"{c.get('title', '')} {c.get('subject', '')}".lower() for w in words) for c in courses)
    return {"key": "subject_match", "score": good / len(courses)}


def not_stuck(run, example) -> dict:
    if (run.outputs or {}).get("feature") != "courses":
        return {"key": "not_stuck", "score": None}
    words = (example.outputs or {}).get("subject_words") or []
    if any("comput" in w for w in words):
        return {"key": "not_stuck", "score": None}
    courses = (run.outputs or {}).get("courses", [])
    stuck = courses and all("computer" in c.get("title", "").lower() for c in courses)
    return {"key": "not_stuck", "score": int(not stuck)}


def make_judge(llm):
    schema = {"type": "object", "properties": {
        "grounded": {"type": "integer"}, "helpful": {"type": "integer"}, "reason": {"type": "string"}},
        "required": ["grounded", "helpful", "reason"]}
    system = (
        "You grade a study-abroad counsellor's answer to a student from Bangladesh. "
        "grounded (1-5): 5 = no invented fees, deadlines, scores or rules; anything uncertain is "
        "flagged to check or to ask a counsellor. 1 = states made-up specifics as fact. "
        "helpful (1-5): 5 = directly answers using the student's own profile. Be strict."
    )

    async def judge(run, example) -> dict:
        if (run.outputs or {}).get("feature") != "counsellor":
            return {"key": "judge", "score": None}
        user = (f"Student profile: {example.inputs.get('profile')}\n"
                f"Question: {example.inputs.get('message')}\n\nAnswer:\n{(run.outputs or {}).get('reply', '')}")
        try:
            data = await llm.complete_json(system, user, schema, fast=False, label="eval-judge")
        except Exception as exc:  # noqa: BLE001
            return {"key": "judge", "score": None, "comment": f"judge failed: {exc}"}
        score = (int(data.get("grounded", 0)) + int(data.get("helpful", 0))) / 10
        return {"key": "judge", "score": score, "comment": str(data.get("reason", ""))[:500]}

    return judge


# ------------------------------------------------------------------- run it
async def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["counsellor", "courses"])
    ap.add_argument("--prefix", default="nexted-ai")
    args = ap.parse_args()

    from langsmith import Client
    from langsmith.evaluation import aevaluate

    from app.config import get_settings
    from app.core.profile import StudentProfile
    from app.kb.ingest import hydrate
    from app.wiring import build_counsellor

    settings = get_settings()
    if not settings.langsmith_api_key:
        raise SystemExit("Set LANGSMITH_API_KEY in .env first.")
    import os

    os.environ.setdefault("LANGSMITH_API_KEY", settings.langsmith_api_key)
    os.environ.setdefault("LANGSMITH_ENDPOINT", settings.langsmith_endpoint)

    client = Client(api_key=settings.langsmith_api_key, api_url=settings.langsmith_endpoint)
    cases = [c for c in CASES if not args.only or c["inputs"]["feature"] == args.only]
    name = DATASET + (f"-{args.only}" if args.only else "")
    if client.has_dataset(dataset_name=name):
        dataset = client.read_dataset(dataset_name=name)
    else:
        dataset = client.create_dataset(dataset_name=name, description="nextED AI regression cases")
        client.create_examples(inputs=[c["inputs"] for c in cases], outputs=[c["outputs"] for c in cases],
                               dataset_id=dataset.id)
        print(f"Created dataset {name} with {len(cases)} cases")

    service = build_counsellor(settings)
    if service.kb is not None and await service.kb.open():
        await hydrate(service.kb, service.store)

    counter = {"n": 0}

    async def target(inputs: dict) -> dict:
        counter["n"] += 1
        sid = f"eval-{counter['n']}"  # test ids: their own daily allowance and memory
        profile = StudentProfile.model_validate(inputs.get("profile") or {})
        if inputs["feature"] == "courses":
            out = await service.courses(sid, profile, inputs.get("query", ""))
            return {"feature": "courses", "courses": out["courses"], "sources": len(out["sources"])}
        out = await service.counsellor(sid, profile, inputs["message"], [])
        return {"feature": "counsellor", "reply": out["reply"], "office": out.get("office")}

    results = await aevaluate(
        target,
        data=name,
        evaluators=[mentions, uses_profile, no_invented_fee, office_card, subject_match, not_stuck,
                    make_judge(service.llm)],
        experiment_prefix=args.prefix,
        max_concurrency=2,
        client=client,
    )
    print("Done. Open the experiment link above (or smith.langchain.com -> Datasets -> "
          f"{name}) to see every score, compare runs and read the judge's reasons.")
    if service.kb is not None:
        await service.kb.close()
    return results


if __name__ == "__main__":
    asyncio.run(main())
