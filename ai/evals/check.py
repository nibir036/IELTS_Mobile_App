"""Is the knowledge base really working? Measured, not eyeballed.

    python -m evals.check            database, vectors, retrieval, personalisation
    python -m evals.check --live     + the running service: streaming and a real search
                                     (start uvicorn first; spends a few AI credits)

Every check prints PASS / WARN / FAIL and a number, so "it gave a nice answer"
is never the evidence. What each one proves:

  1 database      connected, pgvector installed, tables + HNSW indexes exist
  2 coverage      every row and document chunk actually has a vector of the right size
  3 embeddings    the model puts related texts closer than unrelated ones
  4 retrieval     recall@1 / recall@5: each row, searched by its own description,
                  comes back near the top (if not, search is broken whatever it "looks" like)
  5 documents     each knowledge chunk is found by its own opening lines
  6 personal      two different students with an empty search get different lists
  7 index         the HNSW index is actually used once the table is big enough
  8 live stream   (--live) first token time, number of pieces, pieces == final reply
  9 live search   (--live) a Nursing/Canada student gets Nursing rows, not Computer Science
"""
from __future__ import annotations

import argparse
import asyncio
import json
import math
import sys
import time

RESULTS: list[tuple[str, str, str]] = []


def report(status: str, name: str, detail: str) -> None:
    RESULTS.append((status, name, detail))
    print(f"  [{status:4}] {name}: {detail}")


def cosine(a, b) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


# ------------------------------------------------------------------ offline
async def check_database(kb) -> bool:
    print("\n1. Database")
    row = await kb.run("SELECT extversion FROM pg_extension WHERE extname = 'vector'", fetch="one")
    if not row:
        report("FAIL", "pgvector", "extension not installed - run CREATE EXTENSION vector; in pgAdmin")
        return False
    major, minor = (int(x) for x in row[0].split(".")[:2])
    ok = (major, minor) >= (0, 5)
    report("PASS" if ok else "FAIL", "pgvector", f"version {row[0]}" + ("" if ok else " (HNSW needs 0.5+)"))

    tables = {r[0] for r in await kb.run(
        "SELECT tablename FROM pg_tables WHERE schemaname = current_schema()", fetch="all")}
    need = {"kb_meta", "kb_items", "kb_docs", "student_profiles", "student_searches", "chat_messages"}
    missing = need - tables
    report("FAIL" if missing else "PASS", "tables", f"missing {sorted(missing)}" if missing else "all 6 present")

    idx = {r[0] for r in await kb.run(
        "SELECT indexname FROM pg_indexes WHERE schemaname = current_schema()", fetch="all")}
    hnsw = {"kb_items_vec_idx", "kb_docs_vec_idx"} - idx
    report("FAIL" if hnsw else "PASS", "HNSW indexes", f"missing {sorted(hnsw)}" if hnsw else "kb_items + kb_docs")
    return not missing


async def check_coverage(kb) -> None:
    print("\n2. Vector coverage")
    for table, label in (("kb_items", "catalogue rows"), ("kb_docs", "document chunks")):
        total, without, wrong = await kb.run(
            f"""SELECT count(*), count(*) FILTER (WHERE embedding IS NULL),
                       count(*) FILTER (WHERE embedding IS NOT NULL AND vector_dims(embedding) <> %s)
                FROM {table}""", (kb.dim,), fetch="one")
        if total == 0:
            report("WARN", label, "none stored yet")
            continue
        status = "PASS" if without == 0 and wrong == 0 else "FAIL"
        report(status, label, f"{total} stored, {without} without a vector, {wrong} with the wrong size")
    rows = await kb.run("SELECT kind, count(*) FROM kb_items GROUP BY kind ORDER BY kind", fetch="all")
    subjects = await kb.run(
        "SELECT count(DISTINCT lower(subject)), count(DISTINCT lower(country)) FROM kb_items WHERE kind='course'",
        fetch="one")
    detail = ", ".join(f"{k}: {n}" for k, n in rows) or "empty"
    report("PASS" if subjects[0] >= 3 else "WARN", "catalogue variety",
           f"{detail}; {subjects[0]} subjects, {subjects[1]} countries"
           + ("" if subjects[0] >= 3 else " - too uniform: every student will see the same rows until research adds more"))


async def check_embeddings(embedder) -> None:
    print("\n3. Embedding model")
    texts = [
        "BSc Nursing, healthcare degree for registered nurses",
        "Bachelor of Science in Nursing and Midwifery",
        "MSc Computer Science and software engineering",
    ]
    vecs = await embedder.embed_documents(texts)
    q = await embedder.embed_query("I want to study nursing")
    if len(vecs) != 3 or not q:
        report("FAIL", "embed", "the model returned nothing")
        return
    report("PASS" if len(q) == embedder.dim else "FAIL", "dimension", f"{len(q)} (expected {embedder.dim})")
    near, far = cosine(q, vecs[0]), cosine(q, vecs[2])
    pair = cosine(vecs[0], vecs[1])
    ok = near > far + 0.05
    report("PASS" if ok else "FAIL", "meaning",
           f"nursing~nursing {near:.3f}  vs  nursing~computer science {far:.3f}; nursing~midwifery {pair:.3f}")


async def check_retrieval(kb, embedder, limit: int) -> None:
    print("\n4. Retrieval (self-recall)")
    for kind in ("course", "scholarship"):
        rows = await kb.run(
            "SELECT id, content FROM kb_items WHERE kind=%s AND embedding IS NOT NULL ORDER BY random() LIMIT %s",
            (kind, limit), fetch="all")
        if not rows:
            report("WARN", kind, "nothing to test")
            continue
        top1 = top5 = 0
        sims = []
        for row_id, content in rows:
            q = await embedder.embed_query(content)
            near = await kb.nearest_items(kind, q, None, limit=5)
            ids = [n[0] for n in near]
            top1 += bool(ids and ids[0] == row_id)
            top5 += row_id in ids
            if near:
                sims.append(near[0][1])
        n = len(rows)
        r1, r5 = top1 / n, top5 / n
        status = "PASS" if r5 >= 0.9 else ("WARN" if r5 >= 0.7 else "FAIL")
        report(status, kind, f"recall@1 {r1:.0%}, recall@5 {r5:.0%} over {n} rows; "
                             f"mean top similarity {sum(sims) / max(len(sims), 1):.3f}")


async def check_documents(kb, embedder) -> None:
    print("\n5. Knowledge documents (RAG)")
    rows = await kb.run("SELECT title, content FROM kb_docs ORDER BY source, chunk LIMIT 60", fetch="all")
    if not rows:
        report("WARN", "documents", "no documents indexed - add .md files to knowledge/ and restart")
        return
    hit = 0
    for title, content in rows:
        probe = content.strip().split("\n\n")[-1][:300]  # a passage from inside the chunk
        found = await kb.search_docs(await embedder.embed_query(probe), [], limit=3)
        hit += any(f["content"] == content for f in found)
    rate = hit / len(rows)
    report("PASS" if rate >= 0.9 else "FAIL", "chunk recall@3", f"{rate:.0%} of {len(rows)} chunks")


async def check_personal(service) -> None:
    print("\n6. Personalisation")
    from app.core.profile import StudentProfile
    from app.graphs import nodes
    from app.kb import retrieve

    async def top_for(sid: str, profile: StudentProfile) -> list[str]:
        state = service._base_state(sid, profile)
        state.update({"query": "", "kind": "course", "research_enabled": False})
        state.update(await nodes.load_context(state))
        state.update(await nodes.understand(state))  # empty query: no model call
        out = await retrieve.search_courses(state)
        return [c.id for c in out.get("candidates", [])][:5], out.get("search_tier", "")

    a, ta = await top_for("eval-nursing", StudentProfile(subject="Nursing", preferred_country="Canada",
                                                         highest_level="HSC"))
    b, tb = await top_for("eval-cs", StudentProfile(subject="Computer Science", preferred_country="UK",
                                                    highest_level="Bachelor"))
    if not a and not b:
        report("WARN", "two students", "no rows at all")
        return
    overlap = len(set(a) & set(b)) / max(len(set(a) | set(b)), 1)
    status = "PASS" if overlap < 0.6 else "WARN"
    report(status, "two students", f"top-5 overlap {overlap:.0%} (tiers: {ta} / {tb})"
           + ("" if status == "PASS" else " - catalogue too small to tell them apart; it fills up as students search"))


async def check_index(kb) -> None:
    print("\n7. Index use")
    n = await kb.count("course") + await kb.count("scholarship")
    vec = "[" + ",".join(["0.01"] * kb.dim) + "]"
    plan = await kb.run(
        "EXPLAIN SELECT id FROM kb_items ORDER BY embedding <=> %s::vector LIMIT 10", (vec,), fetch="all")
    text = " ".join(r[0] for r in plan)
    used = "kb_items_vec_idx" in text
    if used:
        report("PASS", "HNSW", "planner uses the vector index")
    else:
        report("PASS" if n < 1000 else "WARN", "HNSW",
               f"sequential scan with {n} rows" + (" (normal while small)" if n < 1000 else " - check the index"))


# --------------------------------------------------------------------- live
async def check_live(base: str, token: str) -> None:
    import httpx

    print("\n8. Live streaming (spends 1 credit)")
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    body = {"studentId": "eval-live", "message": "What IELTS score do I need for a UK masters?",
            "profile": {"subject": "Nursing", "preferredCountry": "UK", "ieltsBand": "6.0"}, "history": []}
    pieces, final, first, event = [], None, None, ""
    start = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=180) as client:
            async with client.stream("POST", f"{base}/v1/ai/counsellor/stream", json=body, headers=headers) as res:
                if res.status_code != 200:
                    report("FAIL", "stream", f"HTTP {res.status_code}: {(await res.aread())[:200]!r}")
                    return
                async for line in res.aiter_lines():
                    if line.startswith("event:"):
                        event = line[6:].strip()
                    elif line.startswith("data:"):
                        data = json.loads(line[5:])
                        if event == "token":
                            first = first or time.perf_counter() - start
                            pieces.append(data["t"])
                        elif event == "done":
                            final = data
                        elif event == "error":
                            report("FAIL", "stream", f"error event {data}")
                            return
    except httpx.ConnectError:
        report("FAIL", "stream", f"nothing listening at {base} - start uvicorn")
        return
    total = time.perf_counter() - start
    if not final:
        report("FAIL", "stream", "no done event")
        return
    streamed = "".join(pieces).strip()
    report("PASS" if len(pieces) > 5 else "FAIL", "typing",
           f"{len(pieces)} pieces, first after {first or 0:.1f}s, whole answer {total:.1f}s"
           + ("" if len(pieces) > 5 else " - arrived in one go: is langgraph>=0.3 installed?"))
    same = final.get("reply", "").startswith(streamed[:200]) if streamed else False
    report("PASS" if same else "WARN", "consistency", "streamed text matches the final reply"
           if same else "final reply differs from what was typed (restriction or invitation added)")

    print("\n9. Live course search (spends credits; may research the web)")
    body = {"studentId": "eval-live", "query": "",
            "profile": {"subject": "Nursing", "preferredCountry": "Canada", "highestLevel": "HSC"}}
    async with httpx.AsyncClient(timeout=180) as client:
        res = await client.post(f"{base}/v1/ai/courses", json=body, headers=headers)
    rows = res.json().get("courses", []) if res.status_code == 200 else []
    good = [r for r in rows if "nurs" in f"{r.get('title', '')} {r.get('subject', '')}".lower()]
    cs = [r for r in rows if "computer" in f"{r.get('title', '')} {r.get('subject', '')}".lower()]
    precision = len(good) / len(rows) if rows else 0
    report("PASS" if precision >= 0.6 else ("WARN" if rows else "FAIL"), "subject precision",
           f"{len(good)}/{len(rows)} nursing, {len(cs)} computer science; "
           f"sources read: {len(res.json().get('sources', [])) if res.status_code == 200 else 0}")


# --------------------------------------------------------------------- main
async def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", action="store_true", help="also test the running service")
    ap.add_argument("--url", default="http://127.0.0.1:8000")
    ap.add_argument("--rows", type=int, default=40, help="rows sampled for the recall test")
    args = ap.parse_args()

    from app.config import get_settings
    from app.wiring import build_counsellor

    settings = get_settings()
    if not settings.database_url:
        print("DATABASE_URL is empty in .env - the knowledge base is off.")
        return 1
    service = build_counsellor(settings)
    kb, embedder = service.kb, service.embedder
    print(f"Database: {settings.database_url.rsplit('@', 1)[-1]}   embeddings: {embedder.name} "
          f"{getattr(embedder, 'model_name', '')} ({embedder.dim} dims)")
    if not await kb.open():
        print("Could not connect:", kb.error)
        return 1
    from app.kb.ingest import hydrate, ingest_knowledge, sync_store

    await hydrate(kb, service.store)
    await sync_store(kb, service.store, embedder)
    await ingest_knowledge(kb, embedder, settings.knowledge_dir)

    if await check_database(kb) and kb.vectors:
        await check_coverage(kb)
        await check_embeddings(embedder)
        await check_retrieval(kb, embedder, args.rows)
        await check_documents(kb, embedder)
        await check_personal(service)
        await check_index(kb)
    elif not kb.vectors:
        report("WARN", "vectors", "EMBEDDINGS_PROVIDER is none or fastembed is not installed - keyword search only")
    if args.live:
        await check_live(args.url.rstrip("/"), settings.service_token)
    await kb.close()

    fails = sum(s == "FAIL" for s, _, _ in RESULTS)
    warns = sum(s == "WARN" for s, _, _ in RESULTS)
    print(f"\n{len(RESULTS) - fails - warns} passed, {warns} warnings, {fails} failed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
