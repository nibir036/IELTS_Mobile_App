"""Listening Guide + Listening tips from the website's Listening module (Zero to Band 9 field guide, Module 1).

usage: python3 tool/import_listening_guide.py
Source: seed/sources/listening/listening-module-1.json          (7 files: content blocks)
        seed/sources/listening/listening-module-1-lessons.json  (23 short lessons in 4 collections)
Output: seed/staging/listening_guide/en/NN_<file>.json  — in-app guide chapters (StudyGuideScreen 'listening'):
          each file's lesson part (split in two when long) + "N. Practice · …" with its drills as exercises.
        seed/staging/listening_guide/tips_en.json       — 4 tip articles (series 'listening'), one per lesson
          collection; each tip = a lesson (bite + the key points of its detail).
        seed/staging/listening_guide/callouts_bn.json   — the source's own Bangla for each tutor tip (block id → bn),
          given to the translators.
The Bangla version (bn/, tips_bn.json) is a translation with the same layout.

Blocks: paragraph → p · heading 2/3 → h/h2 · list → ul/ol · table → table (+caption) · callout (Tutor Insider Tip) →
tip · principle → note · practice_drill → exercise (kind essay_edit: try it, then reveal the model answer).
Footers ("Zero to Band 9 … Next: File 0x") and the module title heading are left out.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
import import_grammar as ig  # noqa: E402  (clean, md_blocks, size, split)

SRC = ROOT / 'seed' / 'sources' / 'listening'
ST = ROOT / 'seed' / 'staging' / 'listening_guide'

SHORT = {1: 'foundations', 2: 'prediction', 3: 'distractors', 4: 'completion', 5: 'selection', 6: 'recovery',
         7: 'practice'}
GROUP = {1: 'Strategy', 2: 'Strategy', 3: 'Strategy', 4: 'Question types', 5: 'Question types', 6: 'Test day',
         7: 'Practice tests'}


def drill(b):
    prompt = ig.clean(b['prompt'])
    lines = prompt.split('\n')
    instr, rest = (lines[0], '\n'.join(lines[1:]).strip()) if len(lines) > 1 else ('', prompt)
    return ['exercise', {
        'title': ig.clean(b['label']),
        'kind': 'essay_edit',
        'instructions': instr or 'Try it first, then compare with the model answer.',
        'items': [{'prompt': rest or prompt, 'answer': ig.clean(b['answer']), 'accepted': [], 'reason': ''}],
    }]


def block(b):
    t = b['type']
    if t == 'paragraph':
        return None if b.get('variant') == 'footer' else ['p', ig.clean(b['text'])]
    if t == 'heading':
        return ['h' if b.get('level', 2) <= 2 else 'h2', ig.clean(b['text'])]
    if t == 'list':
        return ['ol' if b.get('ordered') else 'ul', [ig.clean(x) for x in b['items']]]
    if t == 'table':
        out = ['table', [ig.clean(x) for x in b['headers']], [[ig.clean(c) for c in r] for r in b['rows']]]
        if b.get('caption'):
            out.append(ig.clean(b['caption']))
        return out
    if t == 'callout':
        return ['tip', ig.clean(b['text'])]
    if t == 'principle':
        return ['note', ig.clean(b['text'])]
    if t == 'practice_drill':
        return drill(b)
    raise ValueError(f'unknown block type {t}')


def guide():
    m = json.loads((SRC / 'listening-module-1.json').read_text(encoding='utf-8'))
    out_dir = ST / 'en'
    out_dir.mkdir(parents=True, exist_ok=True)
    callouts = {}
    total = 0
    for c in sorted(m['chapters'], key=lambda c: c['position']):
        no = c['position']
        name = re.sub(r'^File \d+:\s*', '', ig.clean(c['title']))
        blocks, ids = [], []
        for b in c['content']['blocks']:
            if b['type'] == 'heading' and b['text'].strip().upper() == 'IELTS LISTENING':
                continue
            if b['type'] == 'callout' and b.get('bn'):
                callouts[b['id']] = b['bn']
            x = block(b)
            if x is not None:
                blocks.append(x)
                ids.append(b['id'])
        # lesson part | practice part (from the "Practice" heading, or all of File 07)
        cut = next((i for i, x in enumerate(blocks) if x[0] == 'h' and x[1].lower() == 'practice'), None)
        if no == 7:
            lesson, practice = [], blocks
        elif cut is None:
            lesson, practice = blocks, []
        else:
            lesson, practice = blocks[:cut], blocks[cut + 1:]
        lead = ['p', ig.clean(c['summary'])] if c.get('summary') else None
        chapters = []
        if lesson:
            parts = ig.split(lesson) if ig.size(lesson) > ig.SPLIT_OVER else [lesson]
            for k, part in enumerate(parts, 1):
                chapters.append({
                    'id': f'l{no:02d}_{SHORT[no]}' + (f'_{k}' if len(parts) > 1 else ''),
                    'title': f'{no}. {name}' + (f' ({k}/{len(parts)})' if len(parts) > 1 else ''),
                    'group': GROUP[no],
                    'blocks': ([lead] if lead and k == 1 else []) + part,
                })
        if practice:
            chapters.append({
                'id': f'l{no:02d}_{SHORT[no]}' + ('' if no == 7 else '_practice'),
                'title': f'{no}. {name}' if no == 7 else f'{no}. Practice · {name}',
                'group': GROUP[no],
                'blocks': ([lead] if no == 7 and lead else []) + practice,
            })
        fname = f'{no:02d}_{SHORT[no]}.json'
        (out_dir / fname).write_text(json.dumps(chapters, ensure_ascii=False, indent=1), encoding='utf-8')
        total += len(chapters)
        ex = sum(1 for ch in chapters for x in ch['blocks'] if x[0] == 'exercise')
        print(f'{fname}: {len(chapters)} chapters · {sum(len(ch["blocks"]) for ch in chapters)} blocks · {ex} drills')
    (ST / 'callouts_bn.json').write_text(json.dumps(callouts, ensure_ascii=False, indent=1), encoding='utf-8')
    print(f'{total} guide chapters · {len(callouts)} tutor tips with source Bangla')


def lesson_points(md):
    """A lesson's detail markdown → one tip body: the "why it matters" line and the key bullets, as plain text
    (**bold** kept)."""
    lines = []
    for raw in md.split('\n'):
        s = raw.strip()
        if not s or s.startswith('|') or re.fullmatch(r'-{3,}', s):
            continue
        if s.startswith('>') and re.search('[\u0980-\u09FF]', s):
            continue  # the author's short Bangla note: the Bangla tips carry a full translation instead
        if s.startswith('#'):
            s = '**' + re.sub(r'^#+\s*', '', s).strip('* ') + '**'
        s = re.sub(r'^\d+\.\s+', '• ', s)
        s = re.sub(r'^[-*]\s+', '• ', s)
        lines.append(ig.clean(s))
    return '\n'.join(lines)


def tips():
    d = json.loads((SRC / 'listening-module-1-lessons.json').read_text(encoding='utf-8'))
    groups = {}
    for les in sorted(d['lessons'], key=lambda x: x['position']):
        groups.setdefault(les['collection']['slug'], (les['collection']['label'], []))[1].append(les)
    arts = []
    titles = {
        'before-the-audio': 'Before the audio: read, predict and paraphrase',
        'question-types': 'Every question type: what to do in each',
        'traps': 'Traps: corrections, distractors and negatives',
        'test-day-skills': 'Test day: recover, check and manage time',
    }
    for slug, (label, items) in groups.items():
        arts.append({
            'id': f'lt_{slug.replace("-", "_")}',
            'series': 'listening',
            'chip': label,
            'breadcrumb': 'Home / Listening / Tips',
            'title': titles.get(slug, label),
            'meta': f'Listening Tips · {sum(x.get("estimated_min", 3) for x in items)} min read · from the Listening Guide',
            'defaultTip': 1,
            'tips': [{'title': ig.clean(x['title']),
                      'body': ig.clean(x['bite']) + '\n\n' + lesson_points(x['detail_md'])} for x in items],
            'tryIt': {'text': 'Try it: read the full chapter in the Listening Guide.', 'target': 'listeningGuide'},
        })
    (ST / 'tips_en.json').write_text(json.dumps(arts, ensure_ascii=False, indent=1), encoding='utf-8')
    print(f'{len(arts)} tip articles · {sum(len(a["tips"]) for a in arts)} tips')


if __name__ == '__main__':
    guide()
    tips()
