#!/usr/bin/env python3
"""Check your copy of the project against the version these files came from.

    python verify.py

Prints one line per file that differs, and nothing reassuring if all is
well. Run it first whenever you hit an AttributeError, a TypeError on a
call that should work, or an import that fails - those are almost always
one file being older than the rest, and this says which file in a second
instead of a traceback at a time.

Line endings are normalised before hashing, so a file saved on Windows
still matches. Your .env, your data/ and your real restrictions list are
yours and are never checked.
"""
from __future__ import annotations

import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent

# sha256 of each file with \r\n and trailing whitespace normalised away.
MANIFEST: dict[str, str] = {}  # filled in below by MANIFEST_DATA

MANIFEST_DATA = """
d4d1a57f98c5993a .env.example
fadd557e0489341f .gitignore
8307a702adbed889 README.md
e3b0c44298fc1c14 app/__init__.py
e3b0c44298fc1c14 app/api/__init__.py
a0aea3b7a34e7801 app/api/schemas.py
e53e2588812d2815 app/api/service.py
f6c3af294eb98a37 app/config.py
e3b0c44298fc1c14 app/core/__init__.py
d7f3a5c7bdf927e6 app/core/budget.py
1ac4e98acfa96beb app/core/catalogue.py
459d195aea8ec5dc app/core/eligibility.py
987ec1a20d2f3ee7 app/core/evidence.py
4e49fc5f4e1a13e7 app/core/freshness.py
1032c782327f271e app/core/gaps.py
d639010a7df332a6 app/core/numbers.py
09a053207cbc8065 app/core/policy.py
0882408574e07f5e app/core/profile.py
43bedbf32d184dd6 app/core/restrictions.py
7a77d3fd76e4111a app/core/search.py
402d1a24d0687253 app/errors.py
e3b0c44298fc1c14 app/graphs/__init__.py
3faf4f1d77aeae80 app/graphs/counsellor.py
cecc281a75d8efc8 app/graphs/courses.py
4999a1a043108a5d app/graphs/nodes.py
a409f9a35739ccea app/graphs/runner.py
9483d708899d2c35 app/graphs/scholarships.py
20edd7f013cafc73 app/main.py
e3b0c44298fc1c14 app/providers/__init__.py
66dc3e2a12173f4d app/providers/base.py
dc598c956cfdc78b app/providers/demo.py
7fed535de0b24bd3 app/providers/echo.py
7d3993b544966e9d app/providers/factory.py
fa470734b0c6b369 app/providers/http_llm.py
e3b0c44298fc1c14 app/store/__init__.py
8e23ac656df2041c app/store/json_store.py
e3b0c44298fc1c14 app/tools/__init__.py
bdd1785a0024e494 app/tools/extract.py
700e4501939b3e28 app/tools/fetch.py
dcc4cee460a7fc97 app/tools/search_web.py
e308d335cc177722 app/tracing.py
2f79649f84ee4d1f app/wiring.py
a431c379c7b11902 examples/pages/course-good.html
32e6eb028338f20e examples/pages/course-vague.html
766fab57471276a6 examples/pages/scholarship.html
09963993564adf1f examples/restrictions.sample.json
0913928c5aeba58a examples/students/borderline.json
8fa23438fb04a0c7 examples/students/empty.json
d370d7a8ade5a95f examples/students/strong.json
4f1cb22d53afd44c examples/students/thin.json
15be64fc07cb2bd1 requirements-dev.txt
f1e5032949ebd4d3 requirements.txt
e3b0c44298fc1c14 tests/__init__.py
2fc4bc434c0e3c95 tests/run.py
2c31d3cb8b66dd85 tests/test_core.py
179d54ea1fd078a1 tests/test_service.py
9049f819b724a7fc try.py
"""


def digest(path: pathlib.Path) -> str:
    raw = path.read_bytes().replace(b"\r\n", b"\n").rstrip()
    return hashlib.sha256(raw).hexdigest()[:16]


def main() -> int:
    for line in MANIFEST_DATA.strip().splitlines():
        want, name = line.split(None, 1)
        MANIFEST[name.strip()] = want

    missing: list[str] = []
    stale: list[str] = []

    for name, want in sorted(MANIFEST.items()):
        path = ROOT / name
        if not path.exists():
            missing.append(name)
        elif digest(path) != want:
            stale.append(name)

    if not missing and not stale:
        print(f"All {len(MANIFEST)} files match. If something is still")
        print("broken it is not a stale file - read the traceback.")
        return 0

    if missing:
        print(f"\n{len(missing)} file(s) you do not have:\n")
        for name in missing:
            print(f"    {name}")
    if stale:
        print(f"\n{len(stale)} file(s) that differ from the current version:\n")
        for name in stale:
            print(f"    {name}")
    print("\nAsk for these by name and replace them whole.")
    return 1


if __name__ == "__main__":
    sys.exit(main())