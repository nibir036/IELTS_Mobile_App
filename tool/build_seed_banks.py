"""Builds the seed files for the app's content banks, full tests, guides and
translations: seed/data/50-71_*.json (+ seed/formats/ examples, manifest).

Source = the app's own content files (assets/content/*.json), so the database
holds exactly what the app shows. Each row has the table's columns (Prisma
field names) plus `data` = the app's record as-is (the content API returns it).

Run after any import that changes assets/content:
    python3 tool/build_seed_banks.py
then load with:  cd server && npm run db:seed

Group "bank" (50-71). Content ids are the app ids, so re-seeding updates rows.
"""
import copy
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(ROOT, 'assets', 'content')
OUT_D = os.path.join(ROOT, 'seed', 'data')
OUT_F = os.path.join(ROOT, 'seed', 'formats')


def load(name):
    with open(os.path.join(CONTENT, name), encoding='utf-8') as f:
        return json.load(f)


def r2_key(path):
    """assets/audio/listening/x.mp3 → listening/x.mp3 · assets/writing/… → writing/…"""
    if not path:
        return path
    return re.sub(r'^assets/(audio/)?', '', path)


def plain(text):
    """Drops the app's **bold** / [[highlight]] markers (for plain columns)."""
    return re.sub(r'\*\*|\[\[|\]\]', '', text or '')


def no_none(row):
    return {k: v for k, v in row.items() if v is not None}


def fields(items):
    out = {}
    for it in items:
        for k, v in it.items():
            t = {'str': 'string', 'dict': 'object', 'list': 'array', 'float': 'number', 'int': 'integer',
                 'bool': 'boolean', 'NoneType': 'null'}[type(v).__name__]
            out.setdefault(k, set()).add(t)
    return {k: '|'.join(sorted(v)) for k, v in out.items()}


MANIFEST = []


def emit(num, name, table, items, desc, source, key='id', notes=None):
    items = [no_none(i) for i in items]
    ids = [i.get(key) for i in items]
    assert len(ids) == len(set(ids)), f'duplicate {key} in {name}'
    fn = f'{num:02d}_{name}.json'
    with open(os.path.join(OUT_D, fn), 'w', encoding='utf-8') as f:
        json.dump({'table': table, 'items': items}, f, ensure_ascii=False, indent=1)
    sample = copy.deepcopy(items[:1])
    for s in sample:  # keep the example readable
        if isinstance(s.get('data'), dict) and len(json.dumps(s['data'])) > 4000:
            s['data'] = '… the app record (same keys as the source file) …'
    fmt = {'_format': {'name': name, 'group': 'bank', 'table': table, 'primaryKey': key,
                       'description': desc, 'currentSourceInApp': source, 'fields': fields(items),
                       'notes': notes or [], 'recordCountToday': len(items)},
           'items': sample}
    with open(os.path.join(OUT_F, fn), 'w', encoding='utf-8') as f:
        json.dump(fmt, f, ensure_ascii=False, indent=2)
    MANIFEST.append({'file': fn, 'group': 'bank', 'table': table, 'records': len(items), 'exported': True})
    print(f'  {fn:40s} {table:24s} {len(items)}')


def group_types(groups):
    out = []
    for g in groups:
        t = g.get('type')
        if t and t not in out:
            out.append(t)
    return out


def question_count(groups):
    n = 0
    for g in groups:
        pick = g.get('pick') or 1
        n += len(g.get('questions') or []) * (pick if pick > 1 else 1)
    return n


def main():
    lb = load('listening_bank.json')
    rb = load('reading_bank.json')  # bank passages are already in 27/28/29
    wb = load('writing_bank.json')
    sb = load('speaking_bank.json')
    res = load('resources_bank.json')
    tb = load('tests_bank.json')
    del rb

    # ── Listening ───────────────────────────────────────────────────────────
    emit(50, 'listening_bank_sets', 'listening_sets', [
        {'id': s['id'], 'source': 'bank', 'part': s['part'], 'title': s['title'], 'context': s.get('context'),
         'audio': s.get('audioKey') or r2_key(s.get('audio')), 'durationSeconds': int(s.get('durationSeconds') or 0),
         'speakers': s.get('speakers') or [], 'transcript': s.get('transcript') or [], 'groups': s['groups'],
         'data': s}
        for s in lb['sets']
    ], 'Listening question bank: 32 recordings, one question format each (lb_…).',
        'assets/content/listening_bank.json → sets',
        notes=['audio = R2 object key (audioKey); data.audio = the app asset path.'])

    lt = tb['listening']
    emit(51, 'listening_test_sets', 'listening_sets', [
        {'id': s['id'], 'source': 'test', 'testId': s['test'], 'part': s['part'], 'title': s['title'],
         'context': s.get('context'), 'audio': r2_key(s['audio']), 'durationSeconds': int(s['durationSeconds']),
         'speakers': s.get('speakers') or [], 'transcript': s.get('transcript') or [], 'groups': s['groups'],
         'data': s}
        for s in lt['sets']
    ], 'Parts 1-4 of Listening Tests 1-4 (lt_wNN_pK), 10 questions each, no transcript.',
        'assets/content/tests_bank.json → listening.sets')
    emit(52, 'listening_full_tests', 'listening_tests', [
        {'id': t['id'], 'kind': 'full', 'number': t['number'], 'title': t['title'], 'setIds': t['sets'], 'data': t}
        for t in lt['tests']
    ], 'Listening Test 1-4 (website tests 11-14).', 'assets/content/tests_bank.json → listening.tests')

    # ── Reading ─────────────────────────────────────────────────────────────
    rt = tb['reading']
    part_of = {pid: i + 1 for t in rt['tests'] for i, pid in enumerate(t['passages'])}
    emit(53, 'reading_test_passages', 'reading_passages', [
        {'id': p['id'], 'source': 'test', 'testId': p['test'], 'part': part_of[p['id']], 'title': p['title'],
         'topic': p['topic'], 'difficulty': p['difficulty'], 'words': p.get('words'), 'paragraphs': p['paragraphs'],
         'groups': p['groups'], 'questionCount': question_count(p['groups']), 'data': p}
        for p in rt['passages']
    ], 'Passages 1-3 of Academic Reading Tests 1-10 (rt_wNN_pK).', 'assets/content/tests_bank.json → reading.passages')
    passages = {p['id']: p for p in rt['passages']}
    emit(54, 'reading_full_tests', 'reading_tests', [
        {'id': t['id'], 'kind': 'full', 'number': t['number'], 'title': t['title'], 'passageIds': t['passages'],
         'questionTypes': group_types([g for pid in t['passages'] for g in passages[pid]['groups']]),
         'questionCount': sum(question_count(passages[pid]['groups']) for pid in t['passages']),
         'minutes': 60, 'data': t}
        for t in rt['tests']
    ], 'Academic Reading Test 1-10 (website tests 11-20).', 'assets/content/tests_bank.json → reading.tests')

    # ── Writing ─────────────────────────────────────────────────────────────
    def bank_prompt(p):
        rec = {k: v for k, v in p.items() if k != 'samples'}
        return {'id': p['id'], 'source': 'bank', 'task': p['task'], 'type': p['type'], 'topic': p.get('topic'),
                'title': p['title'], 'prompt': p['prompt'], 'chart': p.get('chart'),
                'modelAnswer': p.get('modelAnswer'), 'image': r2_key(p.get('image')), 'data': rec}
    bank = wb['task1'] + wb['task2']
    emit(55, 'writing_bank_prompts', 'writing_prompts', [bank_prompt(p) for p in bank],
         'Writing question bank: 140 Task 1 + 120 Task 2 questions (wb1_/wb2_…).',
         'assets/content/writing_bank.json → task1, task2',
         notes=['Band 6/7/8 samples are in 56_writing_bank_samples (writing_sample_answers).',
                'image = R2 key of the rendered Task 1 visual; chart = its data.'])
    emit(56, 'writing_bank_samples', 'writing_sample_answers', [
        {'promptId': p['id'], 'answers': p['samples']} for p in bank if p.get('samples')
    ], 'Band 6 / 7 / 8 sample answers of each bank question.', 'assets/content/writing_bank.json → *.samples',
        key='promptId')

    wt = tb['writing']
    emit(57, 'writing_test_prompts', 'writing_prompts', [
        {'id': p['id'], 'source': 'test', 'testId': p['test'], 'task': p['task'], 'type': p['type'],
         'title': p['title'], 'prompt': p['prompt'], 'image': r2_key(p.get('image')), 'data': p}
        for p in wt['prompts']
    ], 'Task 1 / Task 2 of Writing Tests 1-10 (wt_NN_t1 / _t2).', 'assets/content/tests_bank.json → writing.prompts')
    emit(58, 'writing_tests', 'writing_tests', [
        {'id': t['id'], 'number': t['number'], 'title': t['title'], 'task1Id': t['task1'], 'task2Id': t['task2'],
         'data': t}
        for t in wt['tests']
    ], 'Writing Test 1-10 (website tests 11-20).', 'assets/content/tests_bank.json → writing.tests')

    # ── Speaking ────────────────────────────────────────────────────────────
    def part1(t, source):
        return {'id': t['id'], 'source': source, 'testId': t.get('test'), 'category': t.get('category'),
                'topic': t['topic'], 'questions': t['questions'], 'data': t}

    def card(c, source):
        return {'id': c['id'], 'source': source, 'testId': c.get('test'), 'category': c.get('category'),
                'topic': c['topic'], 'title': c['title'], 'prompt': c['prompt'], 'bullets': c['bullets'],
                'part3': c.get('part3') or [], 'data': c}

    def part3(t, source):
        return {'id': t['id'], 'source': source, 'testId': t.get('test'), 'category': t.get('category'),
                'topic': t['topic'], 'theme': t.get('categoryLabel') or t['topic'],
                'questions': [q['q'] if isinstance(q, dict) else q for q in t['questions']], 'data': t}

    emit(59, 'speaking_bank_part1_topics', 'speaking_part1_topics', [part1(t, 'bank') for t in sb['part1Topics']],
         'Speaking bank Part 1 topics with Band 7+ sample answers.', 'assets/content/speaking_bank.json → part1Topics')
    emit(60, 'speaking_bank_cue_cards', 'speaking_cue_cards', [card(c, 'bank') for c in sb['cueCards']],
         'Speaking bank Part 2 cue cards (sample talk, follow-ups, Part 3 with samples).',
         'assets/content/speaking_bank.json → cueCards')
    emit(61, 'speaking_bank_part3_topics', 'speaking_part3_sets', [part3(t, 'bank') for t in sb['part3Topics']],
         'Speaking bank Part 3 discussion topics (questions with sample answers in data).',
         'assets/content/speaking_bank.json → part3Topics',
         notes=['questions = the question texts; data.questions = {q, tag, answer …}.'])

    st = tb['speaking']
    emit(62, 'speaking_test_part1_topics', 'speaking_part1_topics', [part1(t, 'test') for t in st['part1Topics']],
         'Part 1 of Speaking Tests 1-10 (3 topics merged, sections in data).',
         'assets/content/tests_bank.json → speaking.part1Topics')
    emit(63, 'speaking_test_cue_cards', 'speaking_cue_cards', [card(c, 'test') for c in st['cueCards']],
         'Part 2 cue cards of Speaking Tests 1-10.', 'assets/content/tests_bank.json → speaking.cueCards')
    emit(64, 'speaking_test_part3_topics', 'speaking_part3_sets', [part3(t, 'test') for t in st['part3Topics']],
         'Part 3 topics of Speaking Tests 1-10.', 'assets/content/tests_bank.json → speaking.part3Topics')
    emit(65, 'speaking_tests', 'speaking_tests', [
        {'id': t['id'], 'number': t['number'], 'title': t['title'], 'part1Id': t['part1'], 'cueCardId': t['cueCard'],
         'part3Ids': t['part3'], 'data': t}
        for t in st['tests']
    ], 'Speaking Test 1-10 (website tests 11-20).', 'assets/content/tests_bank.json → speaking.tests')

    # ── Full mocks ──────────────────────────────────────────────────────────
    emit(66, 'full_mock_tests', 'mock_tests', [
        {'id': m['id'], 'kind': 'full', 'number': m['number'], 'letter': m['letter'], 'title': m['title'],
         'listeningTestId': m['listeningTest'], 'readingTestId': m['readingTest'], 'task1Id': m['task1'],
         'task2Id': m['task2'], 'speaking': m['speaking'], 'writingTestId': m.get('writingTest'),
         'speakingTestId': m.get('speakingTest'), 'data': m}
        for m in tb['mock']['tests']
    ], 'Full Mock Test 1-4 = Listening/Reading/Writing/Speaking Test N.', 'assets/content/tests_bank.json → mock.tests')

    # ── Resources ───────────────────────────────────────────────────────────
    emit(67, 'resource_vocabulary', 'vocabulary_words', [
        {'id': w['id'], 'word': w['word'], 'partOfSpeech': w['pos'], 'definition': w['definition'],
         'band': float(w['band']), 'phonetic': w.get('ipa'),
         'example': plain((w.get('examples') or [None])[0]) or None, 'data': w}
        for w in res['vocab']
    ], 'Vocabulary Vault words (vb_…).', 'assets/content/resources_bank.json → vocab')
    emit(68, 'resource_phrases', 'phrases', [
        {'id': p['id'], 'kind': kind, 'phrase': p['phrase'], 'meaning': p['meaning'], 'example': plain(p['example']),
         'data': p}
        for kind, key in (('phrasal', 'phrasalVerbs'), ('idiom', 'idioms')) for p in res[key]
    ], 'Phrasal verbs (pv_…) and idioms (id_…).', 'assets/content/resources_bank.json → phrasalVerbs, idioms',
        notes=['Ids shared with the demo list (11/12) update those rows; their register/topic are kept.'])
    emit(69, 'resource_academic_words', 'academic_words', [
        {'id': w['id'], 'word': w['word'], 'partOfSpeech': w['pos'], 'meaning': w['definition'], 'data': w}
        for w in res['academicWords']
    ], 'Academic Word List words (aw_…).', 'assets/content/resources_bank.json → academicWords')
    emit(70, 'resource_irregular_verbs', 'irregular_verbs', [
        {'id': 'iv_' + re.sub(r'[^a-z]+', '_', v['base'].lower()).strip('_'), 'base': v['base'], 'past': v['past'],
         'participle': v['participle'], 'meaning': v.get('meaning'), 'example': plain(v.get('example')) or None}
        for v in res['irregularVerbs']
    ], 'Irregular verbs (iv_<base>).', 'assets/content/resources_bank.json → irregularVerbs')

    # ── Documents: guides, notes, lists, glossary, translations ─────────────
    docs = []
    for i, name in enumerate(['listening', 'reading', 'writing', 'speaking', 'grammar', 'vocab']):
        g = load(f'{name}_guide.json')
        docs.append({'id': f'guide.{name}', 'kind': 'guide', 'title': g.get('title'), 'sortOrder': i, 'data': g})
    docs += [
        {'id': 'meta.listening_bank', 'kind': 'meta', 'title': lb['meta'].get('title'), 'sortOrder': 0,
         'data': lb['meta']},
        {'id': 'meta.writing_bank', 'kind': 'meta', 'title': 'Writing question bank', 'sortOrder': 1,
         'data': wb['meta']},
        {'id': 'meta.speaking_bank', 'kind': 'meta', 'title': sb['meta'].get('title'), 'sortOrder': 2,
         'data': sb['meta']},
        {'id': 'meta.tests_bank', 'kind': 'meta', 'title': 'Full tests', 'sortOrder': 3, 'data': tb['meta']},
        {'id': 'list.connectors', 'kind': 'list', 'title': 'Connectors', 'sortOrder': 0, 'data': res['connectors']},
        {'id': 'list.topic_vocabulary', 'kind': 'list', 'title': 'Topic vocabulary', 'sortOrder': 1,
         'data': res['topics']},
        {'id': 'glossary.speaking', 'kind': 'glossary', 'title': 'Speaking sample vocabulary', 'sortOrder': 0,
         'data': sb['vocab']},
    ]
    l10n = os.path.join(CONTENT, 'l10n')
    index = json.load(open(os.path.join(l10n, 'index.json'), encoding='utf-8'))
    docs.append({'id': 'l10n.index', 'kind': 'l10n', 'title': 'Translations index', 'sortOrder': 0, 'data': index})
    n = 1
    for module in sorted(index):
        for lang in index[module]:
            with open(os.path.join(l10n, lang, f'{module}.json'), encoding='utf-8') as f:
                docs.append({'id': f'l10n.{lang}.{module}', 'kind': 'l10n', 'title': f'{module} ({lang})',
                             'sortOrder': n, 'data': json.load(f)})
            n += 1
    emit(71, 'content_documents', 'content_documents', docs,
         'Study guides, bank notes, resource lists, speaking glossary and translations, one JSON document each.',
         'assets/content/*_guide.json, *_bank.json meta, l10n/',
         notes=['id: guide.<module> · meta.<bank> · list.<name> · glossary.speaking · l10n.<lang>.<module>.'])

    # manifest: replace the bank group
    mpath = os.path.join(ROOT, 'seed', 'manifest.json')
    m = json.load(open(mpath, encoding='utf-8'))
    m['formats'] = [f for f in m['formats'] if f.get('group') != 'bank'] + MANIFEST
    m['bankGeneratedFrom'] = 'assets/content/*.json (tool/build_seed_banks.py)'
    with open(mpath, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'{len(MANIFEST)} files, {sum(x["records"] for x in MANIFEST)} rows')


if __name__ == '__main__':
    main()
