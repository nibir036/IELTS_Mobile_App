"""Validates tool/sentence_src/*.json and builds assets/content/sentence_bank.json
(the Sentence Builder bank: categories -> sets of 10 drills).

    python3 tool/build_sentence_bank.py                 # validate all + build
    python3 tool/build_sentence_bank.py --check FILE    # validate one file
"""
import glob
import json
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tool', 'sentence_src')
OUT = os.path.join(ROOT, 'assets', 'content', 'sentence_bank.json')
SET_SIZE = 10

# Order and wording shown in the app.
CATEGORIES = [
    ('relative', 'Relative clauses', 'which, who, where, whose, that', 'link'),
    ('adding', 'Adding information', 'furthermore, moreover, in addition', 'add'),
    ('contrast', 'Contrast', 'however, whereas, while, in contrast', 'swap'),
    ('concession', 'Concession', 'although, despite, even though, admittedly', 'swap'),
    ('cause', 'Cause & reason', 'because, since, due to, owing to', 'target'),
    ('result', 'Result & consequence', 'therefore, as a result, consequently', 'forward'),
    ('purpose', 'Purpose', 'in order to, so that, so as to', 'flag'),
    ('condition', 'Condition', 'if, unless, provided that, as long as', 'settings'),
    ('time', 'Time & sequence', 'when, after, before, once, until', 'clock'),
    ('examples', 'Examples & emphasis', 'for example, such as, in particular, indeed', 'list'),
    ('comparison', 'Comparison', 'similarly, likewise, compared with', 'layers'),
    ('summary', 'Generalising & concluding', 'in general, in other words, overall', 'check'),
    ('task1', 'Task 1: describing data', 'while, whereas, followed by, peaking at', 'doc'),
]
INSTRUCTION = 'Join the two sentences into one'

DASHES = re.compile('[–—]')


def check_file(path, seen_answers=None, seen_ids=None):
    errs = []
    try:
        data = json.load(open(path, encoding='utf-8'))
    except Exception as e:  # noqa: BLE001
        return [f'{path}: invalid JSON: {e}'], None
    cat = data.get('category')
    if cat not in {c[0] for c in CATEGORIES}:
        errs.append(f'{path}: unknown category {cat!r}')
    drills = data.get('drills') or []
    seen_answers = seen_answers if seen_answers is not None else {}
    seen_ids = seen_ids if seen_ids is not None else set()
    for n, d in enumerate(drills):
        did = d.get('id', f'#{n}')
        def bad(msg):
            errs.append(f'{did}: {msg}')
        for k in ('id', 'connector', 'function', 'sentences', 'answer', 'prefilled', 'distractors', 'hint', 'level'):
            if k not in d:
                bad(f'missing {k}')
        if any(k not in d for k in ('answer', 'sentences', 'distractors')):
            continue
        if not str(did).startswith(f'{cat}_'):
            bad('id must start with category')
        if did in seen_ids:
            bad('duplicate id')
        seen_ids.add(did)
        ans = d['answer']
        if not (4 <= len(ans) <= 7):
            bad(f'answer has {len(ans)} chunks (4-7)')
        if any((not isinstance(c, str)) or c != c.strip() or not c for c in ans):
            bad('empty chunk or spaces around a chunk')
            continue
        if len(set(ans)) != len(ans):
            bad('repeated chunk')
        long = [c for c in ans if len(c) > 30]
        if long:
            bad(f'chunk over 30 chars: {long}')
        joined = ' '.join(ans)
        if not ans[0][0].isupper():
            bad('first chunk must start with a capital')
        if not joined.endswith('.'):
            bad('answer must end with "."')
        if re.search(r'\s[,;.:]', joined) or '  ' in joined:
            bad('space before punctuation / double space')
        if re.search(r'[.!?]\s', joined[:-1]):
            bad('answer contains more than one sentence')
        conn = d['connector'].lower().replace('…', '...')
        parts = [p.strip() for p in conn.split('...') if p.strip()]
        jl = joined.lower()
        if not all(p in jl for p in parts):
            bad(f'connector "{conn}" not in answer')
        sents = d['sentences']
        if len(sents) != 2 or any(not s.endswith('.') for s in sents):
            bad('need exactly 2 source sentences ending with "."')
        pre = d['prefilled']
        if not isinstance(pre, int) or pre < 0 or pre > 2 or len(ans) - pre < 3:
            bad('prefilled must be 0-2 and leave at least 3 chunks')
        dis = d['distractors']
        if not (1 <= len(dis) <= 2):
            bad('need 1-2 distractors')
        low = {c.lower() for c in ans}
        if any(x.lower() in low for x in dis):
            bad('distractor equals an answer chunk')
        if len(set(dis)) != len(dis):
            bad('repeated distractor')
        if len(ans) - pre + len(dis) > 8:
            bad('word bank over 8 chunks')
        if len(d['hint']) > 140:
            bad('hint too long')
        if d['level'] not in (1, 2, 3):
            bad('level must be 1, 2 or 3')
        blob = json.dumps(d, ensure_ascii=False)
        if DASHES.search(blob):
            bad('contains an em/en dash')
        if '“' in d['hint'] or '”' in d['hint']:
            bad('use straight quotes in hint')
        key = jl
        if key in seen_answers:
            bad(f'duplicate answer (also {seen_answers[key]})')
        seen_answers[key] = did
    return errs, data


def build():
    seen_answers, seen_ids, all_errs, cats = {}, set(), [], []
    for cid, title, subtitle, icon in CATEGORIES:
        path = os.path.join(SRC, f'{cid}.json')
        if not os.path.exists(path):
            all_errs.append(f'missing {path}')
            continue
        errs, data = check_file(path, seen_answers, seen_ids)
        all_errs += errs
        if not data:
            continue
        drills = []
        for d in data['drills']:
            ans = d['answer']
            bank = ans[d['prefilled']:] + d['distractors']
            rnd = random.Random(d['id'])
            for _ in range(10):
                rnd.shuffle(bank)
                if bank[:len(ans) - d['prefilled']] != ans[d['prefilled']:]:
                    break
            drills.append({
                'id': d['id'],
                'connector': d['connector'],
                'function': d['function'],
                'sentences': d['sentences'],
                'answer': ans,
                'prefilled': d['prefilled'],
                'bank': bank,
                'hint': d['hint'],
                'level': d['level'],
            })
        # Easier drills first inside each category, then sets of 10.
        drills.sort(key=lambda x: (x['level'], x['id']))
        sets = []
        for i in range(0, len(drills), SET_SIZE):
            chunk = drills[i:i + SET_SIZE]
            if len(chunk) < 5 and sets:
                sets[-1]['drills'] += chunk
                continue
            sets.append({'id': f'{cid}_set{len(sets) + 1:02d}', 'title': f'Set {len(sets) + 1}', 'drills': chunk})
        cats.append({'id': cid, 'title': title, 'subtitle': subtitle, 'icon': icon,
                     'count': len(drills), 'sets': sets})
    if all_errs:
        print('\n'.join(all_errs[:200]))
        print(f'{len(all_errs)} problem(s); bank not written.')
        sys.exit(1)
    out = {'instruction': INSTRUCTION, 'setSize': SET_SIZE,
           'total': sum(c['count'] for c in cats), 'categories': cats}
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print(f'wrote {OUT}: {out["total"]} drills in {len(cats)} categories')


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--check':
        errs, data = check_file(sys.argv[2])
        n = len((data or {}).get('drills') or [])
        print('\n'.join(errs) if errs else f'OK: {n} drills')
        sys.exit(1 if errs else 0)
    build()
