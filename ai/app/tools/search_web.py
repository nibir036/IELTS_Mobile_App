"""Finding candidate pages.

A search result is a way to find a page. It is never evidence in itself:
a snippet saying a deadline is in March is not a deadline. Everything a
search returns is a URL to go and read through the fetch gate.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Protocol

log = logging.getLogger(__name__)


@dataclass
class SearchHit:
    url: str
    title: str = ""
    snippet: str = ""


class WebSearch(Protocol):
    name: str

    async def search(
        self, query: str, sites: tuple[str, ...] = (), limit: int = 5
    ) -> list[SearchHit]:
        """`sites` restricts results to those domains.

        Each provider expresses this differently - Tavily has a parameter
        for it and does not understand the `site:` operator at all, while
        the Google-shaped ones only understand the operator. Getting this
        wrong is expensive and silent: the search still succeeds, it just
        returns pages the fetch gate will refuse.
        """
        ...


@dataclass
class FakeWebSearch:
    """Canned results, for tests."""

    results: dict[str, list[SearchHit]] = field(default_factory=dict)
    calls: list[str] = field(default_factory=list)
    site_calls: list[tuple] = field(default_factory=list)
    name: str = "fake"

    async def search(
        self, query: str, sites: tuple[str, ...] = (), limit: int = 5
    ) -> list[SearchHit]:
        self.calls.append(query)
        self.site_calls.append(tuple(sites))
        for key, hits in self.results.items():
            if key.lower() in query.lower():
                return hits[:limit]
        return self.results.get("*", [])[:limit]


class NoWebSearch:
    """What you get when no provider is configured: nothing, honestly."""

    name = "none"

    async def search(
        self, query: str, sites: tuple[str, ...] = (), limit: int = 5
    ) -> list[SearchHit]:
        return []


class _HttpSearch:
    name = "http"

    def __init__(self, api_key: str, timeout: float = 10.0) -> None:
        self._key = api_key
        self._timeout = timeout

    async def _post(self, url: str, headers: dict, payload: dict) -> dict:
        try:
            import httpx
        except ImportError:
            return {}
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.post(url, headers=headers, json=payload)
            if response.status_code >= 400:
                log.warning("web search http %s", response.status_code)
                return {}
            return response.json()
        except Exception as exc:  # noqa: BLE001
            log.warning("web search failed: %s", type(exc).__name__)
            return {}

    async def _get(self, url: str, headers: dict, params: dict) -> dict:
        try:
            import httpx
        except ImportError:
            return {}
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(url, headers=headers, params=params)
            if response.status_code >= 400:
                log.warning("web search http %s", response.status_code)
                return {}
            return response.json()
        except Exception as exc:  # noqa: BLE001
            log.warning("web search failed: %s", type(exc).__name__)
            return {}


class TavilySearch(_HttpSearch):
    name = "tavily"
    URL = "https://api.tavily.com/search"

    async def search(
        self, query: str, sites: tuple[str, ...] = (), limit: int = 5
    ) -> list[SearchHit]:
        # Tavily does not understand `site:`. Put it in the query and it is
        # read as search text, which makes the query worse rather than
        # narrower - the failure we actually hit in the field.
        payload = {
            "api_key": self._key,
            "query": query,
            "max_results": limit,
            "search_depth": "basic",
        }
        if sites:
            payload["include_domains"] = list(sites)
        data = await self._post(self.URL, {}, payload)
        return [
            SearchHit(
                url=r.get("url", ""),
                title=r.get("title", ""),
                snippet=r.get("content", ""),
            )
            for r in (data.get("results") or [])
            if r.get("url")
        ]


def _with_site_operator(query: str, sites: tuple[str, ...]) -> str:
    """Google-shaped engines take `site:` in the query, one or several."""
    if not sites:
        return query
    if len(sites) == 1:
        return f"{query} site:{sites[0]}"
    joined = " OR ".join(f"site:{s}" for s in sites)
    return f"{query} ({joined})"


class BraveSearch(_HttpSearch):
    name = "brave"
    URL = "https://api.search.brave.com/res/v1/web/search"

    async def search(
        self, query: str, sites: tuple[str, ...] = (), limit: int = 5
    ) -> list[SearchHit]:
        params = {"q": _with_site_operator(query, sites), "count": limit}
        data = await self._get(
            self.URL,
            {"X-Subscription-Token": self._key, "Accept": "application/json"},
            params,
        )
        results = ((data.get("web") or {}).get("results")) or []
        return [
            SearchHit(
                url=r.get("url", ""),
                title=r.get("title", ""),
                snippet=r.get("description", ""),
            )
            for r in results
            if r.get("url")
        ]


class SerperSearch(_HttpSearch):
    name = "serper"
    URL = "https://google.serper.dev/search"

    async def search(
        self, query: str, sites: tuple[str, ...] = (), limit: int = 5
    ) -> list[SearchHit]:
        payload = {"q": _with_site_operator(query, sites), "num": limit}
        data = await self._post(self.URL, {"X-API-KEY": self._key}, payload)
        return [
            SearchHit(
                url=r.get("link", ""),
                title=r.get("title", ""),
                snippet=r.get("snippet", ""),
            )
            for r in (data.get("organic") or [])
            if r.get("link")
        ]


def build_web_search(provider: str, api_key: str, timeout: float = 10.0) -> WebSearch:
    choice = (provider or "").strip().lower()
    if not choice or not api_key:
        if choice and not api_key:
            log.warning("WEB_SEARCH_PROVIDER=%s but no key set - research disabled.", choice)
        return NoWebSearch()
    if choice == "tavily":
        return TavilySearch(api_key, timeout)
    if choice == "brave":
        return BraveSearch(api_key, timeout)
    if choice == "serper":
        return SerperSearch(api_key, timeout)
    log.warning("Unknown WEB_SEARCH_PROVIDER %r - research disabled.", choice)
    return NoWebSearch()