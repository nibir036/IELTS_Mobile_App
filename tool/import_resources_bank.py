"""Build assets/content/resources_bank.json from the Resources HTML sources.

usage: python3 tool/import_resources_bank.py
Sources (seed/sources/resources/):
  vocab/vocab_bank_*.html          IELTS vocabulary bank (word, IPA, POS, definition, 2 examples, synonyms,
                                    register, band)
  idioms/idioms_*.html              idiom · meaning · example
  phrasal_verbs/phrasal_verbs_*.html phrasal verb · meaning · example
  irregular_verbs.html              base · past · participle · meaning · example
  academic_words/awl_01_connecting_words.html   connectors grouped by function (use note, example, register)
  academic_words/awl_02…07_*.html   academic words (POS, definition, example, word family)
  topic_vocab/topic_vocab_NN_*.html  23 IELTS topic sets (term, meaning/usage, example collocation)
Text is copied as is (HTML entities unescaped, <b> kept as **bold** in examples).
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'seed' / 'sources' / 'resources'
OUT = ROOT / 'assets' / 'content' / 'resources_bank.json'


def txt(s, bold=False):
    s = s or ''
    if bold:
        s = re.sub(r'</?b>', '**', s)
    s = re.sub(r'<[^>]+>', '', s)
    s = html.unescape(s).replace(' ', ' ')
    return re.sub(r'\s+', ' ', s).strip()


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')


def span(card, cls):
    m = re.search(rf'<(?:span|div|p)[^>]*class="{cls}"[^>]*>(.*?)</(?:span|div|p)>', card, re.S)
    return m.group(1) if m else ''


def cards(s):
    """Each <div class="card">…</div> block (cards are not nested)."""
    starts = [m.start() for m in re.finditer(r'<div class="card"', s)]
    ends = starts[1:] + [len(s)]
    return [s[a:b] for a, b in zip(starts, ends)]


def rows(s):
    body = s.split('<tbody', 1)[-1]
    return [re.findall(r'<td[^>]*class="([^"]*)"[^>]*>(.*?)</td>', r, re.S)
            for r in re.findall(r'<tr>(.*?)</tr>', body, re.S)]


def vocab():
    out, seen = [], set()
    for f in sorted((SRC / 'vocab').glob('vocab_bank_*.html')):
        for c in cards(f.read_text(encoding='utf-8')):
            w = txt(span(c, 'w'))
            if not w:
                continue
            exs = [txt(x, bold=True) for x in re.findall(r'<div class="ex">(.*?)</div>', c, re.S)]
            syn = txt(span(c, 'syn')).removeprefix('Syn:').strip()
            band = txt(span(c, 'band')).removeprefix('Band').strip()
            key = (w.lower(), txt(span(c, 'pos')))
            if key in seen:
                continue
            seen.add(key)
            out.append({
                'id': f'vb_{slug(w)}' + ('' if not any(o['id'] == f'vb_{slug(w)}' for o in out) else f'_{len(out)}'),
                'word': w, 'ipa': txt(span(c, 'ipa')), 'pos': txt(span(c, 'pos')),
                'definition': txt(span(c, 'def')), 'examples': exs,
                'synonyms': [x.strip() for x in syn.split(',') if x.strip()],
                'register': txt(span(c, 'tag')), 'band': float(band) if re.fullmatch(r'[\d.]+', band) else None,
            })
    return out


def phrases(folder, prefix):
    out, seen = [], set()
    for f in sorted((SRC / folder).glob('*.html')):
        for r in rows(f.read_text(encoding='utf-8')):
            d = {cls.split()[0]: v for cls, v in r}
            p, m = txt(d.get('pv')), txt(d.get('mean'))
            if not p or not m:
                continue
            key = (p.lower(), m.lower())
            if key in seen:
                continue
            seen.add(key)
            base = f'{prefix}_{slug(p)}'
            n = sum(1 for o in out if o['id'] == base or o['id'].startswith(base + '_'))
            out.append({'id': base if n == 0 else f'{base}_{n + 1}', 'phrase': p, 'meaning': m,
                        'example': txt(d.get('ex'), bold=True)})
    return out


def irregular():
    out = []
    for r in rows((SRC / 'irregular_verbs.html').read_text(encoding='utf-8')):
        cells = [txt(v, bold=(cls == 'ex')) for cls, v in r]
        if len(cells) < 5 or not cells[0]:
            continue
        out.append({'base': cells[0], 'past': cells[1], 'participle': cells[2], 'meaning': cells[3],
                    'example': cells[4]})
    return out


def connectors():
    s = (SRC / 'academic_words' / 'awl_01_connecting_words.html').read_text(encoding='utf-8')
    groups, cur = [], None
    for m in re.finditer(r'<h2 class="lh">(.*?)</h2>\s*(?:<p class="lhx">(.*?)</p>)?|<div class="card"(.*?)</div></div>', s, re.S):
        if m.group(1) is not None:
            title = re.sub(r'^\d+\s*·\s*', '', txt(m.group(1)))
            cur = {'id': f'cn_{slug(title)}', 'title': title, 'note': txt(m.group(2)), 'items': []}
            groups.append(cur)
        elif cur is not None:
            c = m.group(0)
            w = txt(span(c, 'w'))
            if w:
                cur['items'].append({'id': f'cn_{slug(w)}', 'word': w, 'use': txt(span(c, 'use')),
                                     'example': txt(span(c, 'ex'), bold=True), 'function': txt(span(c, 'tag')),
                                     'register': txt(span(c, 'reg'))})
    return groups


def academic():
    out = []
    for f in sorted((SRC / 'academic_words').glob('awl_0[2-7]_*.html')):
        part = int(f.name[4:6])
        for c in cards(f.read_text(encoding='utf-8')):
            w = txt(span(c, 'w'))
            if not w:
                continue
            fam = txt(span(c, 'fam')).removeprefix('Family:').strip()
            out.append({'id': f'aw_{slug(w)}', 'word': w, 'pos': txt(span(c, 'pos')), 'definition': txt(span(c, 'def')),
                        'example': txt(span(c, 'ex'), bold=True),
                        'family': [x.strip() for x in fam.split(',') if x.strip()],
                        'list': 'extended' if part == 7 else 'core'})
    return out


def topics():
    out = []
    for f in sorted((SRC / 'topic_vocab').glob('topic_vocab_*.html')):
        s = f.read_text(encoding='utf-8')
        title = re.sub(r'^Topic Vocabulary\s*[—-]\s*', '', txt(re.search(r'<h1>(.*?)</h1>', s, re.S).group(1)))
        key = re.match(r'topic_vocab_\d+_(.+)\.html', f.name).group(1)
        items, seen = [], set()
        for r in rows(s):
            d = {cls.split()[0]: v for cls, v in r}
            term, mean = txt(d.get('pv')), txt(d.get('mean'))
            if not term or not mean or term.lower() in seen:
                continue
            seen.add(term.lower())
            items.append({'id': f'tv_{key}_{slug(term)}', 'term': term, 'meaning': mean,
                          'example': txt(d.get('ex'), bold=True)})
        out.append({'id': f'tv_{key}', 'title': title, 'items': items})
    return out


def main():
    data = {
        'vocab': vocab(),
        'idioms': phrases('idioms', 'id'),
        'phrasalVerbs': phrases('phrasal_verbs', 'pv'),
        'irregularVerbs': irregular(),
        'connectors': connectors(),
        'academicWords': academic(),
        'topics': topics(),
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print({k: (sum(len(g['items']) for g in v) if k in ('connectors', 'topics') else len(v)) for k, v in data.items()},
          f'→ {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)')


if __name__ == '__main__':
    main()
