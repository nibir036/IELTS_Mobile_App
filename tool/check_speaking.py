"""Check speaking staging files (seed/staging/speaking/part1|part2|part3/*.json).

usage: python3 tool/check_speaking.py [id-prefix ...]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ST = ROOT / 'seed' / 'staging' / 'speaking'
BASE = ST / 'base'

PLAIN = set("""
a an the and or but so because if when then than that this these those it its he she they we you i me my our your
be is are was were been being have has had having do does did done make made get got go went gone come came take took
give gave say said see saw look find found think thought know knew want need use used like liked love loved feel felt
people person man men woman women child children family friend friends home house life time times day days year years
work job money health healthy good bad big small new old great little long short high low right wrong best better
buy bought sell pay cost price cheap expensive car cars road roads bus train city town country world place places
both all some many much more most few less each every other another same different important easy hard difficult
school study student teacher learn learned food eat water help helped play played game games team goal goals tool tools
thing things way ways idea ideas problem problems reason reasons part parts kind lot lots really very quite also just
increase decrease rise fall grow change changed changes success successful happy sad nice fun interesting boring
match risk risks lack self path fair shift norm fuel glue toll bond save saved spend spent start started stop finish
""".split())
DASH = re.compile('[—–]')


def words(s):
    return len(re.findall(r"[A-Za-z0-9'’-]+", s.replace('[[', '').replace(']]', '')))


def marks(s):
    return re.findall(r'\[\[(.+?)\]\]', s)


def weak(ms):
    return [m for m in ms if len(m.split()) == 1 and m.lower().strip(".,'") in PLAIN]


def load(name):
    return json.loads((BASE / name).read_text(encoding='utf-8'))


def check_text(where, s, errs):
    if DASH.search(s):
        errs.append(f'{where}: em/en dash')
    if s.count('[[') != s.count(']]') or re.search(r'\[\[[^\]]*\[\[', s):
        errs.append(f'{where}: broken [[mark]]')


def part1(prefixes):
    sets = {s['id']: s for s in load('part1_sets.json')}
    errs, warns, n = [], [], 0
    for f in sorted((ST / 'part1').glob('*.json')):
        d = json.loads(f.read_text(encoding='utf-8'))
        i = d.get('id')
        if prefixes and not i.startswith(tuple(prefixes)):
            continue
        n += 1
        if i not in sets or f.stem != i:
            errs.append(f'{f.name}: unknown id {i}')
            continue
        qs = d.get('questions', [])
        if len(qs) != 5:
            errs.append(f'{i}: {len(qs)} questions (need 5)')
        orig = {o['source']: o for o in sets[i]['originals']}
        seen = set()
        for k, q in enumerate(qs, 1):
            w = f'{i} Q{k}'
            check_text(w, q.get('q', '') + ' ' + q.get('answer', ''), errs)
            src = q.get('source')
            if src is not None:
                if src not in orig:
                    errs.append(f'{w}: source {src} not in this topic')
                    continue
                seen.add(src)
                o = orig[src]
                if q['q'] != o['q']:
                    errs.append(f'{w}: original question changed')
                allowed = (i, src) in {('sp1_family', 3), ('sp1_future-plans', 15)}
                if q['answer'] != o['answer'] and not allowed:
                    errs.append(f'{w}: original answer changed')
                if allowed and len(marks(q['answer'])) != 1:
                    errs.append(f'{w}: needs exactly one mark')
            else:
                wc, ms = words(q['answer']), marks(q['answer'])
                if not 25 <= wc <= 50:
                    errs.append(f'{w}: {wc} words (25-50)')
                if len(ms) != 1:
                    errs.append(f'{w}: {len(ms)} marks (need 1)')
                if weak(ms):
                    errs.append(f'{w}: plain word marked {weak(ms)}')
        if set(orig) - seen:
            errs.append(f'{i}: missing originals {sorted(set(orig) - seen)}')
        if len({q['q'].lower() for q in qs}) != len(qs):
            errs.append(f'{i}: duplicate question')
    missing = [i for i in sets if not (ST / 'part1' / f'{i}.json').exists()]
    return 'part1', n, len(sets), missing, errs, warns


def part2(prefixes):
    cards = {c['id']: c for c in load('part2.json')}
    p3 = {t['id'] for t in load('part3.json')}
    errs, warns, n = [], [], 0
    for f in sorted((ST / 'part2').glob('*.json')):
        d = json.loads(f.read_text(encoding='utf-8'))
        i = d.get('id')
        if prefixes and not i.startswith(tuple(prefixes)):
            continue
        n += 1
        if i not in cards or f.stem != i:
            errs.append(f'{f.name}: unknown id {i}')
            continue
        a = d.get('answer', '')
        check_text(i, a, errs)
        wc, ms = words(a), marks(a)
        if not 240 <= wc <= 290:
            errs.append(f'{i}: {wc} words (240-290)')
        if not 4 <= len(ms) <= 6:
            errs.append(f'{i}: {len(ms)} marks (4-6)')
        if weak(ms):
            errs.append(f'{i}: plain word marked {weak(ms)}')
        if len({m.lower() for m in ms}) != len(ms):
            errs.append(f'{i}: repeated mark')
        kept = [m for m in cards[i]['vocab'] if m.lower() in {x.lower() for x in ms}]
        if len(kept) < len(cards[i]['vocab']) - 1:
            warns.append(f'{i}: kept only {kept} of sir\'s marks {cards[i]["vocab"]}')
        fu = d.get('followUps', [])
        if len(fu) != 2:
            errs.append(f'{i}: {len(fu)} followUps (need 2)')
        for k, x in enumerate(fu, 1):
            check_text(f'{i} F{k}', x.get('q', '') + ' ' + x.get('answer', ''), errs)
            fw = words(x.get('answer', ''))
            if not 25 <= fw <= 40:
                errs.append(f'{i} F{k}: {fw} words (25-40)')
            if len(marks(x.get('answer', ''))) > 1:
                errs.append(f'{i} F{k}: more than one mark')
        links = d.get('part3', [])
        if not 1 <= len(links) <= 2 or any(x not in p3 for x in links):
            errs.append(f'{i}: bad part3 links {links}')
    missing = [i for i in cards if not (ST / 'part2' / f'{i}.json').exists()]
    return 'part2', n, len(cards), missing, errs, warns


def part3(prefixes):
    topics = {t['id']: t for t in load('part3.json')}
    errs, warns, n = [], [], 0
    for f in sorted((ST / 'part3').glob('*.json')):
        d = json.loads(f.read_text(encoding='utf-8'))
        i = d.get('id')
        if prefixes and not i.startswith(tuple(prefixes)):
            continue
        n += 1
        if i not in topics or f.stem != i:
            errs.append(f'{f.name}: unknown id {i}')
            continue
        fixes = {x['n']: x['answer'] for x in d.get('fixes', [])}
        topic_marks = []
        for q in topics[i]['questions']:
            w = f"{i} Q{q['n']}"
            a = fixes.get(q['n'], q['answer'])
            if q['n'] in fixes:
                check_text(w, a, errs)
                wc = words(a)
                if not 50 <= wc <= 85:
                    errs.append(f'{w}: {wc} words (50-85)')
            ms = marks(a)
            topic_marks += [m.lower() for m in ms]
            if len(ms) != 3:
                errs.append(f'{w}: {len(ms)} marks (need 3)')
            if weak(ms):
                errs.append(f'{w}: plain word marked {weak(ms)}')
            miss = [v for v in q['sourceVocabLine'] if v.lower() not in {m.lower() for m in ms}]
            if miss and q['n'] not in fixes:
                warns.append(f'{w}: vocab line word not marked {miss}')
        dup = {m for m in topic_marks if topic_marks.count(m) > 1}
        if dup:
            warns.append(f'{i}: mark repeated in topic {sorted(dup)}')
    missing = [i for i in topics if not (ST / 'part3' / f'{i}.json').exists()]
    return 'part3', n, len(topics), missing, errs, warns


def vocab(prefixes):
    todo, done = {}, {}
    for f in sorted((ST / 'vocab').glob('todo_*.json')):
        for x in json.loads(f.read_text(encoding='utf-8')):
            todo[x['key']] = f.stem[5:]
    errs, warns = [], []
    for f in sorted((ST / 'vocab').glob('entries_*.json')):
        if prefixes and not any(f.stem.endswith(p) for p in prefixes):
            continue
        for e in json.loads(f.read_text(encoding='utf-8')):
            k = e.get('key', '')
            w = f'{f.stem}:{k}'
            if k not in todo:
                errs.append(f'{w}: key not in todo lists')
                continue
            done[k] = e
            for fld in ('headword', 'pos', 'ipa', 'meaning', 'example', 'level'):
                if not str(e.get(fld, '')).strip():
                    errs.append(f'{w}: missing {fld}')
            if not re.fullmatch(r'/[^/]+/', e.get('ipa', '')):
                errs.append(f'{w}: ipa must look like /.../')
            if e.get('level') not in ('B2', 'C1', 'C2'):
                errs.append(f'{w}: level must be B2, C1 or C2')
            syn = e.get('synonyms', [])
            if not 2 <= len(syn) <= 4:
                errs.append(f'{w}: {len(syn)} synonyms (2-4)')
            mw = words(e.get('meaning', ''))
            if not 5 <= mw <= 25:
                errs.append(f'{w}: meaning {mw} words (5-25)')
            ew = words(e.get('example', ''))
            if not 8 <= ew <= 30:
                errs.append(f'{w}: example {ew} words (8-30)')
            for fld in ('meaning', 'example'):
                if DASH.search(e.get(fld, '')):
                    errs.append(f'{w}: dash in {fld}')
            hw = e.get('headword', '')
            syl = e.get('syllables', [])
            if ' ' not in hw.strip():
                joined = ''.join(x.get('text', '') for x in syl).lower()
                if joined.replace('-', '') != hw.lower().replace('-', ''):
                    errs.append(f'{w}: syllables {joined!r} do not spell {hw!r}')
                st = sum(1 for x in syl if x.get('stress'))
                if len(syl) > 1 and st != 1:
                    errs.append(f'{w}: {st} stressed syllables (need 1)')
                if len(syl) == 1 and st != 1:
                    errs.append(f'{w}: one-syllable word must be stressed')
            elif syl:
                errs.append(f'{w}: phrases take syllables []')
    scope = [k for k, c in todo.items() if not prefixes or any(c == p for p in prefixes)]
    missing = [k for k in scope if k not in done]
    return 'vocab', len(done), len(scope), missing, errs, warns


if __name__ == '__main__':
    pre = sys.argv[1:]
    total = 0
    fns = (vocab,) if pre[:1] == ['vocab'] else (part1, part2, part3)
    if pre[:1] == ['vocab']:
        pre = pre[1:]
    for fn in fns:
        name, n, of, missing, errs, warns = fn(pre)
        print(f'== {name}: {n} checked of {of} · {len(errs)} errors · {len(warns)} warnings · {len(missing)} without file')
        for e in errs:
            print('  ERROR', e)
        if name == 'vocab' and missing:
            print('  missing', missing[:40], '...' if len(missing) > 40 else '')
        for w in warns:
            print('  warn ', w)
        total += len(errs)
    sys.exit(1 if total else 0)
