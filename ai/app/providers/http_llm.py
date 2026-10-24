"""Groq and Gemini, behind the one interface.

Both speak HTTP and both can be asked for JSON, so they share one base with
a small amount per-vendor. httpx is imported lazily so the service and the
tests still run where it is not installed.

A note on 404s. A wrong or retired model name is the single most common
setup mistake with either provider, and a bare "http 404" tells you nothing
useful. So when that happens we go and ask the provider which models the
key can actually use, and put the list in the error. The answer is always
one command away, but it is better still to be told.
"""
from __future__ import annotations

import asyncio
import logging
import re

from app.errors import AiBusy, AiFailed, AiNotConfigured
from app.providers.base import LLMProvider, parse_json_loose

log = logging.getLogger(__name__)

# Worth trying again. Anything else fails fast rather than hammering an API
# with a request that will never succeed.
_RETRYABLE_STATUS = {408, 409, 425, 429, 500, 502, 503, 504}

# A rate limit answers its own question: the response says how long to
# wait. Guessing instead - one second, then two - gives up before a limit
# that asked for seven, and loses the page. Capped so a provider having a
# bad day cannot hold a student's request open indefinitely.
_MAX_RETRY_WAIT = 15.0


def _retry_after(response, fallback: float) -> float:
    """How long the provider asked us to wait, if it said."""
    raw = ""
    try:
        headers = response.headers
        raw = headers.get("retry-after") or headers.get("x-ratelimit-reset-requests") or ""
    except Exception:  # noqa: BLE001
        return fallback
    text = str(raw).strip().lower()
    if not text:
        return fallback
    # "7", "7.5", "7s", "1m30s" - seconds in the forms providers send
    match = re.fullmatch(r"(?:(\d+(?:\.\d+)?)m)?(\d+(?:\.\d+)?)s?", text)
    if not match:
        return fallback
    minutes = float(match.group(1) or 0)
    seconds = float(match.group(2) or 0)
    wait = minutes * 60 + seconds
    if wait <= 0:
        return fallback
    return min(wait, _MAX_RETRY_WAIT)


def _retry_after_tokens(response) -> float:
    """Groq's x-ratelimit-reset-tokens ("7.66s", "1m2s"), capped."""
    try:
        text = str(response.headers.get("x-ratelimit-reset-tokens") or "").strip().lower()
    except Exception:  # noqa: BLE001
        return 0.0
    match = re.fullmatch(r"(?:(\d+(?:\.\d+)?)m)?(\d+(?:\.\d+)?)(ms|s)?", text)
    if not match:
        return 0.0
    seconds = float(match.group(2) or 0) / (1000 if match.group(3) == "ms" else 1)
    return min(float(match.group(1) or 0) * 60 + seconds, _MAX_RETRY_WAIT)


def _error_detail(response) -> str:
    """The provider's own explanation for a rejected request.

    Deliberately narrow: only the `error.message` field, truncated. A 4xx is
    a configuration problem and you cannot fix it blind, but the raw body can
    echo the prompt back, so nothing else from it is logged.
    """
    try:
        body = response.json()
    except Exception:  # noqa: BLE001
        return ""
    if not isinstance(body, dict):
        return ""
    error = body.get("error")
    if isinstance(error, dict):
        text = error.get("message") or error.get("type") or error.get("code") or ""
    elif isinstance(error, str):
        text = error
    else:
        text = body.get("message") or ""
    return str(text)[:400]


def _ensure_json_word(system: str) -> str:
    """OpenAI-compatible endpoints refuse `response_format: json_object`
    unless the word "json" appears somewhere in the messages.

    Groq enforces this strictly. Without it every call fails once, falls
    back, and silently costs twice as much - so the word goes in up front.
    """
    if "json" in system.lower():
        return system
    return system + "\n\nReply with a single JSON object and nothing else."


def _httpx():
    try:
        import httpx
    except ImportError as exc:  # pragma: no cover
        raise AiNotConfigured("The HTTP client library is not installed.") from exc
    return httpx


class _HttpLLM(LLMProvider):
    name = "http"

    def __init__(self, timeout: float = 30.0, max_retries: int = 2) -> None:
        self._timeout = timeout
        self._max_retries = max_retries

    # -- provider specific ---------------------------------------------
    async def list_models(self) -> list[str]:
        """Which models this key can use. Empty if we could not ask."""
        return []

    def _model_help(self, model: str, available: list[str]) -> str:
        if available:
            shown = ", ".join(available[:12])
            more = f" (and {len(available) - 12} more)" if len(available) > 12 else ""
            return (
                f"{self.name}: the model {model!r} was not found. "
                f"Models your key can use: {shown}{more}. "
                f"Set the model name in your .env and restart."
            )
        return (
            f"{self.name}: the model {model!r} was not found, and the model "
            "list could not be read. Check the name in your .env."
        )

    async def _explain_404(self, model: str) -> AiNotConfigured:
        try:
            available = await self.list_models()
        except Exception:  # noqa: BLE001
            available = []
        message = self._model_help(model, available)
        log.error(message)
        return AiNotConfigured(message)

    # -- shared ---------------------------------------------------------
    async def _post(self, url: str, headers: dict, payload: dict, model: str = "") -> dict:
        httpx = _httpx()
        delay = 1.0
        last: Exception | None = None

        for attempt in range(self._max_retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self._timeout) as client:
                    response = await client.post(url, headers=headers, json=payload)

                status = response.status_code

                if status in (401, 403):
                    raise AiNotConfigured(
                        f"{self.name}: the API key was rejected. Check it in your .env."
                    )
                if status == 404:
                    # Almost always a wrong or retired model name.
                    raise await self._explain_404(model)
                if status in _RETRYABLE_STATUS:
                    if attempt == self._max_retries:
                        log.info(
                            "%s is rate limiting us (http %s); giving up on "
                            "this page after %s attempt(s)",
                            self.name, status, attempt + 1,
                        )
                        raise AiBusy()
                    wait = _retry_after(response, delay)
                    log.info(
                        "%s busy (http %s); waiting %.1fs",
                        self.name, status, wait,
                    )
                    await asyncio.sleep(wait)
                    delay *= 2
                    continue
                if status >= 400:
                    detail = _error_detail(response)
                    log.error(
                        "%s rejected the request (http %s)%s",
                        self.name,
                        status,
                        f": {detail}" if detail else " and gave no reason",
                    )
                    raise AiFailed()
                return response.json()
            except (AiBusy, AiFailed, AiNotConfigured):
                raise
            except Exception as exc:  # noqa: BLE001
                last = exc
                log.warning(
                    "llm call failed (%s/%s): %s",
                    attempt + 1,
                    self._max_retries + 1,
                    type(exc).__name__,
                )
                if attempt == self._max_retries:
                    break
                await asyncio.sleep(delay)
                delay *= 2

        raise AiFailed() from last

    async def _stream_sse(self, url: str, headers: dict, payload: dict, pick, model: str = ""):
        """POST and yield the text pieces of a server-sent-events reply.

        `pick(event_json)` returns the text in one event ("" for none). One
        retry if the connection fails before anything arrived; none after,
        because half an answer cannot be taken back.
        """
        import json as _json

        httpx = _httpx()
        busy_waits = 0
        attempt = 0
        while attempt < 2:
            started = False
            try:
                async with httpx.AsyncClient(timeout=httpx.Timeout(self._timeout, read=self._timeout * 2)) as client:
                    async with client.stream("POST", url, headers=headers, json=payload) as response:
                        status = response.status_code
                        if status in (401, 403):
                            raise AiNotConfigured(f"{self.name}: the API key was rejected. Check it in your .env.")
                        if status == 404:
                            raise await self._explain_404(model)
                        if status in _RETRYABLE_STATUS:
                            # Nothing has been written yet, so waiting and
                            # asking again is safe. A rate limit (429) says
                            # how long; the counsellor makes several calls
                            # per message, so a per-minute token limit is hit
                            # easily on a small plan.
                            await response.aread()
                            log.warning("%s is busy (http %s): %s", self.name, status, _error_detail(response))
                            if busy_waits >= 2:
                                raise AiBusy()
                            busy_waits += 1
                            wait = _retry_after(response, 3.0)
                            if "x-ratelimit-reset-tokens" in response.headers:
                                wait = max(wait, _retry_after_tokens(response))
                            await asyncio.sleep(wait)
                            continue
                        if status >= 400:
                            await response.aread()
                            log.error("%s rejected the stream (http %s): %s", self.name, status, _error_detail(response))
                            raise AiFailed()
                        async for line in response.aiter_lines():
                            line = line.strip()
                            if not line.startswith("data:"):
                                continue
                            data = line[5:].strip()
                            if not data or data == "[DONE]":
                                continue
                            try:
                                event = _json.loads(data)
                            except ValueError:
                                continue
                            text = pick(event)
                            if text:
                                started = True
                                yield text
                return
            except (AiBusy, AiFailed, AiNotConfigured):
                raise
            except Exception as exc:  # noqa: BLE001
                if started or attempt == 1:
                    log.warning("%s stream broke: %s", self.name, type(exc).__name__)
                    raise AiFailed() from exc
                attempt += 1
                await asyncio.sleep(1.0)
        raise AiBusy()

    async def _get_json(self, url: str, headers: dict) -> dict:
        httpx = _httpx()
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(url, headers=headers)
            if response.status_code >= 400:
                return {}
            return response.json()
        except Exception:  # noqa: BLE001
            return {}


class GroqProvider(_HttpLLM):
    name = "groq"
    URL = "https://api.groq.com/openai/v1/chat/completions"
    MODELS_URL = "https://api.groq.com/openai/v1/models"

    def __init__(self, api_key: str, model: str, fast_model: str = "", **kw) -> None:
        super().__init__(**kw)
        if not api_key:
            raise AiNotConfigured(
                "GROQ_API_KEY is not set. Get one at console.groq.com."
            )
        if not model:
            raise AiNotConfigured(
                "GROQ_MODEL is not set. Run `python try.py --models` to see "
                "which models your key can use."
            )
        self._key, self._model = api_key, model
        self._fast = fast_model or model

    async def list_models(self) -> list[str]:
        data = await self._get_json(
            self.MODELS_URL, {"Authorization": f"Bearer {self._key}"}
        )
        return sorted(
            str(m.get("id"))
            for m in (data.get("data") or [])
            if m.get("id")
        )

    async def complete_json(
        self, system: str, user: str, schema: dict | None = None,
        *, fast: bool = False, label: str = "",
    ) -> dict:
        model = self._fast if fast else self._model
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": _ensure_json_word(system)},
                {"role": "user", "content": user},
            ],
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
        }
        headers = {"Authorization": f"Bearer {self._key}"}
        try:
            data = await self._post(self.URL, headers, payload, model=model)
        except AiFailed:
            # Not every model on every account accepts response_format. Drop
            # it and ask in the prompt instead - parse_json_loose copes with
            # fences and with reasoning models that think out loud first.
            payload.pop("response_format", None)
            data = await self._post(self.URL, headers, payload, model=model)

        try:
            text = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise AiFailed() from exc
        parsed = parse_json_loose(text or "")
        if not parsed:
            raise AiFailed()
        return parsed

    async def stream_text(self, system: str, user: str, *, fast: bool = False, label: str = ""):
        """Plain-text reply, piece by piece, as Groq writes it."""
        model = self._fast if fast else self._model
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "temperature": 0.3,
            "stream": True,
        }

        def pick(event: dict) -> str:
            try:
                return event["choices"][0]["delta"].get("content") or ""
            except (KeyError, IndexError, TypeError, AttributeError):
                return ""

        async for text in self._stream_sse(
            self.URL, {"Authorization": f"Bearer {self._key}"}, payload, pick, model=model
        ):
            yield text

    async def chat_stream(self, messages: list[dict], tools: list[dict] | None = None,
                          *, fast: bool = False, label: str = ""):
        """A conversation turn with tools (OpenAI format), streamed.

        Yields {"type": "text", "text": ...} as the reply is written, and at
        the end {"type": "tool_calls", "calls": [{id, name, arguments}]}
        when the model asked for tools instead of (or before) answering.
        Works with any OpenAI-compatible model on Groq, gpt-oss included.
        """
        model = self._fast if fast else self._model
        payload: dict = {
            "model": model,
            "messages": messages,
            "temperature": 0.4,
            "stream": True,
        }
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"

        calls: dict[int, dict] = {}
        async for event in self._stream_sse(
            self.URL, {"Authorization": f"Bearer {self._key}"}, payload, lambda e: e, model=model
        ):
            try:
                delta = event["choices"][0].get("delta") or {}
            except (KeyError, IndexError, TypeError, AttributeError):
                continue
            text = delta.get("content")
            if text:
                yield {"type": "text", "text": text}
            for part in delta.get("tool_calls") or []:
                slot = calls.setdefault(int(part.get("index", 0)), {"id": "", "name": "", "arguments": ""})
                if part.get("id"):
                    slot["id"] = part["id"]
                fn = part.get("function") or {}
                if fn.get("name"):
                    slot["name"] = fn["name"]
                if fn.get("arguments"):
                    slot["arguments"] += fn["arguments"]
        if calls:
            ordered = [calls[i] for i in sorted(calls)]
            for i, call in enumerate(ordered):
                call["id"] = call["id"] or f"call_{i}"
            yield {"type": "tool_calls", "calls": ordered}


class GeminiProvider(_HttpLLM):
    name = "gemini"
    BASE = "https://generativelanguage.googleapis.com/v1beta/models"

    def __init__(self, api_key: str, model: str, fast_model: str = "", **kw) -> None:
        super().__init__(**kw)
        if not api_key:
            raise AiNotConfigured(
                "GEMINI_API_KEY is not set. Get one at aistudio.google.com/apikey."
            )
        if not model:
            raise AiNotConfigured(
                "GEMINI_WRITING_MODEL is not set. Run `python try.py --models` "
                "to see which models your key can use."
            )
        self._key, self._model = api_key, model
        self._fast = fast_model or model

    async def list_models(self) -> list[str]:
        data = await self._get_json(self.BASE, {"x-goog-api-key": self._key})
        names = []
        for item in data.get("models") or []:
            raw = str(item.get("name", ""))
            # the API returns "models/gemini-..."; the config wants the tail
            if raw.startswith("models/"):
                raw = raw[len("models/"):]
            methods = item.get("supportedGenerationMethods") or []
            if raw and (not methods or "generateContent" in methods):
                names.append(raw)
        return sorted(names)

    @staticmethod
    def _to_gemini_schema(schema: dict) -> dict:
        """Gemini's dialect: upper-case types, no additionalProperties/enum."""
        if not isinstance(schema, dict):
            return {}
        out: dict = {}
        for key, value in schema.items():
            if key in {"additionalProperties", "enum"}:
                continue
            if key == "type" and isinstance(value, str):
                out["type"] = value.upper()
            elif key == "properties" and isinstance(value, dict):
                out["properties"] = {
                    k: GeminiProvider._to_gemini_schema(v) for k, v in value.items()
                }
            elif key == "items" and isinstance(value, dict):
                out["items"] = GeminiProvider._to_gemini_schema(value)
            else:
                out[key] = value
        return out

    async def complete_json(
        self, system: str, user: str, schema: dict | None = None,
        *, fast: bool = False, label: str = "",
    ) -> dict:
        model = self._fast if fast else self._model
        url = f"{self.BASE}/{model}:generateContent"
        config: dict = {"responseMimeType": "application/json", "temperature": 0.2}
        if schema:
            config["responseSchema"] = self._to_gemini_schema(schema)

        payload = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
            "generationConfig": config,
        }
        headers = {"x-goog-api-key": self._key}

        try:
            data = await self._post(url, headers, payload, model=model)
        except AiFailed:
            if not schema:
                raise
            # Some models reject a schema outright. Retry once without it and
            # parse leniently - the caller validates what comes back anyway.
            payload["generationConfig"] = {
                "responseMimeType": "application/json",
                "temperature": 0.2,
            }
            data = await self._post(url, headers, payload, model=model)

        try:
            text = data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError) as exc:
            raise AiFailed() from exc
        parsed = parse_json_loose(text or "")
        if not parsed:
            raise AiFailed()
        return parsed

    async def stream_text(self, system: str, user: str, *, fast: bool = False, label: str = ""):
        """Plain-text reply, piece by piece (Gemini's SSE stream)."""
        model = self._fast if fast else self._model
        url = f"{self.BASE}/{model}:streamGenerateContent?alt=sse"
        payload = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": user}]}],
            "generationConfig": {"temperature": 0.3},
        }

        def pick(event: dict) -> str:
            try:
                parts = event["candidates"][0]["content"]["parts"]
                return "".join(p.get("text", "") for p in parts)
            except (KeyError, IndexError, TypeError):
                return ""

        async for text in self._stream_sse(url, {"x-goog-api-key": self._key}, payload, pick, model=model):
            yield text
