"""The seam between the counsellor and whichever model writes the words.

Nothing above this line knows that Groq or Gemini exist. Swapping provider
is one environment variable, not three call sites.

Every model call in this service asks for JSON against a schema. Free prose
is only ever a field inside that JSON, never the whole reply - that is what
lets the code above check what came back.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any, Protocol, runtime_checkable


@dataclass(frozen=True)
class Message:
    role: str  # "system" | "user" | "assistant"
    content: str


@runtime_checkable
class LLMProvider(Protocol):
    name: str

    async def complete_json(
        self,
        system: str,
        user: str,
        schema: dict | None = None,
        *,
        fast: bool = False,
        label: str = "",
    ) -> dict:
        """Return a parsed JSON object, or raise an AppError subclass."""
        ...


_FENCE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.S)


def parse_json_loose(text: str) -> dict:
    """Models wrap JSON in fences and add trailing commentary. Cope with it."""
    if not text:
        return {}
    candidate = text.strip()

    fenced = _FENCE.search(candidate)
    if fenced:
        candidate = fenced.group(1).strip()

    try:
        parsed = json.loads(candidate)
        return parsed if isinstance(parsed, dict) else {"value": parsed}
    except json.JSONDecodeError:
        pass

    # Fall back to the outermost {...} in the string.
    start, end = candidate.find("{"), candidate.rfind("}")
    if start != -1 and end > start:
        try:
            parsed = json.loads(candidate[start: end + 1])
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}
    return {}


def clamp(value: Any, low: float, high: float, default: float = 0.0) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    if number != number:  # NaN
        return default
    return max(low, min(high, number))
