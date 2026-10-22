"""Settings, read from the environment (and a .env file if present).

Nothing here is ever returned to a student.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from functools import lru_cache


def _bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, "") or default)
    except ValueError:
        return default


def _float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, "") or default)
    except ValueError:
        return default


def _pg_url(raw: str) -> str:
    """A PostgreSQL URL psycopg accepts.

    The IELTS app's URL is written for Prisma (`...?schema=public`); libpq
    rejects the `schema` parameter, so it is dropped here. The schema the
    tables go in is KB_SCHEMA instead.
    """
    url = raw.strip().strip('"').strip("'")
    if "?" not in url:
        return url
    base, query = url.split("?", 1)
    keep = [p for p in query.split("&") if p and not p.lower().startswith("schema=")]
    return base + ("?" + "&".join(keep) if keep else "")


def _schema_name(raw: str) -> str:
    """A plain lower-case schema name, or '' (= the database default)."""
    name = raw.strip().strip('"').lower()
    return name if re.fullmatch(r"[a-z_][a-z0-9_]{0,62}", name) else ""


def _load_dotenv() -> None:
    """Minimal .env reader so there is no hard dependency on python-dotenv."""
    path = os.getenv("ENV_FILE", ".env")
    if not os.path.exists(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key, value = key.strip(), value.strip().strip('"').strip("'")
                os.environ.setdefault(key, value)
    except OSError:
        pass


@dataclass
class Settings:
    app_env: str = "development"
    cors_origins: tuple[str, ...] = ("http://localhost:3000",)

    # --- who may call us. The Node API is the only expected caller.
    service_token: str = ""
    dev_auth_enabled: bool = True

    # --- model
    llm_provider: str = "echo"            # echo | groq | gemini
    groq_api_key: str = ""
    groq_model: str = ""
    gemini_api_key: str = ""
    gemini_model: str = ""
    # Small, cheap model for understanding and planning; big one for prose.
    fast_model: str = ""
    llm_timeout_seconds: float = 30.0
    llm_max_retries: int = 2

    # --- web research
    web_search_provider: str = ""         # tavily | brave | serper | fake | ""
    web_search_api_key: str = ""
    research_enabled: bool = True
    allowed_domains: tuple[str, ...] = ("ac.uk", "chevening.org", "britishcouncil.org", "gov.uk")
    # Of those, the ones that fund study rather than teach it. A course
    # search sent to these spends its whole budget on award pages and
    # advice articles - which is exactly what it did.
    funding_domains: tuple[str, ...] = ("chevening.org", "britishcouncil.org", "gov.uk")
    max_searches: int = 3
    max_fetches: int = 6
    max_research_seconds: float = 60.0
    fetch_timeout_seconds: float = 10.0
    max_page_bytes: int = 2_000_000
    user_agent: str = "nextED-counsellor/0.1 (+https://nexted.com.bd; study-abroad research)"

    # --- daily cap
    daily_ai_limit: int = 30
    # Off for now: students may search without a daily limit. Set
    # AI_LIMIT_ENABLED=true to bring back NEXTED_AI_DAILY_LIMIT.
    ai_limit_enabled: bool = False

    # --- storage
    data_dir: str = "data"
    seed_dir: str = "examples/seed"
    restrictions_file: str = "examples/restrictions.sample.json"

    # --- knowledge base (PostgreSQL + pgvector). Empty = JSON files only.
    database_url: str = ""
    # Schema the knowledge-base tables live in. Lets the service share the
    # IELTS app's database without touching Prisma's `public` tables.
    kb_schema: str = "nexted_ai"
    embeddings_provider: str = "fastembed"  # fastembed | gemini | none
    embedding_model: str = ""
    embedding_dim: int = 0
    # How close (cosine similarity, 0-1) a row must be to count as a match.
    rag_min_similarity: float = 0.6
    # How close in meaning a course must be to the subject they want when no
    # word matches (bge-small: same field ~0.8+, different fields ~0.6-0.75).
    subject_min_similarity: float = 0.8
    knowledge_dir: str = "knowledge"

    # --- tracing
    langsmith_tracing: bool = False
    langsmith_api_key: str = ""
    langsmith_project: str = "nexted-ai"
    langsmith_endpoint: str = "https://api.smith.langchain.com"

    # --- office
    office_name: str = "nextED"
    office_address: str = "Plot 40, 4th Floor, Road 7B, Block H, Banani, Dhaka, Bangladesh"
    office_phone_display: str = "01626794269"
    office_phone_e164: str = "+8801626794269"
    office_maps_url: str = (
        "https://www.google.com/maps/place/NextED+Advisors/@23.7898425,90.4059136,17z/"
        "data=!3m1!4b1!4m6!3m5!1s0x3755c7fa96085ad5:0x80eacd9ada03657e!8m2!3d23.7898425"
        "!4d90.4084885!16s%2Fg%2F11ypcnw83n"
    )

    disclaimer: str = (
        "The AI counsellor can make mistakes. Please check important details "
        "such as deadlines and entry requirements on the university's own "
        "page, and speak to a nextED counsellor before you act on anything."
    )

    @property
    def is_production(self) -> bool:
        return self.app_env.lower() in {"production", "prod"}


@lru_cache
def get_settings() -> Settings:
    _load_dotenv()
    origins = tuple(
        o.strip() for o in os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",") if o.strip()
    )
    domains = tuple(
        d.strip().lower()
        for d in os.getenv("ALLOWED_DOMAINS", "ac.uk,chevening.org,britishcouncil.org,gov.uk").split(",")
        if d.strip()
    )
    return Settings(
        app_env=os.getenv("APP_ENV", "development"),
        cors_origins=origins,
        service_token=os.getenv("SERVICE_TOKEN", ""),
        dev_auth_enabled=_bool("DEV_AUTH_ENABLED", True),
        llm_provider=os.getenv("LLM_PROVIDER", "echo").strip().lower(),
        groq_api_key=os.getenv("GROQ_API_KEY", ""),
        groq_model=os.getenv("GROQ_MODEL", ""),
        gemini_api_key=os.getenv("GEMINI_API_KEY", ""),
        gemini_model=os.getenv("GEMINI_WRITING_MODEL", os.getenv("GEMINI_MODEL", "")),
        fast_model=os.getenv("FAST_MODEL", ""),
        llm_timeout_seconds=_float("LLM_TIMEOUT_SECONDS", 30.0),
        llm_max_retries=_int("LLM_MAX_RETRIES", 2),
        web_search_provider=os.getenv("WEB_SEARCH_PROVIDER", "").strip().lower(),
        web_search_api_key=os.getenv("WEB_SEARCH_API_KEY", ""),
        research_enabled=_bool("RESEARCH_ENABLED", True),
        allowed_domains=domains,
        funding_domains=tuple(
            d.strip().lower()
            for d in os.getenv(
                "FUNDING_DOMAINS", "chevening.org,britishcouncil.org,gov.uk"
            ).split(",")
            if d.strip()
        ),
        max_searches=_int("MAX_SEARCHES", 3),
        max_fetches=_int("MAX_FETCHES", 6),
        max_research_seconds=_float("MAX_RESEARCH_SECONDS", 60.0),
        fetch_timeout_seconds=_float("FETCH_TIMEOUT_SECONDS", 10.0),
        max_page_bytes=_int("MAX_PAGE_BYTES", 2_000_000),
        daily_ai_limit=_int("NEXTED_AI_DAILY_LIMIT", 30),
        ai_limit_enabled=_bool("AI_LIMIT_ENABLED", False),
        data_dir=os.getenv("DATA_DIR", "data"),
        seed_dir=os.getenv("SEED_DIR", "examples/seed"),
        restrictions_file=os.getenv("RESTRICTIONS_FILE", "examples/restrictions.sample.json"),
        database_url=_pg_url(os.getenv("DATABASE_URL", "")),
        kb_schema=_schema_name(os.getenv("KB_SCHEMA", "nexted_ai")),
        embeddings_provider=os.getenv("EMBEDDINGS_PROVIDER", "fastembed").strip().lower(),
        embedding_model=os.getenv("EMBEDDING_MODEL", "").strip(),
        embedding_dim=_int("EMBEDDING_DIM", 0),
        rag_min_similarity=_float("RAG_MIN_SIMILARITY", 0.6),
        subject_min_similarity=_float("SUBJECT_MIN_SIMILARITY", 0.8),
        knowledge_dir=os.getenv("KNOWLEDGE_DIR", "knowledge"),
        langsmith_tracing=_bool("LANGSMITH_TRACING", False),
        langsmith_api_key=os.getenv("LANGSMITH_API_KEY", ""),
        langsmith_project=os.getenv("LANGSMITH_PROJECT", "nexted-ai"),
        langsmith_endpoint=os.getenv("LANGSMITH_ENDPOINT", "https://api.smith.langchain.com"),
    )