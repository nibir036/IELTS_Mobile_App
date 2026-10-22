"""What one request is allowed to spend going out to the web.

Reading university pages live is what makes the finders useful when we hold
nothing. It is also slow and costs money, so it runs on a leash.

Running out of budget is not an error. It produces an honest partial
answer: here is what we confirmed, here is what we could not, here are the
links. That is a better outcome than either a long wait or a confident
guess.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field


@dataclass
class ResearchBudget:
    max_searches: int = 3
    max_fetches: int = 6
    # A cold-start request reads several pages, and each one is a network
    # fetch plus an extraction call. Twenty seconds covered barely one,
    # so the rest of the results were dropped unread and the student was
    # told we had run out of time - which was true, and useless.
    max_seconds: float = 60.0

    searches_used: int = 0
    fetches_used: int = 0
    started_at: float = field(default_factory=time.monotonic)
    stopped_because: str = ""
    left_unread: int = 0

    # ------------------------------------------------------------------
    @property
    def elapsed(self) -> float:
        return time.monotonic() - self.started_at

    @property
    def seconds_left(self) -> float:
        return max(0.0, self.max_seconds - self.elapsed)

    def can_search(self) -> bool:
        if self.searches_used >= self.max_searches:
            self.stopped_because = "search limit reached"
            return False
        if self.seconds_left <= 0:
            self.stopped_because = "time limit reached"
            return False
        return True

    def can_fetch(self) -> bool:
        if self.fetches_used >= self.max_fetches:
            self.stopped_because = "page limit reached"
            return False
        if self.seconds_left <= 0:
            self.stopped_because = "time limit reached"
            return False
        return True

    def spend_search(self) -> None:
        self.searches_used += 1

    def spend_fetch(self) -> None:
        self.fetches_used += 1

    @property
    def spent(self) -> bool:
        return not (self.can_search() or self.can_fetch())

    def summary(self) -> dict:
        return {
            "searches": self.searches_used,
            "pages": self.fetches_used,
            "seconds": round(self.elapsed, 1),
            "stopped_because": self.stopped_because,
            "left_unread": self.left_unread,
        }

    def note_unread(self, count: int) -> None:
        """Results we found but never got to. The caller knows; we do not."""
        self.left_unread += max(0, count)

    def student_note(self) -> str:
        """What to tell the student when we had to stop early.

        Only when something was actually left unread. Spending the whole
        budget on work that finished is not running out - saying so turned
        every complete answer into an apology.
        """
        if not self.left_unread:
            return ""
        return (
            "I ran out of time checking every option, so some of these are "
            "unconfirmed - the links are there if you want to check them, and "
            "a counsellor can confirm the rest."
        )