"""A provider that needs no key and no network.

Not a toy. It is what lets the whole service and the whole test suite run
on a laptop with nothing configured, and it is also how you tell whether
the real model is adding value or just adding words.

It answers each schema honestly rather than inventing content: rankings
keep the order they arrived in, phrasing passes the facts through
unchanged, and prose says plainly that no model is connected.
"""
from __future__ import annotations

from app.providers.base import LLMProvider


class EchoProvider(LLMProvider):
    name = "echo"

    async def complete_json(
        self,
        system: str,
        user: str,
        schema: dict | None = None,
        *,
        fast: bool = False,
        label: str = "",
    ) -> dict:
        wanted = set((schema or {}).get("properties", {}).keys())

        if "constraints" in wanted or label == "understand":
            # No interpretation: the caller's heuristic fallback handles it.
            return {"constraints": {}}

        if "matches" in wanted or label == "rank":
            ids = _ids_in(user)
            return {
                "matches": [
                    {"id": i, "confidence": 60, "why": "Matches what you asked for."}
                    for i in ids
                ]
            }

        if "items" in wanted or label == "phrase":
            # Hand the facts straight back; the caller falls back to raw facts.
            return {"items": []}

        if "queries" in wanted or label == "plan":
            return {"queries": []}

        if "fields" in wanted or label == "extract":
            return {"fields": []}

        return {
            "reply": (
                "I am running without a language model connected, so I cannot "
                "write a full answer yet. Set LLM_PROVIDER to groq or gemini "
                "with the matching API key to switch the counsellor on.\n\n"
                "Everything else in the service - matching, eligibility, "
                "restrictions and the daily limit - is working normally."
            )
        }


def _ids_in(text: str) -> list[str]:
    """Pull the candidate ids out of the prompt so ranking echoes them back."""
    import re

    return re.findall(r'"id"\s*:\s*"([^"]+)"', text)[:12]
