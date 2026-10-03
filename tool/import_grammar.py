"""Convert the Grammar course (web version seed data) into in-app guide chapters (English).

usage: python3 tool/import_grammar.py
Source: seed/sources/grammar/all-chapters.json (4 modules, 11 chapters, exercises) and
        seed/sources/grammar/all-chapters-lessons.json (one short recap per exercise)
        + seed/staging/grammar_guide/added_exercises.json (exercises the course was missing)
        + seed/staging/grammar_guide/fixes.json (English text missing in the source, e.g. a paragraph with only
          its Bangla summary)
Output: seed/staging/grammar_guide/en/NN_<chapter>.json — one file per source chapter, each a list of in-app
        chapters: the lesson (split in two when long) and, when the chapter has exercises, a practice chapter.
        The Bangla version (bn/, same block layout) is a translation.

Blocks (StudyGuideScreen): p, h, h2, ul, ol, table (+caption), box [kind, title, body, items], pair [incorrect,
correct, why], exercise {title, kind, instructions, items[{prompt, answer, accepted, reason}]}, tip.
Text is copied as is; only *italic* markers and HTML entities from the recaps are normalised.
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'seed' / 'sources' / 'grammar'
ST = ROOT / 'seed' / 'staging' / 'grammar_guide'
SPLIT_OVER = 9000          # characters of lesson text before a chapter is split in two

SHORT = {
    'ch1-subject-verb-agreement': 'agreement', 'ch2-tense-mastery': 'tenses', 'ch3-articles-nouns': 'articles',
    'ch4-prepositions': 'prepositions', 'ch5-complex-sentences': 'complex', 'ch6-passive-voice': 'passive',
    'ch7-conditionals-hedging': 'conditionals', 'ch8-inversion-clefts': 'inversion', 'ch9-nominalisation':
    'nominalisation', 'ch10-essay-editing': 'editing', 'ch11-answer-keys': 'review',
}


def clean(s):
    s = html.unescape(s or '')
    s = re.sub(r'(?<![*\w])\*(?!\*)([^*\n]+?)\*(?!\*)', r'\1', s)   # *italic* → plain (keep **bold**)
    return s.strip()


FIXES = {}  # block id → English text the source is missing (seed/staging/grammar_guide/fixes.json)


def block(b):
    t = b['type']
    if t == 'paragraph':
        return ['p', clean(b['text']) or FIXES.get(b['id'], '')]
    if t == 'heading':
        return ['h' if b.get('level', 2) <= 2 else 'h2', clean(b['text'])]
    if t == 'list':
        return ['ol' if b.get('ordered') else 'ul', [clean(x) for x in b['items']]]
    if t == 'table':
        out = ['table', [clean(x) for x in b['headers']], [[clean(c) for c in r] for r in b['rows']]]
        if b.get('caption'):
            out.append(clean(b['caption']))
        return out
    if t == 'callout':
        return ['box', 'regional', clean(b.get('title')), clean(b['text']), []]
    if t == 'example_pair':
        return ['pair', clean(b['incorrect']), clean(b['correct']), clean(b.get('why'))]
    if t == 'l1_error_fixer':
        items = [f"{clean(e['label'])}\n✗ {clean(e['incorrect'])}\n✓ {clean(e['correct'])}"
                 for e in b.get('error_types', [])]
        return ['box', 'l1', clean(b['title']), clean(b['body']), items]
    if t == 'ielts_impact':
        items = [f'{k}: {clean(v)}' for k, v in (b.get('examples') or {}).items()]
        skills = ', '.join(s.capitalize() for s in b.get('skills', []))
        body = clean(b['body']) + (f'\n\nSkills: {skills}' if skills else '')
        return ['box', 'impact', clean(b['title']), body, items]
    raise ValueError(f'unknown block type {t}')


def md_table(rows):
    """Markdown table lines (| a | b |, |---|) → a table block."""
    cells = [[clean(c) for c in r.strip().strip('|').split('|')] for r in rows
             if not re.fullmatch(r'\|?\s*:?-{2,}.*', r.strip())]
    return ['table', cells[0], cells[1:]]


def md_blocks(md):
    """The recap markdown (### headings, - lists, | tables |, paragraphs) → blocks."""
    out, items, rows = [], [], []
    for line in md.split('\n'):
        s = line.strip()
        if s.startswith('|'):
            rows.append(s)
            continue
        if rows:
            out.append(md_table(rows))
            rows = []
        if s.startswith('- '):
            items.append(clean(s[2:]))
            continue
        if items:
            out.append(['ul', items])
            items = []
        if not s:
            continue
        if s.startswith('#'):
            out.append(['h2', clean(s.lstrip('#'))])
        else:
            out.append(['p', clean(s)])
    if items:
        out.append(['ul', items])
    if rows:
        out.append(md_table(rows))
    return out


def exercise(e):
    return ['exercise', {
        'title': clean(e['title']),
        'kind': e['kind'],
        'instructions': clean(e['instructions']),
        'items': [{'prompt': clean(i['prompt']), 'answer': clean(i['answer']),
                   'accepted': [clean(a) for a in i.get('accepted', [])], 'reason': clean(i.get('reason'))}
                  for i in e['items']],
    }]


def size(blocks):
    return len(json.dumps(blocks, ensure_ascii=False))


def split(blocks):
    """Split before the level-2 heading closest to the middle (by text size)."""
    total = size(blocks)
    cands = [i for i, b in enumerate(blocks) if b[0] == 'h' and 0 < i < len(blocks)]
    if not cands:
        return [blocks]
    best = min(cands, key=lambda i: abs(size(blocks[:i]) - total / 2))
    return [blocks[:best], blocks[best:]]


def main():
    g = json.loads((SRC / 'all-chapters.json').read_text(encoding='utf-8'))
    recaps = json.loads((SRC / 'all-chapters-lessons.json').read_text(encoding='utf-8'))['lessons']
    added_f = ST / 'added_exercises.json'
    added = json.loads(added_f.read_text(encoding='utf-8')) if added_f.exists() else []
    fixes_f = ST / 'fixes.json'
    if fixes_f.exists():
        FIXES.update({k: v['en'] for k, v in json.loads(fixes_f.read_text(encoding='utf-8')).items()})
    modules = {m['id']: m for m in g['modules']}
    out_dir = ST / 'en'
    out_dir.mkdir(parents=True, exist_ok=True)
    chapters = sorted(g['chapters'], key=lambda c: (modules[c['module_id']]['position'], int(c['position'])))
    n_total = 0
    for no, c in enumerate(chapters, 1):
        m = modules[c['module_id']]
        group = f"Module {m['position']} · {m['title']}"
        short = SHORT[c['slug']]
        blocks = [block(b) for b in c['content']['blocks']]
        lead = ['p', clean(c['summary'])] if c.get('summary') else None
        parts = split(blocks) if size(blocks) > SPLIT_OVER else [blocks]
        out = []
        for k, part in enumerate(parts, 1):
            title = f"{no}. {clean(c['title'])}" + (f' ({k}/{len(parts)})' if len(parts) > 1 else '')
            out.append({'id': f'g{no:02d}_{short}' + (f'_{k}' if len(parts) > 1 else ''), 'title': title,
                        'group': group, 'blocks': ([lead] if lead and k == 1 else []) + part})
        exs = [e for e in g['exercises'] if e['chapter_id'] == c['id']]
        exs.sort(key=lambda e: int(e.get('position') or 0))
        exs += [e for e in added if e['chapter'] == c['slug']]
        if exs:
            prac = []
            for e in exs:
                rec = next((r for r in recaps if r.get('exercise_id') == e.get('id')), None)
                if rec:
                    prac.append(['h', f"Recap · {clean(rec['title'])}"])
                    prac.append(['tip', clean(rec['bite'])])
                    prac += md_blocks(rec.get('detail_md') or '')
                prac.append(exercise(e))
            out.append({'id': f'g{no:02d}_{short}_practice', 'title': f'{no}. Practice · {clean(c["title"])}',
                        'group': group, 'blocks': prac})
        name = f'{no:02d}_{short}.json'
        (out_dir / name).write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding='utf-8')
        n_total += len(out)
        print(f"{name}: {len(out)} chapters · {sum(len(x['blocks']) for x in out)} blocks · "
              f"{len(exs)} exercises · {sum(len(e['items']) for e in exs)} items")
    print(f'{n_total} in-app chapters → {out_dir.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
