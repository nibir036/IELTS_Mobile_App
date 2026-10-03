"""Convert sir's Speaking guide (HTML) into in-app guide chapters (Bangla).

usage: python3 tool/import_speaking_guide.py
Source: seed/sources/guides/IELTS_Speaking_Guide_book_full.html
Output: seed/staging/speaking_guide/bn/0N_part_x.json  — [{id, title, part, blocks}] in the StudyGuideScreen block
format (see CONTENT_SCHEMA.md). The English version (en/guide.json, same block layout) is a translation.

Kept: Part A (theory & strategy), Part B strategy chapters, Part C (Part 2 & 3 strategy), the final checklist.
Left out: the Part 1 topic bank (32 topics of model answers) and the 40-card cue-card bank (Part D) — the app has
its own speaking bank; they can be imported separately.
"""
import json
import re
from pathlib import Path

from bs4 import BeautifulSoup, NavigableString, Tag

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'seed' / 'sources' / 'guides' / 'IELTS_Speaking_Guide_book_full.html'
OUT = ROOT / 'seed' / 'staging' / 'speaking_guide' / 'bn'
FILES = {'A': '01_part_a.json', 'B': '02_part_b.json', 'C': '03_part_c.json', 'D2': '03_part_c.json'}

SKIP_TITLES = ('সূচিপত্র', 'Topic Bank: Part 1', 'এই অংশটি কীভাবে ব্যবহার করবেন')
SKIP_PREFIX = ('শ্রেণি ',)
BN_DIGITS = str.maketrans('০১২৩৪৫৬৭৮৯', '0123456789')


def inline(node):
    """Text of a node with <b>/<strong> as **bold**, <br> as newline."""
    out = []
    for c in node.children:
        if isinstance(c, NavigableString):
            out.append(str(c))
        elif isinstance(c, Tag):
            if c.name == 'br':
                out.append('\n')
            elif c.name in ('b', 'strong'):
                inner = inline(c).strip()
                if inner:
                    out.append(f'**{inner}**')
            else:
                out.append(inline(c))
    return ''.join(out)


def clean(s):
    s = re.sub(r'[ \t\r\f\v]+', ' ', s)
    s = re.sub(r' *\n *', '\n', s)
    s = s.replace('** **', ' ').replace('****', '')
    return s.strip()


def table(t):
    rows = []
    for tr in t.find_all('tr'):
        cells = [clean(inline(c)) for c in tr.find_all(['th', 'td'])]
        if cells:
            rows.append(cells)
    if not rows:
        return None
    head, body = rows[0], rows[1:]
    n = len(head)
    body = [(r + [''] * n)[:n] for r in body]
    return ['table', head, body]


def classes(tag):
    return tag.get('class') or []


def div_blocks(d):
    cls = classes(d)
    paras = [p for p in d.find_all('p', recursive=False)]
    small = [clean(inline(p)) for p in paras if 'small' in classes(p)]
    main = [clean(inline(p)) for p in paras if 'small' not in classes(p)]
    if not paras:
        main = [clean(inline(d))]
    out = []
    if 'tip' in cls:
        out.append(['tip', '\n'.join(main)])
    elif 'ex' in cls:
        kind = 'model' if 'good' in cls else 'ex'
        text = '\n'.join(main)
        if 'bad' in cls:
            text = '✗ ' + text
        out.append([kind, text])
    elif 'card' in cls:
        ct = d.find(class_='ct')
        title = clean(inline(ct)) if ct else ''
        body = [clean(inline(p)) for p in d.find_all('p')]
        out.append(['note', '\n'.join(([f'**{title}**'] if title else []) + body)])
        small = []
    elif 'qa' in cls:
        out.append(['ex', '\n'.join(main)])
    elif 'notes' in cls:
        out.append(['ex', clean(inline(d))])
    elif 'vocab' in cls or 'p3' in cls:
        out.append(['note', clean(inline(d))])
    else:
        text = '\n'.join(main)
        if text:
            out.append(['p', text])
    for s in small:
        if s:
            out.append(['note', s])
    return [b for b in out if b[1]]


def blocks_of(el):
    if not isinstance(el, Tag):
        return []
    n = el.name
    if n == 'h2':
        return [['h', clean(inline(el))]]
    if n == 'h3':
        return [['h2', clean(inline(el))]]
    if n == 'p':
        t = clean(inline(el))
        return [['note' if 'small' in classes(el) else 'p', t]] if t else []
    if n in ('ul', 'ol'):
        items = [clean(inline(li)) for li in el.find_all('li', recursive=False)]
        return [[n, [i for i in items if i]]] if items else []
    if n == 'table':
        t = table(el)
        return [t] if t else []
    if n == 'div':
        if 'cover' in classes(el):
            return []
        return div_blocks(el)
    return []


def slug(title, used):
    s = re.sub(r'[^a-z0-9]+', '_', title.translate(BN_DIGITS).lower()).strip('_')[:28] or 'ch'
    base, i = s, 2
    while s in used:
        s = f'{base}_{i}'
        i += 1
    used.add(s)
    return s


def part_of(i, title):
    return title


def main():
    soup = BeautifulSoup(SRC.read_text(encoding='utf-8'), 'html.parser')
    chapters, cur, used = [], None, set()
    part = 'A'
    for el in soup.body.children:
        if not isinstance(el, Tag):
            continue
        if el.name == 'div' and 'cover' in classes(el):
            txt = el.get_text(' ')
            m = re.search(r'Part ([A-D]\d?)\s*:', txt)
            if m:
                part = m.group(1)
            continue
        if el.name == 'h1':
            title = clean(inline(el)).replace('**', '')
            skip = title.startswith(SKIP_TITLES) or title.startswith(SKIP_PREFIX) or part.startswith('D') and \
                not title.startswith('পরীক্ষার আগের সপ্তাহ')
            cur = None if skip else {'id': 'sp_' + slug(title, used), 'title': title, 'part': part, 'blocks': []}
            if cur:
                chapters.append(cur)
            continue
        if cur is not None:
            cur['blocks'].extend(blocks_of(el))
    for c in chapters:  # book navigation lines ("— Part C এখানে শেষ … —")
        c['blocks'] = [b for b in c['blocks'] if not (isinstance(b[1], str) and b[1].startswith('— ') and b[1].endswith(' —'))]
    chapters = [c for c in chapters if c['blocks']]
    OUT.mkdir(parents=True, exist_ok=True)
    files = {}
    for c in chapters:
        files.setdefault(FILES[c['part']], []).append(c)
    for name, chs in files.items():
        (OUT / name).write_text(json.dumps(chs, ensure_ascii=False, indent=1), encoding='utf-8')
    n = sum(len(c['blocks']) for c in chapters)
    print(f'{len(chapters)} chapters · {n} blocks → {OUT.relative_to(ROOT)}/ {sorted(files)}')
    for c in chapters:
        print(f"  {c['part']:3} {c['id']:34} {len(c['blocks']):3}  {c['title'][:60]}")


if __name__ == '__main__':
    main()
