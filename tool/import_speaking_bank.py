"""Build assets/content/speaking_bank.json from sir's speaking files + staging.

Sources:
  seed/sources/speaking/*.html              sir's Part 1 / 2 / 3 banks (parsed by speaking_source.py)
  seed/staging/speaking/part1/<id>.json     Part 1 topic sets (5 questions, sir's originals kept)
  seed/staging/speaking/part2/<id>.json     extended Part 2 answers, follow-ups, Part 3 links
  seed/staging/speaking/part3/<id>.json     Part 3 vocabulary-mark fixes
  seed/staging/speaking/vocab/entries_*.json  vocabulary dictionary
  seed/staging/speaking/guide_extras.json   new items from sir's Speaking guide (7 cue cards, 3 Part 1 topics)

Also writes seed/audio/speaking_audio_manifest.json (one entry per sample answer, for TTS).
usage: python3 tool/import_speaking_bank.py
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import speaking_source as src  # noqa: E402

ROOT = src.ROOT
ST = ROOT / 'seed' / 'staging' / 'speaking'
OUT = ROOT / 'assets' / 'content' / 'speaking_bank.json'
AUDIO = ROOT / 'seed' / 'audio' / 'speaking_audio_manifest.json'

P3_PICK = ['opinion', 'comparison', 'cause-effect', 'future', 'problem-solution']


def jload(p):
    return json.loads(Path(p).read_text(encoding='utf-8'))


def plain(s):
    return s.replace('[[', '').replace(']]', '')


def words(s):
    return len(re.findall(r"[A-Za-z0-9'’-]+", plain(s)))


def keys(s):
    return [m.lower() for m in src.marks(s)]


GUIDE_HTML = ROOT / 'seed' / 'sources' / 'guides' / 'IELTS_Speaking_Guide_book_full.html'


def guide_extras():
    """Cue cards and Part 1 topics from sir's Speaking guide that the bank lacks (list in guide_extras.json).
    Returns (cards, part1) in a simple form; text is copied from the guide as is."""
    cfg_path = ST / 'guide_extras.json'
    if not cfg_path.exists() or not GUIDE_HTML.exists():
        return [], []
    from bs4 import BeautifulSoup
    cfg = jload(cfg_path)
    soup = BeautifulSoup(GUIDE_HTML.read_text(encoding='utf-8'), 'html.parser')

    def txt(el):
        return re.sub(r'\s+', ' ', el.get_text(' ')).strip()

    cards = []
    for want in cfg['cards']:
        box = next(c for c in soup.find_all(class_='card')
                   if c.find(class_='ct') and txt(c.find(class_='ct')) == want['title'])
        say = [re.sub(r'\s+', ' ', x).strip() for x in box.find('p').get_text('\n').split('\n')]
        bullets = [x for x in say if x and not x.lower().startswith('you should say')]
        notes = box.find_next_sibling(class_='notes')
        model = box.find_next_sibling(class_='ex')
        vocab = box.find_next_sibling(class_='vocab')
        p3 = box.find_next_sibling(class_='p3')
        cards.append({
            **want,
            'prompt': want['title'].rstrip('.'),
            'bullets': bullets,
            'notes': [x.strip() for x in notes.get_text('\n').split('\n') if x.strip()] if notes else [],
            'answer': ' '.join(txt(p) for p in model.find_all('p')),
            'phrases': [x.strip() for x in txt(vocab).replace('Vocabulary:', '').split('•') if x.strip()] if vocab else [],
            'guidePart3': [x.strip() for x in txt(p3).replace('Part 3:', '').split('•') if x.strip()] if p3 else [],
        })
    part1 = []
    for want in cfg['part1']:
        h = next(h for h in soup.find_all('h2') if want['heading'] in txt(h))
        qa = h.find_next_sibling(class_='qa')
        qs = [re.sub(r'[★\s]+$', '', txt(p))[2:].strip() for p in qa.find_all('p', class_='q')]
        ans = [txt(p)[2:].strip() for p in qa.find_all('p', class_='a')]
        part1.append({**want, 'qa': list(zip(qs, ans))})
    return cards, part1


def build():
    base_sets = {s['id']: s for s in jload(ST / 'base' / 'part1_sets.json')}
    vocab = {}
    for f in sorted((ST / 'vocab').glob('entries_*.json')):
        for e in jload(f):
            k = e['key']
            vocab[k] = {
                'headword': e['headword'], 'pos': e['pos'], 'ipa': e['ipa'],
                'syllables': e.get('syllables', []), 'meaning': e['meaning'],
                'example': e['example'], 'synonyms': e['synonyms'], 'level': e['level'],
            }
    audio = []
    missing_vocab = set()

    def need(s):
        for k in keys(s):
            if k not in vocab:
                missing_vocab.add(k)

    # ── Part 3 (needed for card links) ─────────────────────────────────────
    part3 = []
    for t in src.part3():
        fx_path = ST / 'part3' / f"{t['id']}.json"
        fixes = {x['n']: x['answer'] for x in jload(fx_path)['fixes']} if fx_path.exists() else {}
        qs = []
        for q in t['questions']:
            a = fixes.get(q['n'], q['answer'])
            need(a)
            qs.append({'q': q['q'], 'tag': q['tag'], 'tagLabel': q['tagLabel'], 'answer': a,
                       'words': words(a), 'edited': q['n'] in fixes})
            audio.append({'file': f"{t['id']}_q{q['n']}.mp3", 'part': 3, 'ref': t['id'],
                          'q': q['q'], 'text': plain(a)})
        part3.append({'id': t['id'], 'bank': True, 'number': t['number'], 'category': t['category'],
                      'categoryLabel': t['categoryLabel'], 'topic': t['topic'],
                      'description': t.get('description', ''), 'questions': qs})
    p3 = {t['id']: t for t in part3}

    # ── Part 1 ─────────────────────────────────────────────────────────────
    part1 = []
    for sid, s in base_sets.items():
        d = jload(ST / 'part1' / f'{sid}.json')
        samples = []
        for i, q in enumerate(d['questions'], 1):
            need(q['answer'])
            samples.append({'q': q['q'], 'answer': q['answer'], 'source': q.get('source'),
                            'words': words(q['answer'])})
            audio.append({'file': f'{sid}_q{i}.mp3', 'part': 1, 'ref': sid, 'q': q['q'],
                          'text': plain(q['answer'])})
        part1.append({'id': sid, 'bank': True, 'topic': s['topic'], 'category': s['category'],
                      'categoryLabel': s['categoryLabel'], 'intro': s['intro'],
                      'questions': [x['q'] for x in samples], 'samples': samples})

    g_cards, g_part1 = guide_extras()
    labels = {s['category']: s['categoryLabel'] for s in base_sets.values()}
    for g in g_part1:
        samples = []
        for i, (q, a) in enumerate(g['qa'], 1):
            samples.append({'q': q, 'answer': a, 'source': 'guide', 'words': words(a)})
            audio.append({'file': f"{g['id']}_q{i}.mp3", 'part': 1, 'ref': g['id'], 'q': q, 'text': a})
        part1.append({'id': g['id'], 'bank': True, 'topic': g['topic'], 'category': g['category'],
                      'categoryLabel': labels[g['category']], 'intro': False, 'source': 'guide',
                      'questions': [x['q'] for x in samples], 'samples': samples})

    # ── Part 2 ─────────────────────────────────────────────────────────────
    cards = []
    for n, c in enumerate(src.part2(), 1):
        d = jload(ST / 'part2' / f"{c['id']}.json")
        need(d['answer'])
        for x in d['followUps']:
            need(x['answer'])
        links = d['part3']
        prim = p3[links[0]]['questions']
        chosen = [q for tag in P3_PICK for q in prim if q['tag'] == tag][:5]
        for q in prim:
            if len(chosen) >= 5:
                break
            if q not in chosen:
                chosen.append(q)
        if len(links) > 1:
            sec = p3[links[1]]['questions']
            extra = next((q for q in sec if q['tag'] == 'agree-disagree'), sec[0])
            chosen.append(extra)
        cards.append({
            'id': c['id'], 'bank': True, 'number': n, 'cardNumber': c['number'],
            'category': c['category'], 'categoryLabel': c['categoryLabel'], 'topic': c['categoryLabel'],
            'title': c['title'], 'prompt': c['title'], 'bullets': c['bullets'],
            'sample': {'answer': d['answer'], 'words': words(d['answer']),
                       'seconds': round(words(d['answer']) / 140 * 60)},
            'followUps': d['followUps'],
            'part3Topics': links,
            'part3': [q['q'] for q in chosen],
            'part3Samples': chosen,
        })
        audio.append({'file': f"{c['id']}.mp3", 'part': 2, 'ref': c['id'], 'q': c['title'],
                      'text': plain(d['answer'])})
        for i, x in enumerate(d['followUps'], 1):
            audio.append({'file': f"{c['id']}_f{i}.mp3", 'part': 2, 'ref': c['id'], 'q': x['q'],
                          'text': plain(x['answer'])})

    cat_labels = {c['category']: c['categoryLabel'] for c in cards}
    per_cat = {}
    for c in cards:
        per_cat[c['category']] = max(per_cat.get(c['category'], 0), c['cardNumber'])
    for g in g_cards:
        prim = p3[g['part3'][0]]['questions']
        chosen = [q for tag in P3_PICK for q in prim if q['tag'] == tag][:5]
        sec = p3[g['part3'][1]]['questions']
        chosen.append(next((q for q in sec if q['tag'] == 'agree-disagree'), sec[0]))
        per_cat[g['category']] += 1
        cid = f"sp2_{g['category']}_{per_cat[g['category']]:02d}"
        cards.append({
            'id': cid, 'bank': True, 'number': len(cards) + 1, 'cardNumber': per_cat[g['category']],
            'category': g['category'], 'categoryLabel': cat_labels[g['category']],
            'topic': cat_labels[g['category']], 'title': g['prompt'], 'prompt': g['prompt'],
            'bullets': g['bullets'], 'source': 'guide',
            'sample': {'answer': g['answer'], 'words': words(g['answer']),
                       'seconds': round(words(g['answer']) / 140 * 60)},
            'notes': g['notes'], 'phrases': g['phrases'],
            'followUps': [],
            'part3Topics': g['part3'],
            'part3': g['guidePart3'] + [q['q'] for q in chosen][:2],
            'part3Samples': chosen,
        })
        audio.append({'file': f'{cid}.mp3', 'part': 2, 'ref': cid, 'q': g['prompt'], 'text': g['answer']})

    if missing_vocab:
        raise SystemExit(f'vocab entries missing for: {sorted(missing_vocab)[:20]}')

    used = set()
    for t in part1:
        for x in t['samples']:
            used.update(keys(x['answer']))
    for c in cards:
        used.update(keys(c['sample']['answer']))
        for x in c['followUps']:
            used.update(keys(x['answer']))
    for t in part3:
        for q in t['questions']:
            used.update(keys(q['answer']))
    vocab = {k: v for k, v in sorted(vocab.items()) if k in used}

    def cats(items):
        seen = {}
        for x in items:
            seen.setdefault(x['category'], x['categoryLabel'])
        return [{'id': k, 'label': v} for k, v in seen.items()]

    meta = {
        'title': 'IELTS Speaking question bank',
        'counts': {
            'part1Topics': len(part1), 'part1Questions': sum(len(t['samples']) for t in part1),
            'part2Cards': len(cards), 'part3Topics': len(part3),
            'part3Questions': sum(len(t['questions']) for t in part3),
            'vocab': len(vocab), 'headwords': len({v['headword'].lower() for v in vocab.values()}),
        },
        'part1Categories': cats(part1), 'part2Categories': cats(cards), 'part3Categories': cats(part3),
        'part3Tags': [{'id': v, 'label': k} for k, v in src.TAGS.items()],
        'sampleNote': 'Sample answers are written by one speaker (a young professional from Sirajganj). '
                      'Use them for ideas, structure and vocabulary, then answer with your own experience.',
        'bands': {'part1': 'Band 7.5–8', 'part2': 'Band 7.5–8', 'part3': 'Band 8+'},
        'audio': {'status': 'pending', 'folder': 'assets/audio/speaking/'},
    }
    bank = {'meta': meta, 'part1Topics': part1, 'cueCards': cards, 'part3Topics': part3, 'vocab': vocab}
    OUT.write_text(json.dumps(bank, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    AUDIO.parent.mkdir(parents=True, exist_ok=True)
    AUDIO.write_text(json.dumps({'folder': 'assets/audio/speaking/', 'count': len(audio),
                                 'items': audio}, ensure_ascii=False, indent=1), encoding='utf-8')
    c = meta['counts']
    print(f"part1 {c['part1Topics']} topics / {c['part1Questions']} qs · part2 {c['part2Cards']} cards · "
          f"part3 {c['part3Topics']} topics / {c['part3Questions']} qs · vocab {c['vocab']} "
          f"({c['headwords']} headwords) · audio items {len(audio)} · {OUT.stat().st_size // 1024} KB")


if __name__ == '__main__':
    build()
