"""Running a graph, with or without LangGraph installed.

A node here is an ordinary async function: it takes the state and returns a
dict of updates. Nothing in a node knows which runner is driving it.

When LangGraph is installed it builds a real StateGraph and runs that, which
is what gives you LangSmith traces and the ability to add branching later.
When it is not, the same nodes run through the small sequential runner
below.

That is not a workaround. It means `pytest` needs no LangChain stack, the
service starts on a machine where the install failed, and the day LangGraph
makes a breaking change the decision layer carries on working.

A note on the state schema, because getting it wrong is silent and nasty:
LangGraph builds one channel per ANNOTATED key on the state type. Passing a
bare `dict` annotates nothing, so there are no channels to merge into and
each node's return value replaces the whole state - the next node then sees
none of the things that were put there before it. `GraphState` below exists
to declare every key, so partial updates merge instead of replacing.
"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any, AsyncIterator, Awaitable, Callable, Sequence, TypedDict

from app.errors import AppError

log = logging.getLogger(__name__)

Node = Callable[[dict], Awaitable[dict]]
Router = Callable[[dict], str]


class GraphState(TypedDict, total=False):
    """Every key any of the three graphs puts in the state.

    `total=False` means a node may return any subset. Each key must be
    listed here or LangGraph will drop it between nodes.
    """

    # --- handed in by the service
    student_id: str
    profile: Any
    store: Any
    llm: Any
    web_search: Any
    fetcher: Any
    budget: Any
    research_enabled: bool
    query: str
    kind: str
    message: str
    history: list

    # --- shared steps
    scope: Any
    words: list
    trace_notes: list
    usage: dict
    constraints: dict

    # --- searching and research
    candidates: list
    search_note: str
    search_tier: str
    store_exhausted: bool
    planned_queries: list
    researched: list
    sources: list
    changes: list
    budget_note: str
    budget_summary: dict

    # --- the decisions
    restricted_pairs: list
    eligibility_pairs: list
    needs_home_district: bool

    # --- the model's contributions
    ranking: dict
    phrased: dict

    # --- counsellor
    intent: Any
    facts_block: str
    reply: str
    restricted: list
    show_contact: bool
    used_model: bool

    # --- output
    results: list
    gap: Any
    trace_steps: list

    # --- knowledge base (PostgreSQL + pgvector) and streaming
    kb: Any
    embedder: Any
    settings: Any
    profile_vec: Any
    rag_block: str
    streaming: bool
    emit: Any

    # --- counsellor agent (tool loop) and memory
    agent_messages: list
    pending_calls: list
    tool_rounds: int
    used_tools: bool
    agent_failed: bool
    profile_updates: dict
    memory_block: str
    actions: list


def langgraph_available() -> bool:
    try:
        import langgraph.graph  # noqa: F401
    except Exception:  # noqa: BLE001
        return False
    return True


@dataclass
class Step:
    name: str
    fn: Node
    # Optional branch: given the state after this node, which node runs next.
    # Returning "" (or omitting the router) means "the next step in order".
    # Returning "END" finishes the graph.
    router: Router | None = None


@dataclass
class Graph:
    """An ordered list of steps, with optional jumps."""

    name: str
    steps: list[Step] = field(default_factory=list)

    def add(self, name: str, fn: Node, router: Router | None = None) -> "Graph":
        self.steps.append(Step(name=name, fn=fn, router=router))
        return self

    # ------------------------------------------------------------------
    @property
    def names(self) -> list[str]:
        return [s.name for s in self.steps]

    def check(self) -> list[str]:
        """Problems that would only show up at run time otherwise."""
        problems: list[str] = []
        names = self.names
        if not names:
            problems.append(f"{self.name}: no steps")
        if len(names) != len(set(names)):
            problems.append(f"{self.name}: duplicate node names")
        return problems

    async def _run_sequential(self, state: dict) -> dict:
        index = {step.name: i for i, step in enumerate(self.steps)}
        position = 0
        visited = 0
        limit = len(self.steps) * 4  # a cheap guard against a bad router

        while 0 <= position < len(self.steps) and visited < limit:
            step = self.steps[position]
            visited += 1
            try:
                updates = await step.fn(state)
            except AppError:
                # The service's own answers - the daily cap is reached, the
                # provider is busy. These travel up to the caller, which
                # turns them into something a student can read. A stack
                # trace here says a node broke, which is not what happened.
                raise
            except Exception:
                log.exception("node %s.%s failed", self.name, step.name)
                raise
            if updates:
                state.update(updates)
            state.setdefault("trace_steps", []).append(step.name)

            target = step.router(state) if step.router else ""
            if target == "END":
                break
            if target:
                position = index.get(target, position + 1)
            else:
                position += 1
        return state

    async def _run_langgraph(self, state: dict) -> dict:
        compiled = self._compile()
        result = await compiled.ainvoke(state)
        # Belt and braces: anything the graph did not carry through is still
        # whatever we handed in.
        return {**state, **dict(result)}

    def _compile(self):
        from langgraph.graph import END, START, StateGraph

        builder = StateGraph(GraphState)
        names = self.names

        for step in self.steps:
            builder.add_node(step.name, step.fn)

        builder.add_edge(START, names[0])

        for i, step in enumerate(self.steps):
            following = names[i + 1] if i + 1 < len(names) else None

            if step.router is None:
                builder.add_edge(step.name, following or END)
                continue

            builder.add_conditional_edges(
                step.name,
                _make_router(step.router, set(names), following),
                {**{n: n for n in names}, "__end__": END},
            )

        return builder.compile()

    async def stream(self, state: dict) -> AsyncIterator[tuple[str, Any]]:
        """Run the graph and yield ("token", text) as the reply is written,
        then ("done", final_state).

        With LangGraph installed this is LangGraph's own streaming:
        `astream(stream_mode=["custom", "values"])`, and the writing node
        sends each piece through `get_stream_writer()`. Without it, the same
        nodes run sequentially and send pieces through a queue.
        """
        state.setdefault("trace_steps", [])
        state["streaming"] = True
        if langgraph_available():
            sent = False
            try:
                compiled = self._compile()
                final: dict = dict(state)
                async for mode, chunk in compiled.astream(state, stream_mode=["custom", "values"]):
                    if mode == "custom":
                        text = chunk.get("token") if isinstance(chunk, dict) else None
                        if text:
                            sent = True
                            yield ("token", text)
                    elif mode == "values" and isinstance(chunk, dict):
                        final.update(chunk)
                yield ("done", {**state, **final})
                return
            except AppError:
                raise
            except Exception:  # noqa: BLE001
                if sent:
                    raise
                log.exception("langgraph stream failed; falling back to sequential")

        queue: asyncio.Queue = asyncio.Queue()

        async def emit(text: str) -> None:
            await queue.put(text)

        state["emit"] = emit
        task = asyncio.create_task(self._run_sequential(state))
        getter: asyncio.Task | None = None
        try:
            while True:
                getter = asyncio.create_task(queue.get())
                done, _ = await asyncio.wait({getter, task}, return_when=asyncio.FIRST_COMPLETED)
                if getter in done:
                    yield ("token", getter.result())
                    continue
                getter.cancel()
                while not queue.empty():
                    yield ("token", queue.get_nowait())
                result = task.result()  # re-raises the graph's error, if any
                result.pop("emit", None)
                yield ("done", result)
                return
        finally:
            if getter is not None and not getter.done():
                getter.cancel()
            if not task.done():
                task.cancel()

    async def run(self, state: dict, prefer_langgraph: bool = True) -> dict:
        state.setdefault("trace_steps", [])
        if prefer_langgraph and langgraph_available():
            try:
                return await self._run_langgraph(state)
            except AppError:
                # Not a graph problem - an answer. Falling back here would
                # run every node a second time, spending the student's
                # daily allowance twice to reach the same refusal.
                raise
            except Exception:  # noqa: BLE001
                # A graph problem must not take the feature down.
                log.exception("langgraph run failed; falling back to sequential")
        return await self._run_sequential(state)


def _make_router(router: Router, names: set[str], following: str | None):
    """Turn a node's router into something LangGraph can dispatch on."""

    def choose(state: dict) -> str:
        target = router(state) or ""
        if target == "END":
            return "__end__"
        if target in names:
            return target
        return following if following else "__end__"

    return choose


def token_writer(state: dict):
    """The function a node calls to send one piece of a streamed reply.

    None when the graph is not streaming. Under LangGraph it is LangGraph's
    own stream writer; under the sequential runner, the queue's.
    """
    if not state.get("streaming"):
        return None
    emit = state.get("emit")
    if emit is not None:
        return emit
    try:
        from langgraph.config import get_stream_writer

        writer = get_stream_writer()
    except Exception:  # noqa: BLE001
        return None

    async def write(text: str) -> None:
        writer({"token": text})

    return write


def steps_of(graph: Graph) -> Sequence[str]:
    return graph.names