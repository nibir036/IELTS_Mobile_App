"""The fetch gate: the only way anything in this service reaches the web.

A URL that arrives here was chosen by a language model from search results,
which means it is attacker-influenced input in the ordinary case, not the
unusual one. So every request passes the same checks:

  * the host must be on the allowlist
  * the host must not resolve to a private or loopback address (SSRF)
  * robots.txt must not forbid it
  * redirects are followed by us, re-checking every hop
  * timeouts and a size cap are always set
  * we identify ourselves honestly in the User-Agent

`FakePageFetcher` serves saved files instead, which is how the extractor
and the evidence rules are tested without a network.
"""
from __future__ import annotations

import asyncio
import ipaddress
import logging
import pathlib
import re
import socket
from dataclasses import dataclass, field
from urllib.parse import urljoin, urlparse

log = logging.getLogger(__name__)

MAX_REDIRECTS = 4

# Failures that mean "ask again", not "the answer is no". A page that
# answered with a 404 or a 403 has answered; a connection that never
# completed has not, and a university page that times out once usually
# responds the second time. Retrying the first kind would be rude and
# pointless; not retrying the second loses real results.
_TRANSIENT_ERRORS = frozenset({
    "ConnectTimeout", "ReadTimeout", "WriteTimeout", "PoolTimeout",
    "ConnectError", "ReadError", "WriteError", "RemoteProtocolError",
})


def is_transient(error_name: str) -> bool:
    """Is this failure worth one more attempt?"""
    return error_name in _TRANSIENT_ERRORS


@dataclass
class Page:
    url: str
    status: int = 0
    html: str = ""
    text: str = ""
    error: str = ""
    content_hash: str = ""

    @property
    def ok(self) -> bool:
        return self.status == 200 and bool(self.text)


@dataclass
class FetchPolicy:
    allowed_domains: tuple[str, ...] = ()
    # A subset of the above: hosts that fund study rather than teach it.
    # The gate treats them identically; only search targeting differs.
    funding_domains: tuple[str, ...] = ()
    timeout_seconds: float = 10.0
    max_bytes: int = 2_000_000
    user_agent: str = "nextED-counsellor/0.1"
    obey_robots: bool = True


def host_allowed(url: str, allowed: tuple[str, ...]) -> bool:
    """Suffix match on the registered domain, not a substring match.

    'evil-ac.uk.attacker.com' must not pass a check for 'ac.uk'.
    """
    try:
        host = (urlparse(url).hostname or "").lower().strip(".")
    except ValueError:
        return False
    if not host or not allowed:
        return False
    for domain in allowed:
        domain = domain.lower().strip(".")
        if host == domain or host.endswith("." + domain):
            return True
    return False


def is_public_address(host: str) -> bool:
    """Resolve the host and refuse anything that is not publicly routable."""
    if not host:
        return False
    try:
        infos = socket.getaddrinfo(host, None)
    except (socket.gaierror, UnicodeError):
        return False
    for info in infos:
        address = info[4][0]
        try:
            ip = ipaddress.ip_address(address)
        except ValueError:
            return False
        if (
            ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_reserved
            or ip.is_multicast
            or ip.is_unspecified
        ):
            return False
    return True


def url_is_safe(url: str, policy: FetchPolicy) -> tuple[bool, str]:
    parsed = urlparse(url)
    if parsed.scheme != "https":
        return False, "only https is allowed"
    if not host_allowed(url, policy.allowed_domains):
        return False, "host is not on the allowlist"
    if not is_public_address(parsed.hostname or ""):
        return False, "host does not resolve to a public address"
    return True, ""


# --------------------------------------------------------------- HTML -> text
_SCRIPT = re.compile(r"<(script|style|noscript)[^>]*>.*?</\1>", re.S | re.I)
_TAG = re.compile(r"<[^>]+>")
_WS = re.compile(r"[ \t\r\f\v]+")
_BLANK = re.compile(r"\n{3,}")

_ENTITIES = {
    "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"',
    "&#39;": "'", "&apos;": "'", "&pound;": "£", "&euro;": "€",
    "&ndash;": "-", "&mdash;": "-", "&rsquo;": "'", "&lsquo;": "'",
}


def html_to_text(html: str) -> str:
    """Enough of a reader to find sentences in. Not a browser."""
    if not html:
        return ""
    text = _SCRIPT.sub(" ", html)
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"</(p|div|li|tr|h[1-6])>", "\n", text, flags=re.I)
    text = _TAG.sub(" ", text)
    for entity, char in _ENTITIES.items():
        text = text.replace(entity, char)
    text = re.sub(r"&#(\d+);", lambda m: chr(int(m.group(1))), text)
    text = _WS.sub(" ", text)
    text = "\n".join(line.strip() for line in text.split("\n"))
    return _BLANK.sub("\n\n", text).strip()


def sentences(text: str) -> list[str]:
    """Split into candidate evidence sentences."""
    parts: list[str] = []
    for line in text.split("\n"):
        line = line.strip()
        if not line:
            continue
        for chunk in re.split(r"(?<=[.!?])\s+(?=[A-Z0-9£$€])", line):
            chunk = chunk.strip()
            if len(chunk) >= 12:
                parts.append(chunk)
    return parts


def content_hash(text: str) -> str:
    import hashlib

    return hashlib.sha256(text.encode("utf-8", "ignore")).hexdigest()[:32]


# ------------------------------------------------------------------- fetchers
class PageFetcher:
    """Real HTTPS fetching, through every check above."""

    def __init__(self, policy: FetchPolicy) -> None:
        self.policy = policy
        self._robots: dict[str, object] = {}

    async def _robots_allows(self, url: str) -> bool:
        if not self.policy.obey_robots:
            return True
        parsed = urlparse(url)
        root = f"{parsed.scheme}://{parsed.netloc}"
        if root not in self._robots:
            self._robots[root] = await self._load_robots(root)
        parser = self._robots[root]
        if parser is None:
            return True  # no robots.txt, or unreadable: proceed politely
        try:
            return bool(parser.can_fetch(self.policy.user_agent, url))  # type: ignore[attr-defined]
        except Exception:  # noqa: BLE001
            return True

    async def _load_robots(self, root: str):
        from urllib.robotparser import RobotFileParser

        try:
            import httpx
        except ImportError:
            return None
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(
                    f"{root}/robots.txt",
                    headers={"User-Agent": self.policy.user_agent},
                )
            if response.status_code != 200:
                return None
            parser = RobotFileParser()
            parser.parse(response.text.splitlines())
            return parser
        except Exception:  # noqa: BLE001
            return None

    async def get(self, url: str) -> Page:
        try:
            import httpx
        except ImportError:
            return Page(url=url, error="http client not installed")

        current = url
        for _ in range(MAX_REDIRECTS + 1):
            safe, why = url_is_safe(current, self.policy)
            if not safe:
                log.info("fetch refused: %s (%s)", current, why)
                return Page(url=current, error=why)

            if not await self._robots_allows(current):
                return Page(url=current, error="robots.txt disallows this page")

            # One retry, for connect failures only. A university page that
            # times out on the first attempt usually answers on the second,
            # and giving up on it costs the whole result: the scholarship
            # page we most wanted was lost this way. A page that answered
            # and said no is not retried - that is an answer.
            response = None
            last_error = ""
            for attempt in (1, 2):
                try:
                    async with httpx.AsyncClient(
                        timeout=self.policy.timeout_seconds, follow_redirects=False
                    ) as client:
                        response = await client.get(
                            current,
                            headers={
                                "User-Agent": self.policy.user_agent,
                                "Accept": "text/html,application/xhtml+xml",
                            },
                        )
                    break
                except Exception as exc:  # noqa: BLE001
                    last_error = type(exc).__name__
                    if attempt == 2 or not is_transient(last_error):
                        break
                    log.info("%s on %s; trying once more", last_error, current)
                    await asyncio.sleep(0.5)

            if response is None:
                return Page(url=current, error=f"fetch failed: {last_error}")

            # Follow redirects ourselves so every hop is re-checked.
            if response.status_code in (301, 302, 303, 307, 308):
                location = response.headers.get("location", "")
                if not location:
                    return Page(url=current, status=response.status_code,
                                error="redirect without a location")
                current = urljoin(current, location)
                continue

            if response.status_code != 200:
                return Page(url=current, status=response.status_code,
                            error=f"http {response.status_code}")

            raw = response.content[: self.policy.max_bytes]
            html = raw.decode(response.encoding or "utf-8", "ignore")
            text = html_to_text(html)
            return Page(
                url=current,
                status=200,
                html=html,
                text=text,
                content_hash=content_hash(text),
            )

        return Page(url=current, error="too many redirects")


@dataclass
class FakePageFetcher:
    """Serves saved pages from disk. How the research path is tested."""

    directory: pathlib.Path
    mapping: dict[str, str] = field(default_factory=dict)
    calls: list[str] = field(default_factory=list)

    async def get(self, url: str) -> Page:
        self.calls.append(url)
        name = self.mapping.get(url)
        if name is None:
            slug = re.sub(r"[^a-z0-9]+", "-", url.lower()).strip("-")
            name = f"{slug}.html"
        path = self.directory / name
        if not path.exists():
            return Page(url=url, status=404, error="no saved page for this url")
        html = path.read_text(encoding="utf-8")
        text = html_to_text(html)
        return Page(url=url, status=200, html=html, text=text,
                    content_hash=content_hash(text))