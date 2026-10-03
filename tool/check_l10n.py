"""Check translated reading content (seed/staging/l10n/reading/<lang>/).

usage: python3 tool/check_l10n.py <lang> [chunk ...]      e.g.  python3 tool/check_l10n.py bn 03
Checks: every passage / question / type lesson is covered; texts are in the target script;
English quotes from the source ("…") survive unchanged; nothing is left identical to the source.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'seed' / 'staging' / 'l10n' / 'reading'
SCRIPT = {'bn': r'[ঀ-৿]', 'ne': r'[ऀ-ॿ]', 'ar': r'[؀-ۿ]', 'id': r'[A-Za-z]'}
QUOTE = re.compile(r'"([^"]{3,})"')


def script_ok(lang, text, least=8):
    if lang == 'id':
        return True
    return len(re.findall(SCRIPT[lang], text)) >= least


def check_text(lang, where, src, dst, errs, warns):
    if not isinstance(dst, str) or not dst.strip():
        errs.append(f'{where}: empty')
        return
    if dst.strip() == src.strip():
        errs.append(f'{where}: same as English')
        return
    if not script_ok(lang, dst, 3 if where.endswith('.title') else 8):
        errs.append(f'{where}: not in {lang} script')
    for q in QUOTE.findall(src):
        if q not in dst:
            warns.append(f'{where}: quote changed or missing "{q[:40]}"')
    if '—' in dst and '—' not in src and lang != 'bn':
        pass


def _shape(b):
    k = b[0]
    if k in ('ul', 'ol'):
        return (k, len(b[1]))
    if k == 'table':
        return (k, len(b[1]), len(b[2]))
    return (k,)


def check_extra(lang, src_dir, dst_dir, only, errs, warns):
    """library_passages / skill_lessons / tips / guide (each optional until translated)."""
    if only and 'extra' not in only:
        return 0
    n = 0

    def load(name):
        f = dst_dir / name
        if not f.exists():
            warns.append(f'{name}: not translated yet')
            return None
        return {x['id']: x for x in json.loads(f.read_text(encoding='utf-8'))}

    def src(name):
        return json.loads((src_dir / name).read_text(encoding='utf-8'))

    def text(where, a, b):
        nonlocal n
        n += 1
        check_text(lang, where, a, b, errs, warns)

    dst = load('library_passages.json')
    if dst is not None:
        for p in src('library_passages.json'):
            ex = (dst.get(p['id']) or {}).get('explanations', {})
            for q in p['questions']:
                text(f"{p['id']}.q{q['n']}", q['explanation'], ex.get(str(q['n'])))
    dst = load('skill_lessons.json')
    if dst is not None:
        for l in src('skill_lessons.json'):
            d = dst.get(l['id']) or {}
            text(f"{l['id']}.title", l['title'], d.get('title'))
            text(f"{l['id']}.keyIdea", l['keyIdea'], d.get('keyIdea'))
            if l['keyIdea'].count('**') != (d.get('keyIdea') or '').count('**'):
                errs.append(f"{l['id']}.keyIdea: ** markers differ")
            if len(d.get('uses', [])) != len(l['uses']):
                errs.append(f"{l['id']}.uses: count differs")
    dst = load('tips.json')
    if dst is not None:
        for a in src('tips.json'):
            d = dst.get(a['id']) or {}
            text(f"{a['id']}.title", a['title'], d.get('title'))
            if len(d.get('tips', [])) != len(a['tips']):
                errs.append(f"{a['id']}.tips: count differs")
                continue
            for i, (s, t) in enumerate(zip(a['tips'], d['tips'])):
                text(f"{a['id']}.t{i}.title", s['title'], t.get('title'))
                text(f"{a['id']}.t{i}.body", s['body'], t.get('body'))
    dst = load('guide.json')
    if dst is not None and (src_dir / 'guide.json').exists():
        for c in src('guide.json'):
            d = dst.get(c['id'])
            if not d:
                errs.append(f"guide.{c['id']}: missing")
                continue
            text(f"guide.{c['id']}.title", c['title'], d.get('title'))
            if [_shape(b) for b in c['blocks']] != [_shape(b) for b in d.get('blocks', [])]:
                errs.append(f"guide.{c['id']}: block structure differs from English")
    return n


def main():
    lang = sys.argv[1]
    only = sys.argv[2:]
    errs, warns = [], []
    src_dir, dst_dir = BASE / 'src', BASE / lang
    n_p = n_q = 0
    for f in sorted(src_dir.glob('passages_*.json')):
        chunk = f.stem.split('_')[1]
        if only and chunk not in only:
            continue
        out = dst_dir / f'passages_{chunk}.json'
        if not out.exists():
            errs.append(f'{out.name}: missing')
            continue
        dst = {x['id']: x for x in json.loads(out.read_text(encoding='utf-8'))}
        for p in json.loads(f.read_text(encoding='utf-8')):
            d = dst.get(p['id'])
            if not d:
                errs.append(f"{p['id']}: missing")
                continue
            n_p += 1
            for k in ('title', 'text'):
                check_text(lang, f"{p['id']}.lesson.{k}", p['lesson'][k], d.get('lesson', {}).get(k), errs, warns)
            if p['lesson'].get('example'):
                check_text(lang, f"{p['id']}.lesson.example", p['lesson']['example'],
                           d.get('lesson', {}).get('example'), errs, warns)
            ex = d.get('explanations', {})
            for q in p['questions']:
                n_q += 1
                check_text(lang, f"{p['id']}.q{q['n']}", q['explanation'], ex.get(str(q['n'])), errs, warns)
    if not only or 'lessons' in only:
        tl = dst_dir / 'type_lessons.json'
        if tl.exists():
            dst = {x['id']: x for x in json.loads(tl.read_text(encoding='utf-8'))}
            for l in json.loads((src_dir / 'type_lessons.json').read_text(encoding='utf-8')):
                d = dst.get(l['id'])
                if not d:
                    errs.append(f"{l['id']}: missing")
                    continue
                check_text(lang, f"{l['id']}.title", l['title'], d.get('title'), errs, warns)
                if len(d.get('sections', [])) != len(l['sections']):
                    errs.append(f"{l['id']}: {len(d.get('sections', []))} sections, need {len(l['sections'])}")
                    continue
                for i, (s, t) in enumerate(zip(l['sections'], d['sections'])):
                    check_text(lang, f"{l['id']}.s{i}.heading", s['heading'], t.get('heading'), errs, warns)
                    check_text(lang, f"{l['id']}.s{i}.text", s['text'], t.get('text'), errs, warns)
        elif not only:
            errs.append('type_lessons.json: missing')
    n_x = check_extra(lang, src_dir, dst_dir, only, errs, warns)
    print(f'{lang}: {n_x} extra texts (library, skill lessons, tips, guide) · {n_p} passages · {n_q} explanations checked · {len(errs)} errors · {len(warns)} warnings')
    for e in errs[:80]:
        print('  ERROR', e)
    for w in warns[:40]:
        print('  warn ', w)
    sys.exit(1 if errs else 0)


if __name__ == '__main__':
    main()
