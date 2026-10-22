"""Building the service: store, model, search, fetcher, tracing.

Kept out of main.py so that importing the wiring does not require FastAPI.
`try.py` and the tests rely on that.
"""
from __future__ import annotations

import logging

from app.api.service import Counsellor
from app.config import get_settings
from app.providers.factory import build_llm
from app.store.json_store import Store
from app.tools.fetch import FetchPolicy, PageFetcher
from app.tools.search_web import build_web_search
from app.tracing import configure as configure_tracing

log = logging.getLogger("nexted.wiring")


def build_counsellor(settings=None) -> Counsellor:
    """Wire everything once. Used by the app and by the tests."""
    settings = settings or get_settings()

    store = Store.open(
        data_dir=settings.data_dir,
        restrictions_file=settings.restrictions_file,
        seed_dir=settings.seed_dir,
        # 0 = unlimited (AI_LIMIT_ENABLED is off).
        daily_limit=settings.daily_ai_limit if settings.ai_limit_enabled else 0,
    )
    if not store.restrictions_active:
        log.warning(
            "No restriction rules loaded. Restriction checking is OFF until a "
            "list is supplied at %s", settings.restrictions_file,
        )

    llm = build_llm(settings)
    log.info("LLM provider: %s", llm.name)

    web_search = build_web_search(
        settings.web_search_provider,
        settings.web_search_api_key,
        settings.fetch_timeout_seconds,
    )
    fetcher = PageFetcher(
        FetchPolicy(
            allowed_domains=settings.allowed_domains,
            funding_domains=settings.funding_domains,
            timeout_seconds=settings.fetch_timeout_seconds,
            max_bytes=settings.max_page_bytes,
            user_agent=settings.user_agent,
        )
    )
    log.info(
        "research: %s (search=%s, courses=%s, awards=%s)",
        "on" if settings.research_enabled and web_search.name != "none" else "off",
        web_search.name,
        ",".join(d for d in settings.allowed_domains
                 if d not in settings.funding_domains) or "(none)",
        ",".join(settings.funding_domains) or "(none)",
    )

    kb = embedder = None
    if settings.database_url:
        from app.kb.embed import build_embedder
        from app.kb.pg import KnowledgeBase

        embedder = build_embedder(settings)
        kb = KnowledgeBase(settings.database_url, embedder.dim, settings.kb_schema)
        log.info("knowledge base: PostgreSQL, embeddings=%s (%s dims)", embedder.name, embedder.dim)
    else:
        log.info("knowledge base: off (no DATABASE_URL) - JSON files only")

    configure_tracing(settings)
    return Counsellor(settings, store, llm, web_search, fetcher, kb=kb, embedder=embedder)