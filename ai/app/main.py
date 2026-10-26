"""The FastAPI service.

    uvicorn app.main:app --reload
    http://127.0.0.1:8000/docs

Only the Node API is expected to call this. It is not exposed to the
internet and it never sees a student's login - Node vouches for the student
and sends their profile across.
"""
from __future__ import annotations
import hmac

import json
import logging
from contextlib import asynccontextmanager

from app.api.schemas import CounsellorRequest, FinderRequest
from app.api.service import Counsellor
from app.config import get_settings
from app.errors import AppError, MissingField, NotAuthenticated
from app.wiring import build_counsellor

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("nexted")


def create_app():
    from fastapi import Depends, FastAPI, Header, Request
    from fastapi.exceptions import RequestValidationError
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import JSONResponse, StreamingResponse

    settings = get_settings()

    @asynccontextmanager
    async def lifespan(app):
        """Open the knowledge base and bring it up to date."""
        service: Counsellor = app.state.counsellor
        kb = service.kb
        if kb is not None:
            if await kb.open():
                try:
                    from app.kb.ingest import hydrate, ingest_knowledge, sync_store

                    await hydrate(kb, service.store)
                    await sync_store(kb, service.store, service.embedder)
                    await ingest_knowledge(kb, service.embedder, settings.knowledge_dir)
                    log.info(
                        "knowledge base ready: %s courses, %s scholarships",
                        await kb.count("course"), await kb.count("scholarship"),
                    )
                except Exception:  # noqa: BLE001
                    log.exception("knowledge base sync failed - continuing with what is loaded")
            else:
                log.warning("knowledge base unavailable (%s) - running on JSON files only", kb.error)
        yield
        if kb is not None:
            await kb.close()

    # No public API docs in production: this service only talks to the Node API.
    docs = {} if not settings.is_production else {"docs_url": None, "redoc_url": None, "openapi_url": None}
    app = FastAPI(
        **docs,
        lifespan=lifespan,
        title="nextED AI - counsellor, courses, scholarships",
        version="1.0.0",
        description=(
            "Three AI features behind one service. The AI explains the "
            "decision; it never makes it."
        ),
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_origins),
        allow_credentials=True,
        allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

    app.state.counsellor = build_counsellor(settings)

    async def require_service(authorization: str | None = Header(default=None)) -> None:
        """Only the Node API may call this service.

        A shared secret is enough because this never faces the internet. In
        development it may be left unset.
        """
        if not settings.service_token:
            if settings.is_production:
                raise NotAuthenticated("This service is not configured for production.")
            return
        if not authorization or not authorization.lower().startswith("bearer "):
            raise NotAuthenticated()
        given = authorization.split(" ", 1)[1].strip()
        # Constant-time compare, so the token can't be guessed byte by byte.
        if not hmac.compare_digest(given.encode(), settings.service_token.encode()):
            raise NotAuthenticated()

    # ------------------------------------------------------------ routes
    @app.get("/")
    async def index() -> dict:
        """A signpost, so opening the base URL in a browser is not a 404.

        It also doubles as a quick way to see what is switched on without
        remembering the health path.
        """
        service: Counsellor = app.state.counsellor
        searching = settings.research_enabled and service.web_search.name != "none"
        warnings = []
        if service.llm.name in {"echo", "demo"}:
            warnings.append(
                f"LLM_PROVIDER is '{service.llm.name}' - replies are stubs. "
                "Set it to groq or gemini with a key and a model."
            )
        if not searching:
            warnings.append(
                "No web search configured - the finders can only answer from "
                "what is already stored."
            )
        if not service.store.rules:
            warnings.append(
                "No restriction rules loaded - restriction checking is off."
            )
        return {
            "service": "nextED AI",
            "docs": "/docs",
            "endpoints": [
                "GET  /health",
                "GET  /v1/ai/usage?studentId=...",
                "POST /v1/ai/counsellor",
                "POST /v1/ai/counsellor/stream   (text/event-stream)",
                "GET  /v1/ai/counsellor/thread?studentId=...",
                "POST /v1/ai/courses",
                "POST /v1/ai/scholarships",
            ],
            "llm": service.llm.name,
            "research": searching,
            "warnings": warnings,
        }

    @app.get("/health")
    async def health() -> dict:
        service: Counsellor = app.state.counsellor
        kb = service.kb
        knowledge = {"status": "off"}
        if kb is not None:
            knowledge = {
                "status": "ok" if kb.ready else "error",
                "embeddings": getattr(service.embedder, "name", "none"),
                "dims": kb.dim,
            }
            if not kb.ready and kb.error:
                knowledge["error"] = str(kb.error)[:200]
        return {
            "knowledgeBase": knowledge,
            "status": "ok",
            "env": settings.app_env,
            "llm": service.llm.name,
            "research": service.settings.research_enabled
            and service.web_search.name != "none",
            "restrictionRules": len(service.store.rules),
            "courses": len(service.store.courses),
            "scholarships": len(service.store.scholarships),
        }

    @app.get("/v1/ai/usage")
    async def usage(studentId: str, _: None = Depends(require_service)) -> dict:
        service: Counsellor = app.state.counsellor
        return {"usage": service.store.read_usage(studentId).as_dict()}

    @app.post("/v1/ai/counsellor")
    async def counsellor(
        body: CounsellorRequest, _: None = Depends(require_service)
    ) -> dict:
        if not body.message.strip():
            raise MissingField("Please type a message.")
        service: Counsellor = app.state.counsellor
        return await service.counsellor(
            body.studentId,
            body.profile,
            body.message,
            [t.model_dump() for t in body.history],
        )

    @app.get("/v1/ai/counsellor/thread")
    async def counsellor_thread(studentId: str, _: None = Depends(require_service)) -> dict:
        """The student's one saved conversation, oldest first."""
        service: Counsellor = app.state.counsellor
        return await service.thread(studentId)

    @app.delete("/v1/ai/counsellor/thread")
    async def counsellor_thread_clear(studentId: str, _: None = Depends(require_service)) -> dict:
        """Start the conversation again (the profile is not touched)."""
        service: Counsellor = app.state.counsellor
        return await service.clear_thread(studentId)

    @app.post("/v1/ai/counsellor/stream")
    async def counsellor_stream(
        body: CounsellorRequest, _: None = Depends(require_service)
    ):
        """The counsellor, typed out as it is written (Server-Sent Events).

        event: token   data: {"t": "next piece of text"}
        event: done    data: { the same body as POST /v1/ai/counsellor }
        event: error   data: {"code": ..., "message": ...}
        """
        if not body.message.strip():
            raise MissingField("Please type a message.")
        service: Counsellor = app.state.counsellor

        def sse(event: str, data) -> str:
            return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False, default=str)}\n\n"

        async def events():
            try:
                async for kind, value in service.counsellor_stream(
                    body.studentId,
                    body.profile,
                    body.message,
                    [t.model_dump() for t in body.history],
                ):
                    if kind == "token":
                        yield sse("token", {"t": value})
                    else:
                        yield sse("done", value)
            except AppError as exc:
                yield sse("error", {**exc.body(), "status": exc.status_code})
            except Exception:  # noqa: BLE001
                log.exception("counsellor stream failed")
                yield sse("error", {
                    "code": "internal_error",
                    "message": "Something went wrong on our side. Please try again.",
                })

        return StreamingResponse(
            events(),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )

    @app.post("/v1/ai/courses")
    async def courses(body: FinderRequest, _: None = Depends(require_service)) -> dict:
        service: Counsellor = app.state.counsellor
        return await service.courses(body.studentId, body.profile, body.query)

    @app.post("/v1/ai/scholarships")
    async def scholarships(
        body: FinderRequest, _: None = Depends(require_service)
    ) -> dict:
        service: Counsellor = app.state.counsellor
        return await service.scholarships(body.studentId, body.profile, body.query)

    # ------------------------------------------------------------ errors
    @app.exception_handler(AppError)
    async def _app_error(request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content=exc.body())

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={"code": "invalid_request", "message": "That request could not be read."},
        )

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled error on %s", request.url.path)
        return JSONResponse(
            status_code=500,
            content={
                "code": "internal_error",
                "message": "Something went wrong on our side. Please try again.",
            },
        )

    return app


app = create_app()