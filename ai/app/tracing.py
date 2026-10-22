"""LangSmith, switched off by default.

Two rules that are not negotiable:

  * student profiles are redacted before anything is sent
  * verbose tracing is never the production default - a trace of every run
    is a second copy of your students' data living outside your database

When tracing is off, or the SDK is not installed, every function here is a
no-op and nothing leaves the process.
"""
from __future__ import annotations

import logging
import os
from contextlib import contextmanager
from typing import Any

log = logging.getLogger(__name__)

_ENABLED = False

# Anything whose name looks like one of these is replaced before sending.
_SENSITIVE = (
    "name", "phone", "email", "student_id", "profile", "message",
    "history", "api_key", "token", "authorization",
)


def configure(settings) -> bool:
    """Turn tracing on if it is both wanted and possible."""
    global _ENABLED
    if not settings.langsmith_tracing:
        _ENABLED = False
        return False
    if not settings.langsmith_api_key:
        log.warning("LANGSMITH_TRACING is on but no API key is set - tracing stays off.")
        _ENABLED = False
        return False

    os.environ["LANGCHAIN_TRACING_V2"] = "true"
    os.environ["LANGCHAIN_API_KEY"] = settings.langsmith_api_key
    os.environ["LANGCHAIN_PROJECT"] = settings.langsmith_project
    os.environ["LANGCHAIN_ENDPOINT"] = settings.langsmith_endpoint

    try:
        import langsmith  # noqa: F401
    except ImportError:
        log.warning("langsmith is not installed - tracing stays off.")
        _ENABLED = False
        return False

    _ENABLED = True
    log.info("LangSmith tracing ON, project=%s", settings.langsmith_project)
    return True


def enabled() -> bool:
    return _ENABLED


def redact(payload: Any) -> Any:
    """Strip anything that identifies a student, however deeply nested."""
    if isinstance(payload, dict):
        out = {}
        for key, value in payload.items():
            if any(s in str(key).lower() for s in _SENSITIVE):
                out[key] = "[redacted]"
            else:
                out[key] = redact(value)
        return out
    if isinstance(payload, (list, tuple)):
        return [redact(v) for v in payload]
    return payload


@contextmanager
def span(name: str, **metadata):
    """Mark a unit of work. A no-op unless tracing is on."""
    if not _ENABLED:
        yield None
        return
    try:
        from langsmith import trace

        cm = trace(name=name, metadata=redact(metadata))
        handle = cm.__enter__()
    except Exception:  # noqa: BLE001 - tracing must never break a request
        log.debug("tracing span %s failed", name, exc_info=True)
        yield None
        return
    # The request's own errors (AiLimitReached, ...) must pass through
    # untouched; catching them here and yielding again is a RuntimeError.
    try:
        yield handle
    except BaseException as exc:
        cm.__exit__(type(exc), exc, exc.__traceback__)
        raise
    else:
        cm.__exit__(None, None, None)
