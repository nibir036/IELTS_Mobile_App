"""Text -> vector.

Groq has no embeddings API, so the vectors come from a separate model:

  fastembed  (default) a small local model, BAAI/bge-small-en-v1.5, 384
             dimensions. Free, no key, runs on the CPU. The first start
             downloads it once (~130 MB) into the fastembed cache.
  gemini     Google's text-embedding-004 (768 dimensions), using
             GEMINI_API_KEY. Needs the internet.
  none       no vectors: search falls back to keywords only.

The model is loaded lazily and runs in a worker thread, so the event loop
never blocks on it.
"""
from __future__ import annotations

import asyncio
import logging
from typing import Protocol, Sequence

log = logging.getLogger(__name__)


class Embedder(Protocol):
    name: str
    dim: int

    async def embed_documents(self, texts: Sequence[str]) -> list[list[float]]: ...

    async def embed_query(self, text: str) -> list[float] | None: ...


class NoEmbedder:
    name = "none"
    dim = 0

    async def embed_documents(self, texts: Sequence[str]) -> list[list[float]]:
        return []

    async def embed_query(self, text: str) -> list[float] | None:
        return None


class FastEmbedder:
    """Local model via the `fastembed` package (ONNX, no PyTorch)."""

    name = "fastembed"

    def __init__(self, model: str = "BAAI/bge-small-en-v1.5", dim: int = 384) -> None:
        self.model_name = model
        self.dim = dim
        self._model = None
        self._lock = asyncio.Lock()

    def _load(self):
        if self._model is None:
            from fastembed import TextEmbedding  # imported here: optional dependency

            log.info("loading embedding model %s (first run downloads it)", self.model_name)
            self._model = TextEmbedding(model_name=self.model_name)
        return self._model

    async def _ensure(self):
        async with self._lock:
            return await asyncio.to_thread(self._load)

    async def embed_documents(self, texts: Sequence[str]) -> list[list[float]]:
        if not texts:
            return []
        model = await self._ensure()

        def run() -> list[list[float]]:
            return [list(map(float, v)) for v in model.passage_embed(list(texts))]

        return await asyncio.to_thread(run)

    async def embed_query(self, text: str) -> list[float] | None:
        if not text.strip():
            return None
        model = await self._ensure()

        def run() -> list[float]:
            return [float(x) for x in next(iter(model.query_embed(text)))]

        return await asyncio.to_thread(run)


class GeminiEmbedder:
    name = "gemini"
    URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:{method}"

    def __init__(self, api_key: str, model: str = "text-embedding-004", dim: int = 768) -> None:
        self._key = api_key
        self.model_name = model
        self.dim = dim

    async def _call(self, method: str, payload: dict) -> dict:
        import httpx

        url = self.URL.format(model=self.model_name, method=method)
        async with httpx.AsyncClient(timeout=30) as client:
            res = await client.post(url, headers={"x-goog-api-key": self._key}, json=payload)
            res.raise_for_status()
            return res.json()

    async def embed_documents(self, texts: Sequence[str]) -> list[list[float]]:
        out: list[list[float]] = []
        for start in range(0, len(texts), 100):  # the batch limit
            batch = texts[start:start + 100]
            data = await self._call("batchEmbedContents", {
                "requests": [
                    {
                        "model": f"models/{self.model_name}",
                        "content": {"parts": [{"text": t}]},
                        "taskType": "RETRIEVAL_DOCUMENT",
                    }
                    for t in batch
                ]
            })
            out.extend([e.get("values", []) for e in data.get("embeddings", [])])
        return out

    async def embed_query(self, text: str) -> list[float] | None:
        if not text.strip():
            return None
        data = await self._call("embedContent", {
            "model": f"models/{self.model_name}",
            "content": {"parts": [{"text": text}]},
            "taskType": "RETRIEVAL_QUERY",
        })
        return (data.get("embedding") or {}).get("values") or None


def build_embedder(settings) -> Embedder:
    choice = (settings.embeddings_provider or "fastembed").strip().lower()
    if choice == "none":
        return NoEmbedder()
    if choice == "gemini":
        if not settings.gemini_api_key:
            log.warning("EMBEDDINGS_PROVIDER=gemini but GEMINI_API_KEY is empty - vectors are off")
            return NoEmbedder()
        return GeminiEmbedder(settings.gemini_api_key, settings.embedding_model or "text-embedding-004",
                              settings.embedding_dim or 768)
    try:
        import fastembed  # noqa: F401
    except ImportError:
        log.warning("fastembed is not installed (pip install fastembed) - vectors are off, keyword search only")
        return NoEmbedder()
    return FastEmbedder(settings.embedding_model or "BAAI/bge-small-en-v1.5", settings.embedding_dim or 384)
