"""REPLACED by tool/import_vocab_book.py (the full book). Kept for reference only; running it does nothing.

Old: Vocabulary Lessons (study guide 'vocab') from the website's vocabulary course lessons.

usage: python3 tool/import_vocab_lessons.py
Source: seed/sources/vocab/all-chapters-lessons.json (29 lessons in 6 chapters: L1 errors, lexical upgrade,
        grammar & cohesion, topic vocabulary, idioms & register, exam practice).
Output: seed/staging/vocab_guide/en/NN_<collection>.json — one in-app chapter per lesson: the lesson's short
        summary (tip) + its notes. The Bangla version (bn/) is a translation with the same layout.
Lines pointing to "the full chapter" (not part of the app) are left out.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
import import_grammar as ig  # noqa: E402  (clean, md_table)

SRC = ROOT / 'seed' / 'sources' / 'vocab' / 'all-chapters-lessons.json'
ST = ROOT / 'seed' / 'staging' / 'vocab_guide'


def dash(s):
    return s.replace(' -- ', ' — ').replace('--', '—')


def md(text):
    """Lesson markdown → blocks (### → h2, - / * bullets with indented continuation lines, | tables |, paragraphs)."""
    out, items, rows = [], [], []

    def flush():
        nonlocal items, rows
        if items:
            out.append(['ul', items])
            items = []
        if rows:
            out.append(ig.md_table(rows))
            rows = []

    for raw in dash(text).split('\n'):
        s = raw.strip()
        if re.search(r'(see|open) the full chapter', s, re.I):
            continue
        if s.startswith('|'):
            if items:
                out.append(['ul', items])
                items = []
            rows.append(s)
            continue
        if raw.startswith('  ') and s and items:
            items[-1] += '\n' + ig.clean(s)
            continue
        if re.match(r'^[-*]\s+', s):
            if rows:
                out.append(ig.md_table(rows))
                rows = []
            items.append(ig.clean(re.sub(r'^[-*]\s+', '', s)))
            continue
        flush()
        if not s:
            continue
        if s.startswith('#'):
            out.append(['h2', ig.clean(s.lstrip('#'))])
        else:
            out.append(['p', ig.clean(s)])
    flush()
    return out


def main():
    lessons = json.loads(SRC.read_text(encoding='utf-8'))['lessons']
    lessons.sort(key=lambda x: (x['chapterNumber'], x['position']))
    out_dir = ST / 'en'
    out_dir.mkdir(parents=True, exist_ok=True)
    files = {}
    for n, les in enumerate(lessons, 1):
        col = les['collection']
        files.setdefault((les['chapterNumber'], col['slug']), []).append({
            'id': f'v{n:02d}_{les["slug"].replace("-", "_")[:40]}',
            'title': f'{n}. {ig.clean(les["title"])}',
            'group': f'Chapter {les["chapterNumber"]} · {col["label"]}',
            'blocks': [['tip', dash(ig.clean(les['bite']))]] + md(les['detail_md']),
        })
    for (ch, slug), chs in files.items():
        name = f'{ch:02d}_{slug.replace("-", "_")}.json'
        (out_dir / name).write_text(json.dumps(chs, ensure_ascii=False, indent=1), encoding='utf-8')
        print(f'{name}: {len(chs)} lessons · {sum(len(c["blocks"]) for c in chs)} blocks')


if __name__ == '__main__':
    raise SystemExit('Replaced by tool/import_vocab_book.py (the full Zero to Band 9 book).')
