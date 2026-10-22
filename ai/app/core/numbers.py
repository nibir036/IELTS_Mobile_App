"""Reading numbers out of whatever students and websites actually write.

A student types "7.0 (overall)". A university page says "£18,000 per year".
A transcript says "3.2 / 4.0". All of these have to become a number, and a
wrong answer here quietly poisons every comparison downstream.
"""
from __future__ import annotations

import re

_FIRST_NUMBER = re.compile(r"\d+(?:[.,]\d+)?")


def num(value: object) -> float | None:
    """First number in `value`, or None.

    Note this is deliberately stricter than the TypeScript `num()` it
    replaces. That one stripped every character except digits and dots, so
    "3.2 / 4.0" became "3.24.0" and failed to parse at all. Taking the first
    number instead gives 3.2, which is what the student meant.
    """
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)

    text = str(value).strip()
    if not text:
        return None

    # 18,000 is one number; 3,5 in some locales is 3.5. Treat a comma with
    # exactly three digits after it as a thousands separator, else a decimal.
    text = re.sub(r"(?<=\d),(?=\d{3}\b)", "", text)

    match = _FIRST_NUMBER.search(text)
    if not match:
        return None
    try:
        return float(match.group(0).replace(",", "."))
    except ValueError:
        return None


def normalise_text(value: str) -> str:
    """Lowercase, collapse whitespace, drop punctuation that varies."""
    text = value.lower().strip()
    text = text.replace("&", " and ")
    text = re.sub(r"[‘’“”]", "'", text)
    text = re.sub(r"[^a-z0-9'\s-]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()
