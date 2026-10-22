from __future__ import annotations

import logging

from app.config import Settings
from app.providers.base import LLMProvider
from app.providers.echo import EchoProvider

log = logging.getLogger(__name__)


def build_llm(settings: Settings) -> LLMProvider:
    choice = (settings.llm_provider or "echo").strip().lower()

    if choice == "groq":
        from app.providers.http_llm import GroqProvider

        return GroqProvider(
            api_key=settings.groq_api_key,
            model=settings.groq_model,
            fast_model=settings.fast_model,
            timeout=settings.llm_timeout_seconds,
            max_retries=settings.llm_max_retries,
        )

    if choice == "demo":
        from app.providers.demo import DemoLLM

        log.warning("LLM_PROVIDER=demo - scripted replies, for trying the API only.")
        return DemoLLM()

    if choice == "gemini":
        from app.providers.http_llm import GeminiProvider

        return GeminiProvider(
            api_key=settings.gemini_api_key,
            model=settings.gemini_model,
            fast_model=settings.fast_model,
            timeout=settings.llm_timeout_seconds,
            max_retries=settings.llm_max_retries,
        )

    if choice != "echo":
        log.warning("Unknown LLM_PROVIDER %r - falling back to 'echo'.", choice)
    if settings.is_production:
        log.warning("LLM_PROVIDER=echo in production: replies will be stubs.")
    return EchoProvider()
