#!/usr/bin/env python3
"""Run the tests without pytest.

`pytest -q` is the normal way. This exists so the suite also runs on a
machine where pytest is not installed, which keeps "can I trust this?"
one command away from anybody.
"""
from __future__ import annotations

import importlib
import pathlib
import sys
import traceback

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def main() -> int:
    modules = ["tests.test_core", "tests.test_service"]
    passed: list[str] = []
    failed: list[tuple[str, str]] = []
    names: list[str] = []

    for mod_name in modules:
        module = importlib.import_module(mod_name)
        for name in sorted(n for n in dir(module) if n.startswith("test_")):
            names.append(name)
            try:
                getattr(module, name)()
                passed.append(name)
            except Exception:
                failed.append((name, traceback.format_exc(limit=5)))

    for name in passed:
        print(f"  ok    {name}")
    for name, tb in failed:
        print(f"  FAIL  {name}")
        print(tb)

    print()
    print(f"{len(passed)} passed, {len(failed)} failed, {len(names)} total")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
