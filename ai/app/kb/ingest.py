"""Keeping the knowledge base and the catalogue in step.

  hydrate(store)        on start: every row in PostgreSQL goes into memory,
                        so all processes see everything ever found
  sync_store(store)     after a request: new or changed rows go into
                        PostgreSQL, with a fresh vector (unchanged rows cost
                        nothing - compared by hash)
  ingest_knowledge()    knowledge/*.md|*.txt|*.json -> chunks with vectors,
                        for the counsellor's answers (RAG)

Run by hand:   python -m app.kb.ingest          (re-index everything)
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import pathlib
import re

from app.store.json_store import (
    course_from_json,
    course_to_json,
    scholarship_from_json,
    scholarship_to_json,
)

log = logging.getLogger(__name__)


def _digest(text: str) -> str:
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


def _fact_text(fact) -> str:
    value = getattr(fact, "value", None)
    return "" if value in (None, "") else str(value)


def course_text(c) -> str:
    """What a course is about, in words, for its vector."""
    parts = [
        c.title,
        f"{c.level} {c.subject}".strip(),
        f"at {c.university}" if c.university else "",
        f"in {c.country}" if c.country else "",
        f"duration {c.duration}" if c.duration else "",
        f"intake {c.intake}" if c.intake else "",
        f"tuition {_fact_text(c.tuition)}" if c.tuition else "",
        f"IELTS {_fact_text(c.min_ielts)}" if c.min_ielts else "",
    ]
    return ". ".join(p for p in parts if p)


def scholarship_text(s) -> str:
    parts = [
        s.title,
        f"offered by {s.provider}" if getattr(s, "provider", "") else "",
        f"for study in {s.country}" if s.country else "",
        f"level {s.level}" if getattr(s, "level", "") else "",
        f"amount {_fact_text(s.amount)}" if getattr(s, "amount", None) else "",
        "open to " + ", ".join(s.nationalities) if getattr(s, "nationalities", None) else "",
    ]
    return ". ".join(p for p in parts if p)


async def hydrate(kb, store) -> int:
    """Load every stored row from PostgreSQL into the in-memory store."""
    added = 0
    for kind, parse, target in (
        ("course", course_from_json, store.courses),
        ("scholarship", scholarship_from_json, store.scholarships),
    ):
        for raw in await kb.all_items(kind):
            try:
                row = parse(raw)
            except Exception as exc:  # noqa: BLE001
                log.warning("skipping a stored %s that could not be read: %s", kind, exc)
                continue
            if row.id not in target:
                added += 1
            target[row.id] = row
    if added:
        log.info("knowledge base: %s row(s) loaded from PostgreSQL", added)
    return added


async def sync_store(kb, store, embedder) -> int:
    """Write new and changed catalogue rows to PostgreSQL, with vectors."""
    written = 0
    for kind, rows, to_json, to_text, org in (
        ("course", store.courses, course_to_json, course_text, "university"),
        ("scholarship", store.scholarships, scholarship_to_json, scholarship_text, "provider"),
    ):
        known = await kb.item_hashes(kind)
        pending = []
        for row in list(rows.values()):
            data = to_json(row)
            digest = _digest(json.dumps(data, sort_keys=True, default=str))
            if known.get(row.id) == digest:
                continue
            pending.append((row, data, digest, to_text(row)))
        if not pending:
            continue
        vectors: list = []
        try:
            vectors = await embedder.embed_documents([p[3] for p in pending])
        except Exception as exc:  # noqa: BLE001
            log.warning("embedding %s row(s) failed (%s); stored without vectors for now", len(pending), exc)
        payload = []
        for i, (row, data, digest, text) in enumerate(pending):
            payload.append({
                "id": row.id,
                "kind": kind,
                "title": row.title or "",
                "org": getattr(row, org, "") or "",
                "country": row.country or "",
                "level": getattr(row, "level", "") or "",
                "subject": getattr(row, "subject", "") or "",
                "content": text,
                # no vector yet -> no hash, so the next sync tries again
                "hash": digest if (i < len(vectors) or not kb.vectors) else "",
                "data": data,
                "embedding": vectors[i] if i < len(vectors) else None,
            })
        await kb.upsert_items(payload)
        written += len(payload)
    if written:
        log.info("knowledge base: %s catalogue row(s) written", written)
    return written


# ------------------------------------------------------------------ documents
def _chunks(text: str, size: int = 1200, overlap: int = 150) -> list[str]:
    """Split on paragraphs, then pack paragraphs into ~size-character chunks."""
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    out: list[str] = []
    buf = ""
    for para in paras:
        if len(buf) + len(para) + 2 <= size:
            buf = f"{buf}\n\n{para}" if buf else para
            continue
        if buf:
            out.append(buf)
        while len(para) > size:
            out.append(para[:size])
            para = para[size - overlap:]
        buf = para
    if buf:
        out.append(buf)
    return out


def _read_doc(path: pathlib.Path) -> tuple[str, str]:
    """(title, text) for .md / .txt / .json files."""
    raw = path.read_text(encoding="utf-8", errors="ignore")
    if path.suffix.lower() == ".json":
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return path.stem, raw
        items = data if isinstance(data, list) else [data]
        lines = []
        for item in items:
            if isinstance(item, dict):
                q, a = item.get("question") or item.get("q"), item.get("answer") or item.get("a")
                if q and a:
                    lines.append(f"Q: {q}\nA: {a}")
                else:
                    lines.append("\n".join(f"{k}: {v}" for k, v in item.items()))
            else:
                lines.append(str(item))
        return path.stem.replace("_", " "), "\n\n".join(lines)
    title = path.stem.replace("_", " ")
    first = raw.lstrip().splitlines()[0] if raw.strip() else ""
    if first.startswith("#"):
        title = first.lstrip("# ").strip() or title
    return title, raw


async def ingest_knowledge(kb, embedder, folder: str) -> int:
    """Index every document in `folder`; unchanged files are skipped."""
    base = pathlib.Path(folder)
    if not base.exists():
        return 0
    files = sorted(p for p in base.rglob("*") if p.suffix.lower() in {".md", ".txt", ".json"}
                   and p.name.lower() != "readme.md")
    done = 0
    sources = []
    for path in files:
        source = str(path.relative_to(base)).replace("\\", "/")
        sources.append(source)
        title, text = _read_doc(path)
        chunks = _chunks(text)
        digests = [_digest(c) for c in chunks]
        known = await kb.doc_hashes(source)
        if sorted(known.values()) == sorted(digests) and known:
            continue
        vectors: list = []
        try:
            vectors = await embedder.embed_documents([f"{title}\n\n{c}" for c in chunks])
        except Exception as exc:  # noqa: BLE001
            log.warning("embedding %s failed: %s", source, exc)
        await kb.replace_doc(
            source, title,
            [(c, d if (i < len(vectors) or not kb.vectors) else "", vectors[i] if i < len(vectors) else None)
             for i, (c, d) in enumerate(zip(chunks, digests))],
        )
        done += 1
    removed = await kb.remove_docs_except(sources)
    if done or removed:
        log.info("knowledge base: %s document(s) indexed, %s removed", done, removed)
    return done


async def _main() -> None:
    from app.config import get_settings
    from app.kb.embed import build_embedder
    from app.kb.pg import KnowledgeBase
    from app.store.json_store import Store

    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    settings = get_settings()
    if not settings.database_url:
        print("DATABASE_URL is not set in .env - nothing to index.")
        return
    embedder = build_embedder(settings)
    kb = KnowledgeBase(settings.database_url, embedder.dim, settings.kb_schema)
    if not await kb.open():
        print("Could not open the database:", kb.error)
        return
    store = Store.open(settings.data_dir, settings.restrictions_file, settings.seed_dir, settings.daily_ai_limit)
    await hydrate(kb, store)
    rows = await sync_store(kb, store, embedder)
    docs = await ingest_knowledge(kb, embedder, settings.knowledge_dir)
    print(f"Done: {rows} catalogue row(s) and {docs} document(s) indexed.")
    print(f"In the database: {await kb.count('course')} courses, {await kb.count('scholarship')} scholarships.")
    await kb.close()


if __name__ == "__main__":
    asyncio.run(_main())
