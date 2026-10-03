"""Check a study guide's chapters: seed/staging/<guide>/{<lang>,en}/<file>.json (same block layout).

usage: python3 tool/check_writing_guide.py [--guide speaking_guide] [--lang ne] [file ...]
(default guide: writing_guide, default lang: bn, default files: all in <lang>/; with --lang other than bn,
also checks tips_<lang>.json against tips_en.json when it exists)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'seed' / 'staging' / 'writing_guide'
if len(sys.argv) > 2 and sys.argv[1] == '--guide':
    BASE = ROOT / 'seed' / 'staging' / sys.argv[2]
    del sys.argv[1:3]
LANG = 'bn'
if len(sys.argv) > 2 and sys.argv[1] == '--lang':
    LANG = sys.argv[2]
    del sys.argv[1:3]
KINDS = {'h', 'h2', 'p', 'ul', 'ol', 'tip', 'note', 'ex', 'model', 'table', 'img', 'box', 'pair', 'exercise'}
BOX_KINDS = {'regional', 'l1', 'impact'}
BN = re.compile(r'[ঀ-৿]')
SCRIPT = {'bn': BN, 'ne': re.compile(r'[ऀ-ॿ]'), 'ar': re.compile(r'[؀-ۿ]'),
          # Indonesian: Latin script; look for common function words instead
          'id': re.compile(r'\b(yang|dan|untuk|dengan|tidak|ini|itu|Anda|adalah|dalam)\b')}
TARGET = SCRIPT.get(LANG, BN)


def shape(b):
    k = b[0]
    if k in ('ul', 'ol'):
        return (k, len(b[1]))
    if k == 'table':
        return (k, len(b[1]), len(b[2]))
    if k == 'img':
        return (k, b[1])
    if k == 'box':
        return (k, b[1], len(b[4]))
    if k == 'exercise':
        return (k, b[1].get('kind'), len(b[1].get('items', [])))
    return (k,)


def check_blocks(where, blocks, errs):
    for i, b in enumerate(blocks):
        w = f'{where}[{i}]'
        if not isinstance(b, list) or not b or b[0] not in KINDS:
            errs.append(f'{w}: bad block {str(b)[:60]}')
            continue
        k = b[0]
        if k in ('ul', 'ol'):
            if len(b) != 2 or not isinstance(b[1], list) or not all(isinstance(x, str) and x.strip() for x in b[1]):
                errs.append(f'{w}: {k} needs ["{k}", [non-empty strings]]')
        elif k == 'box':
            if len(b) != 5 or b[1] not in BOX_KINDS or not str(b[3]).strip() or not isinstance(b[4], list):
                errs.append(f'{w}: box needs ["box", kind, title, body, [items]]')
        elif k == 'pair':
            if len(b) != 4 or not all(isinstance(x, str) for x in b[1:]) or not b[1].strip() or not b[2].strip():
                errs.append(f'{w}: pair needs ["pair", incorrect, correct, why]')
        elif k == 'exercise':
            e = b[1] if len(b) == 2 and isinstance(b[1], dict) else {}
            if not e.get('title') or not e.get('instructions') or not e.get('items'):
                errs.append(f'{w}: exercise needs title, instructions, items')
            for j, it in enumerate(e.get('items', [])):
                if not str(it.get('prompt', '')).strip() or not str(it.get('answer', '')).strip():
                    errs.append(f'{w} item {j + 1}: needs prompt and answer')
        elif k == 'table':
            if len(b) not in (3, 4) or not isinstance(b[1], list) or not isinstance(b[2], list):
                errs.append(f'{w}: table needs ["table", [cols], [[cells]]]')
                continue
            for r in b[2]:
                if not isinstance(r, list) or len(r) != len(b[1]):
                    errs.append(f'{w}: table row length {len(r) if isinstance(r, list) else "?"} != {len(b[1])}')
        elif k == 'img':
            if len(b) != 3 or not (ROOT / b[1]).exists():
                errs.append(f'{w}: image missing {b[1:2]}')
        else:
            if len(b) != 2 or not isinstance(b[1], str) or not b[1].strip():
                errs.append(f'{w}: {k} needs non-empty text')


def main():
    names = sys.argv[1:] or [p.name for p in sorted((BASE / ('bn' if LANG == 'bn' else 'en')).glob('*.json'))]
    if LANG != 'bn':  # every chapter file Bangla has must exist in this language
        names = [n for n in names if (BASE / 'bn' / Path(n).name).exists()]
    errs, warns, total = [], [], 0
    for name in names:
        name = Path(name).name
        if not (BASE / LANG / name).exists():
            errs.append(f'{LANG}/{name}: missing')
            continue
        bn = json.loads((BASE / LANG / name).read_text(encoding='utf-8'))
        enf = BASE / 'en' / name
        en = json.loads(enf.read_text(encoding='utf-8')) if enf.exists() else None
        if en is None:
            errs.append(f'en/{name}: missing')
        for lang, chs in ((LANG, bn), ('en', en or [])):
            for c in chs:
                if not c.get('id') or not c.get('title') or not isinstance(c.get('blocks'), list):
                    errs.append(f'{lang}/{name}: chapter needs id, title, blocks')
                    continue
                check_blocks(f'{lang}/{c["id"]}', c['blocks'], errs)
        bn_ref = {}
        if LANG != 'bn' and (BASE / 'bn' / name).exists():
            bn_ref = {c.get('id'): c for c in json.loads((BASE / 'bn' / name).read_text(encoding='utf-8'))}
        if en is not None:
            if [c.get('id') for c in bn] != [c.get('id') for c in en]:
                errs.append(f'{name}: chapter ids differ {LANG} vs en')
            for a, b in zip(bn, en):
                sa = [shape(x) for x in a.get('blocks', [])]
                sb = [shape(x) for x in b.get('blocks', [])]
                if sa != sb:
                    for i, (x, y) in enumerate(zip(sa, sb)):
                        if x != y:
                            errs.append(f'{name}/{a.get("id")}: block {i} differs {LANG} {x} vs en {y}')
                            break
                    else:
                        errs.append(f'{name}/{a.get("id")}: {len(sa)} {LANG} blocks vs {len(sb)} en blocks')
                for i, (x, y) in enumerate(zip(a.get('blocks', []), b.get('blocks', []))):
                    if x[0] == 'exercise' and y[0] == 'exercise':
                        for j, (p, q) in enumerate(zip(x[1]['items'], y[1]['items'])):
                            if (p['prompt'], p['answer'], p.get('accepted')) != (q['prompt'], q['answer'], q.get('accepted')):
                                errs.append(f'{name}/{a.get("id")}[{i}] item {j + 1}: prompt/answer must stay identical')
                if LANG == 'bn':
                    for i, blk in enumerate(b.get('blocks', [])):
                        txt = json.dumps(blk, ensure_ascii=False)
                        if BN.search(txt) and blk[0] not in ('img',):
                            warns.append(f'en/{b.get("id")}[{i}]: Bangla left in English version')
                if not TARGET.search(a.get('title', '')) and LANG != 'id':
                    warns.append(f'{LANG}/{a.get("id")}: title not translated?')
                if not any(TARGET.search(json.dumps(x, ensure_ascii=False)) for x in a.get('blocks', [])):
                    (warns if LANG == 'bn' else errs).append(f'{LANG}/{a.get("id")}: no {LANG} text at all')
                # A block Bangla translated must not be left as the English original.
                ref = bn_ref.get(a.get('id'), {}).get('blocks', [])
                for i, (x, y) in enumerate(zip(a.get('blocks', []), b.get('blocks', []))):
                    if x == y and x[0] not in ('img', 'model', 'ex') and i < len(ref) and ref[i] != y:
                        (errs if LANG != 'bn' else warns).append(
                            f'{name}/{a.get("id")}[{i}]: {x[0]} left in English (Bangla translated it)')
        total += sum(len(c.get('blocks', [])) for c in bn)
    tips_src = BASE / 'tips_en.json'
    tips_dst = BASE / f'tips_{LANG}.json'
    if LANG != 'bn' and tips_src.exists() and tips_dst.exists() and not sys.argv[1:]:
        src = json.loads(tips_src.read_text(encoding='utf-8'))
        dst = {a.get('id'): a for a in json.loads(tips_dst.read_text(encoding='utf-8'))}
        for a in src:
            d = dst.get(a['id'])
            if not d:
                errs.append(f'tips_{LANG}: {a["id"]} missing')
                continue
            if len(d.get('tips', [])) != len(a['tips']):
                errs.append(f'tips_{LANG}: {a["id"]} tip count differs')
            for k, t in enumerate(d.get('tips', [])):
                if not str(t.get('title', '')).strip() or not str(t.get('body', '')).strip():
                    errs.append(f'tips_{LANG}: {a["id"]} tip {k + 1} empty')
                elif t.get('body') == a['tips'][k]['body'] if k < len(a['tips']) else False:
                    errs.append(f'tips_{LANG}: {a["id"]} tip {k + 1} left in English')
            if not TARGET.search(json.dumps(d, ensure_ascii=False)):
                errs.append(f'tips_{LANG}: {a["id"]} not in {LANG}')
    print(f'{len(names)} file(s) · {total} {LANG} blocks · {len(errs)} errors · {len(warns)} warnings')
    for e in errs[:60]:
        print('  ERROR', e)
    for w in warns[:30]:
        print('  warn ', w)
    sys.exit(1 if errs else 0)


if __name__ == '__main__':
    main()
