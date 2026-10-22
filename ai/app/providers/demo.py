"""A scripted model for demos and tests.

It needs no key and no network, and it answers each job the way a careful
model would - reading values straight out of the page it is given rather
than inventing them.

One deliberate exception: on a page that states no English requirement it
reports one anyway, with a vague sentence as its evidence. That is what a
careless model does, and it is there so you can watch `core/evidence.py`
throw the claim away.

Not for production. `LLM_PROVIDER=demo` is accepted so the API can be tried
end to end without a key, but it only knows the pages in examples/pages.
"""
from __future__ import annotations

import json
import re


class DemoLLM:
    name = "demo"

    def __init__(self, **overrides) -> None:
        self.calls: list[str] = []
        self.overrides = overrides

    async def complete_json(
        self, system: str, user: str, schema=None, *, fast: bool = False, label: str = ""
    ) -> dict:
        self.calls.append(label)
        if label in self.overrides:
            value = self.overrides[label]
            if isinstance(value, Exception):
                raise value
            return value

        if label == "understand":
            return {"constraints": {}}

        if label == "plan":
            if "scholarship" in user.lower():
                return {"queries": [{"query": "global futures scholarship", "site": ""}]}
            if "business" in user.lower():
                return {"queries": [{"query": "business management masters", "site": ""}]}
            return {"queries": [{"query": "msc artificial intelligence", "site": ""}]}

        if label == "extract":
            return self._extract(user)

        if label == "rank":
            ids = re.findall(r'"id":\s*"([^"]+)"', user)
            return {
                "matches": [
                    {
                        "id": row_id,
                        "confidence": max(40, 85 - n * 7),
                        "why": "Matches the subject and level you asked for.",
                    }
                    for n, row_id in enumerate(ids)
                ]
            }

        if label == "phrase":
            try:
                payload = json.loads(user)
            except json.JSONDecodeError:
                return {"items": []}
            return {
                "items": [
                    {"id": p["id"], "reasons": p.get("facts", [])[:2]} for p in payload
                ]
            }

        return {
            "reply": (
                "Running on the demo model, so this reply is a stub. Set "
                "LLM_PROVIDER to groq or gemini with a key to switch the real "
                "counsellor on - everything else you see is real."
            )
        }

    # ------------------------------------------------------------------
    @staticmethod
    def _extract(user: str) -> dict:
        if "Artificial Intelligence" in user:
            return {
                "found": True,
                "title": "MSc Artificial Intelligence",
                "university": "Example University",
                "level": "Masters",
                "subject": "Computer Science",
                "duration": "1 year",
                "intake": "September 2027",
                "fields": [
                    {
                        "name": "min_ielts",
                        "value": "6.5",
                        "evidence": "Applicants need an overall IELTS score of 6.5 with no component below 6.0.",
                    },
                    {
                        "name": "tuition",
                        "value": "24500",
                        "evidence": "Tuition for 2027 entry is £24,500 per year for international students.",
                    },
                    {
                        "name": "deadline",
                        "value": "2027-01-15",
                        "evidence": "The deadline for applications is 15 January 2027.",
                    },
                ],
            }

        if "Global Futures" in user:
            return {
                "found": True,
                "title": "Example Global Futures Scholarship",
                "provider": "Example Foundation",
                "level": "Masters",
                "nationalities": ["Bangladesh", "India", "Nepal"],
                "fields": [
                    {
                        "name": "min_ielts",
                        "value": "7.0",
                        "evidence": "Applicants must have an overall IELTS score of 7.0 or above.",
                    },
                    {
                        "name": "amount",
                        "value": "12000",
                        "evidence": "The award is worth 12000 towards tuition for one year of postgraduate study.",
                    },
                    {
                        "name": "deadline",
                        "value": "2027-02-28",
                        "evidence": "Applications close on 28 February 2027.",
                    },
                ],
            }

        if "Business Management" in user:
            # The careless case, on purpose. This page states no IELTS score;
            # the claim below is backed only by a vague sentence, so the
            # evidence check drops it and the course survives without it.
            return {
                "found": True,
                "title": "MA Business Management",
                "university": "Example Northern University",
                "level": "Masters",
                "subject": "Business",
                "fields": [
                    {
                        "name": "min_ielts",
                        "value": "6.5",
                        "evidence": "Applicants should demonstrate a good level of English.",
                    }
                ],
            }

        return {"found": False, "fields": []}
