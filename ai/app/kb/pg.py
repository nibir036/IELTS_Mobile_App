"""PostgreSQL + pgvector storage for the knowledge base.

Uses psycopg 3's synchronous pool, called through worker threads. That is
deliberate: psycopg's async mode refuses Windows' default event loop, and
this service is developed on Windows.

Tables (created on first start, safe to re-run):

  kb_items          one row per course / scholarship, the full record as
                    JSON plus a vector of its description
  kb_docs           chunks of knowledge documents (knowledge/*.md|txt)
  student_profiles  each student's latest profile and its vector
  student_searches  what each student searched and was shown
  chat_messages     the counsellor conversation, per student
  kb_meta           settings the tables were built with (vector size)
"""
from __future__ import annotations

import asyncio
import json
import logging
from typing import Any, Sequence

log = logging.getLogger(__name__)


def _vec(values: Sequence[float] | None) -> str | None:
    """A vector as pgvector's text form, '[0.1,0.2,...]'."""
    if not values:
        return None
    return "[" + ",".join(f"{float(v):.6f}" for v in values) + "]"


class KnowledgeBase:
    def __init__(self, database_url: str, dim: int, schema: str = "") -> None:
        self.database_url = database_url
        # Own schema (e.g. "nexted_ai") so the tables can sit in a shared
        # database without mixing with anyone else's. '' = database default.
        self.schema = schema
        self.dim = dim
        self._pool = None
        self.ready = False
        self.vectors = dim > 0
        self.error = ""

    @property
    def _cast(self) -> str:
        """Type cast for a vector parameter (none when vectors are off)."""
        return "::vector" if self.vectors else ""

    # ------------------------------------------------------------ lifecycle
    async def open(self) -> bool:
        try:
            await asyncio.to_thread(self._open_sync)
            self.ready = True
            log.info("knowledge base: connected (vectors: %s)", f"{self.dim} dims" if self.vectors else "off")
        except Exception as exc:  # noqa: BLE001
            self.ready = False
            self.error = f"{type(exc).__name__}: {exc}"
            log.error("knowledge base: could not open the database - %s", self.error)
        return self.ready

    def _open_sync(self) -> None:
        from psycopg_pool import ConnectionPool

        schema = self.schema

        def configure(conn) -> None:
            # Every pooled connection works in our schema first, then public
            # (where the pgvector type may already be installed).
            if schema:
                conn.execute(f'CREATE SCHEMA IF NOT EXISTS "{schema}"')
                conn.execute(f'SET search_path TO "{schema}", public')

        self._pool = ConnectionPool(
            self.database_url, min_size=1, max_size=8, open=True, timeout=10,
            kwargs={"autocommit": True}, configure=configure,
        )
        self._pool.wait(timeout=10)
        self._migrate()

    async def close(self) -> None:
        if self._pool is not None:
            await asyncio.to_thread(self._pool.close)

    def _exec(self, sql: str, params: Sequence[Any] | None = None, fetch: str = "") -> Any:
        with self._pool.connection() as conn:
            cur = conn.execute(sql, params or ())
            if fetch == "all":
                return cur.fetchall()
            if fetch == "one":
                return cur.fetchone()
            return None

    async def run(self, sql: str, params: Sequence[Any] | None = None, fetch: str = "") -> Any:
        return await asyncio.to_thread(self._exec, sql, params, fetch)

    def _migrate(self) -> None:
        vec = f"vector({self.dim})" if self.vectors else "text"
        if self.vectors:
            self._exec("CREATE EXTENSION IF NOT EXISTS vector")
        self._exec("CREATE TABLE IF NOT EXISTS kb_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")

        # A different embedding model means a different vector size. The old
        # vectors are useless then: drop them and let the next sync rebuild.
        row = self._exec("SELECT value FROM kb_meta WHERE key = 'dim'", fetch="one")
        old_dim = int(row[0]) if row else None
        rebuild = old_dim is not None and old_dim != self.dim

        self._exec(f"""
            CREATE TABLE IF NOT EXISTS kb_items (
              id TEXT PRIMARY KEY,
              kind TEXT NOT NULL,
              title TEXT NOT NULL DEFAULT '',
              org TEXT NOT NULL DEFAULT '',
              country TEXT NOT NULL DEFAULT '',
              level TEXT NOT NULL DEFAULT '',
              subject TEXT NOT NULL DEFAULT '',
              content TEXT NOT NULL DEFAULT '',
              content_hash TEXT NOT NULL DEFAULT '',
              data JSONB NOT NULL,
              embedding {vec},
              updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )""")
        self._exec("CREATE INDEX IF NOT EXISTS kb_items_kind_idx ON kb_items (kind)")
        self._exec(f"""
            CREATE TABLE IF NOT EXISTS kb_docs (
              id TEXT PRIMARY KEY,
              source TEXT NOT NULL,
              title TEXT NOT NULL DEFAULT '',
              chunk INT NOT NULL DEFAULT 0,
              content TEXT NOT NULL,
              content_hash TEXT NOT NULL DEFAULT '',
              embedding {vec},
              updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )""")
        self._exec(f"""
            CREATE TABLE IF NOT EXISTS student_profiles (
              student_id TEXT PRIMARY KEY,
              profile JSONB NOT NULL,
              profile_hash TEXT NOT NULL DEFAULT '',
              embedding {vec},
              updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )""")
        self._exec("""
            CREATE TABLE IF NOT EXISTS student_searches (
              id BIGSERIAL PRIMARY KEY,
              student_id TEXT NOT NULL,
              kind TEXT NOT NULL,
              query TEXT NOT NULL DEFAULT '',
              result_ids JSONB NOT NULL DEFAULT '[]',
              created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )""")
        self._exec("CREATE INDEX IF NOT EXISTS student_searches_idx ON student_searches (student_id, kind, id DESC)")
        self._exec("""
            CREATE TABLE IF NOT EXISTS chat_messages (
              id BIGSERIAL PRIMARY KEY,
              student_id TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )""")
        self._exec("CREATE INDEX IF NOT EXISTS chat_messages_idx ON chat_messages (student_id, id DESC)")
        # What came with a reply (profile details saved, the office card), so
        # a reloaded thread looks exactly like it did.
        self._exec("ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS meta JSONB NOT NULL DEFAULT '{}'")
        # Long-term memory: one running summary per student of everything
        # older than the recent messages the counsellor reads word for word.
        self._exec("""
            CREATE TABLE IF NOT EXISTS student_memory (
              student_id TEXT PRIMARY KEY,
              summary TEXT NOT NULL DEFAULT '',
              upto_id BIGINT NOT NULL DEFAULT 0,
              updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
            )""")

        if self.vectors and rebuild:
            log.warning("embedding size changed (%s -> %s): rebuilding vectors", old_dim, self.dim)
            for table in ("kb_items", "kb_docs", "student_profiles"):
                self._exec(f"ALTER TABLE {table} DROP COLUMN IF EXISTS embedding")
                self._exec(f"ALTER TABLE {table} ADD COLUMN embedding vector({self.dim})")
                self._exec(f"UPDATE {table} SET " + ("profile_hash" if table == "student_profiles" else "content_hash") + " = ''")
        if self.vectors:
            # HNSW: fast nearest-neighbour search that stays fast as it grows.
            self._exec("CREATE INDEX IF NOT EXISTS kb_items_vec_idx ON kb_items USING hnsw (embedding vector_cosine_ops)")
            self._exec("CREATE INDEX IF NOT EXISTS kb_docs_vec_idx ON kb_docs USING hnsw (embedding vector_cosine_ops)")
        self._exec(
            "INSERT INTO kb_meta (key, value) VALUES ('dim', %s) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value",
            (str(self.dim),),
        )

    # ------------------------------------------------------------ catalogue
    async def item_hashes(self, kind: str) -> dict[str, str]:
        rows = await self.run(
            "SELECT id, content_hash FROM kb_items WHERE kind = %s", (kind,), fetch="all"
        )
        return {r[0]: r[1] for r in rows or []}

    async def upsert_items(self, rows: list[dict]) -> None:
        """rows: {id, kind, title, org, country, level, subject, content, hash, data, embedding}"""
        if not rows:
            return

        cast = self._cast

        def run() -> None:
            with self._pool.connection() as conn:
                with conn.transaction():
                    for r in rows:
                        conn.execute(
                            f"""
                            INSERT INTO kb_items (id, kind, title, org, country, level, subject,
                                                  content, content_hash, data, embedding, updated_at)
                            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s::jsonb,%s{cast}, now())
                            ON CONFLICT (id) DO UPDATE SET
                              kind = EXCLUDED.kind, title = EXCLUDED.title, org = EXCLUDED.org,
                              country = EXCLUDED.country, level = EXCLUDED.level,
                              subject = EXCLUDED.subject, content = EXCLUDED.content,
                              content_hash = EXCLUDED.content_hash, data = EXCLUDED.data,
                              embedding = COALESCE(EXCLUDED.embedding, kb_items.embedding),
                              updated_at = now()
                            """,
                            (
                                r["id"], r["kind"], r["title"], r["org"], r["country"], r["level"],
                                r["subject"], r["content"], r["hash"], json.dumps(r["data"], ensure_ascii=False),
                                _vec(r.get("embedding")) if self.vectors else None,
                            ),
                        )

        await asyncio.to_thread(run)

    async def all_items(self, kind: str) -> list[dict]:
        rows = await self.run("SELECT data FROM kb_items WHERE kind = %s", (kind,), fetch="all")
        out = []
        for (data,) in rows or []:
            out.append(data if isinstance(data, dict) else json.loads(data))
        return out

    async def count(self, kind: str) -> int:
        row = await self.run("SELECT count(*) FROM kb_items WHERE kind = %s", (kind,), fetch="one")
        return int(row[0]) if row else 0

    async def nearest_items(
        self, kind: str, query_vec: list[float] | None, profile_vec: list[float] | None, limit: int = 60
    ) -> list[tuple[str, float, float]]:
        """(id, similarity to the query, similarity to the student) for the closest rows."""
        if not self.vectors or not (query_vec or profile_vec):
            return []
        q = _vec(query_vec or profile_vec)
        p = _vec(profile_vec or query_vec)
        rows = await self.run(
            """
            SELECT id, 1 - (embedding <=> %s::vector) AS qs, 1 - (embedding <=> %s::vector) AS ps
            FROM kb_items
            WHERE kind = %s AND embedding IS NOT NULL
            ORDER BY embedding <=> %s::vector
            LIMIT %s
            """,
            (q, p, kind, q, limit),
            fetch="all",
        )
        return [(r[0], float(r[1] or 0), float(r[2] or 0)) for r in rows or []]

    # ------------------------------------------------------------ documents
    async def doc_hashes(self, source: str) -> dict[str, str]:
        rows = await self.run("SELECT id, content_hash FROM kb_docs WHERE source = %s", (source,), fetch="all")
        return {r[0]: r[1] for r in rows or []}

    async def replace_doc(self, source: str, title: str, chunks: list[tuple[str, str, list[float] | None]]) -> None:
        """chunks: (content, hash, embedding). Replaces every chunk of the source."""

        cast = self._cast

        def run() -> None:
            with self._pool.connection() as conn:
                with conn.transaction():
                    conn.execute("DELETE FROM kb_docs WHERE source = %s", (source,))
                    for i, (content, digest, emb) in enumerate(chunks):
                        conn.execute(
                            f"""INSERT INTO kb_docs (id, source, title, chunk, content, content_hash, embedding)
                               VALUES (%s,%s,%s,%s,%s,%s,%s{cast})""",
                            (f"{source}#{i}", source, title, i, content, digest,
                             _vec(emb) if self.vectors else None),
                        )

        await asyncio.to_thread(run)

    async def remove_docs_except(self, sources: Sequence[str]) -> int:
        rows = await self.run("SELECT DISTINCT source FROM kb_docs", fetch="all")
        gone = [r[0] for r in rows or [] if r[0] not in set(sources)]
        for source in gone:
            await self.run("DELETE FROM kb_docs WHERE source = %s", (source,))
        return len(gone)

    async def search_docs(self, query_vec: list[float] | None, keywords: Sequence[str], limit: int = 4) -> list[dict]:
        if self.vectors and query_vec:
            rows = await self.run(
                """SELECT title, content, 1 - (embedding <=> %s::vector) AS score FROM kb_docs
                   WHERE embedding IS NOT NULL ORDER BY embedding <=> %s::vector LIMIT %s""",
                (_vec(query_vec), _vec(query_vec), limit),
                fetch="all",
            )
            return [{"title": r[0], "content": r[1], "score": float(r[2] or 0)} for r in rows or []]
        words = [w for w in keywords if len(w) > 2][:4]
        if not words:
            return []
        clause = " OR ".join(["content ILIKE %s"] * len(words))
        rows = await self.run(
            f"SELECT title, content FROM kb_docs WHERE {clause} LIMIT %s",
            [*(f"%{w}%" for w in words), limit],
            fetch="all",
        )
        return [{"title": r[0], "content": r[1], "score": 0.5} for r in rows or []]

    # ------------------------------------------------------------ students
    async def profile_vector(self, student_id: str, profile: dict, digest: str, embed) -> list[float] | None:
        """The student's vector, re-made only when their profile changed."""
        row = await self.run(
            "SELECT profile_hash, embedding::text FROM student_profiles WHERE student_id = %s"
            if self.vectors else
            "SELECT profile_hash, NULL FROM student_profiles WHERE student_id = %s",
            (student_id,), fetch="one",
        )
        if row and row[0] == digest and row[1]:
            return [float(x) for x in str(row[1]).strip("[]").split(",") if x]
        vector = await embed() if self.vectors else None
        await self.run(
            f"""INSERT INTO student_profiles (student_id, profile, profile_hash, embedding, updated_at)
               VALUES (%s, %s::jsonb, %s, %s{self._cast}, now())
               ON CONFLICT (student_id) DO UPDATE SET profile = EXCLUDED.profile,
                 profile_hash = EXCLUDED.profile_hash, embedding = EXCLUDED.embedding, updated_at = now()""",
            (student_id, json.dumps(profile, ensure_ascii=False), digest, _vec(vector) if self.vectors else None),
        )
        return vector

    async def record_search(self, student_id: str, kind: str, query: str, ids: Sequence[str]) -> None:
        await self.run(
            "INSERT INTO student_searches (student_id, kind, query, result_ids) VALUES (%s,%s,%s,%s::jsonb)",
            (student_id, kind, query, json.dumps(list(ids))),
        )

    async def recent_searches(self, student_id: str, kind: str = "", limit: int = 5) -> list[dict]:
        if kind:
            rows = await self.run(
                """SELECT kind, query, result_ids FROM student_searches WHERE student_id = %s AND kind = %s
                   ORDER BY id DESC LIMIT %s""",
                (student_id, kind, limit), fetch="all",
            )
        else:
            rows = await self.run(
                "SELECT kind, query, result_ids FROM student_searches WHERE student_id = %s ORDER BY id DESC LIMIT %s",
                (student_id, limit), fetch="all",
            )
        out = []
        for k, q, ids in rows or []:
            out.append({"kind": k, "query": q, "ids": ids if isinstance(ids, list) else json.loads(ids or "[]")})
        return out

    async def add_message(self, student_id: str, role: str, content: str, meta: dict | None = None) -> None:
        if content.strip():
            await self.run(
                "INSERT INTO chat_messages (student_id, role, content, meta) VALUES (%s,%s,%s,%s::jsonb)",
                (student_id, role, content[:8000], json.dumps(meta or {}, ensure_ascii=False, default=str)),
            )

    async def thread(self, student_id: str, limit: int = 200) -> list[dict]:
        """The student's one conversation, oldest first, for the app."""
        rows = await self.run(
            """SELECT id, role, content, meta, created_at FROM chat_messages
               WHERE student_id = %s ORDER BY id DESC LIMIT %s""",
            (student_id, limit), fetch="all",
        )
        out = []
        for row_id, role, content, meta, at in reversed(rows or []):
            meta = meta if isinstance(meta, dict) else json.loads(meta or "{}")
            out.append({"id": row_id, "role": role, "content": content,
                        "at": at.isoformat() if at else "", **meta})
        return out

    async def clear_thread(self, student_id: str) -> None:
        await self.run("DELETE FROM chat_messages WHERE student_id = %s", (student_id,))
        await self.run("DELETE FROM student_memory WHERE student_id = %s", (student_id,))

    async def memory(self, student_id: str) -> tuple[str, int]:
        """(summary of the older conversation, last message id it covers)."""
        row = await self.run(
            "SELECT summary, upto_id FROM student_memory WHERE student_id = %s", (student_id,), fetch="one")
        return (row[0], int(row[1])) if row else ("", 0)

    async def messages_after(self, student_id: str, after_id: int, limit: int = 60) -> list[dict]:
        rows = await self.run(
            """SELECT id, role, content FROM chat_messages WHERE student_id = %s AND id > %s
               ORDER BY id ASC LIMIT %s""",
            (student_id, after_id, limit), fetch="all",
        )
        return [{"id": r[0], "role": r[1], "content": r[2]} for r in rows or []]

    async def save_memory(self, student_id: str, summary: str, upto_id: int) -> None:
        await self.run(
            """INSERT INTO student_memory (student_id, summary, upto_id, updated_at)
               VALUES (%s, %s, %s, now())
               ON CONFLICT (student_id) DO UPDATE SET summary = EXCLUDED.summary,
                 upto_id = EXCLUDED.upto_id, updated_at = now()""",
            (student_id, summary[:6000], upto_id),
        )

    async def recent_messages(self, student_id: str, limit: int = 12) -> list[dict]:
        rows = await self.run(
            "SELECT role, content FROM chat_messages WHERE student_id = %s ORDER BY id DESC LIMIT %s",
            (student_id, limit), fetch="all",
        )
        return [{"role": r[0], "content": r[1]} for r in reversed(rows or [])]
