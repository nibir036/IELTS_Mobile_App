"""Vocabulary Lessons (study guide 'vocab') = the full nextED vocabulary book *Zero to Band 9* (website data/vocab).

usage: python3 tool/import_vocab_book.py
Source: seed/sources/vocab/book/chapter1..7.json (NextEd-IELTS-V2 data/vocab/chapterN_data, structured blocks +
        the PDF text). Chapter 7 is the book's answer key: its answers (with the English "Why" and the Bangla note)
        are attached to the exercises of Chapters 1–6 instead of being a chapter of their own.
Output: seed/staging/vocab_guide/en/NN_<chapter>.json — every chapter of the book, complete:
  1 L1 Interference Fixer   intro · the 30 errors (wrong → right, Bangla logic, rule, examiner view) · 2 exercises
  2 Band Upgrade Matrix     intro · the 35 words (Band 5.5 / 7.5 / 9.0, Speaking vs Writing, Bangla nuance) · 2 ex.
  3 Verbs & Transitions     the 100-verb table · linking-word guide (8 categories, 3 traps) · 2 exercises
  4 Topic vocabulary        15 topics × (10 nouns, 10 verbs, 10 collocations, 5 Task 2 phrases, 5 idioms) · 3 ex.
  5 Idioms & register       the separation rule · 50 Speaking idioms · 50 Writing collocations · 2 exercises
  6 Workbook                20 transformations · 5 essay rewrites · 5 Speaking simulations with models
The Bangla notes of the answer key (বাংলা: …) are kept in seed/staging/vocab_guide/key_bn.json for the translators.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
import import_grammar as ig  # noqa: E402  (clean)

SRC = ROOT / 'seed' / 'sources' / 'vocab' / 'book'
ST = ROOT / 'seed' / 'staging' / 'vocab_guide'

# Bangla words the PDF text split in two.
BN_FIX = {'ভু ল': 'ভুল', 'বহুসংস্কৃ তিবাদ': 'বহুসংস্কৃতিবাদ', 'কৃ ষির': 'কৃষির', 'স্কু লের': 'স্কুলের',
          'বন্ধু দের': 'বন্ধুদের', 'বাস্তু তন্ত্র': 'বাস্তুতন্ত্র', 'কৃ ত্রিম': 'কৃত্রিম', 'ভু ক্তভোগী': 'ভুক্তভোগী',
          'বিউটিফু ল': 'বিউটিফুল', 'উজাড় )': 'উজাড়)'}

KEY_BN = {}  # exercise item id → the answer key's Bangla note


TAIL = re.compile(r'\s+(?:Chapter \d+(?: Batch \d+)? Answer Key|Chapter \d+: [A-Z]|End of Chapter \d).*$', re.S)


def cut_tail(s):
    return TAIL.sub('', s).strip()


def c(s):
    s = '' if s is None else str(s)
    s = s.replace(' before checking the key at the end of the file', ' before checking the answers')
    s = s.replace(' before checking the key at the end', ' before checking the answers')
    for a, b in BN_FIX.items():
        s = s.replace(a, b)
    return ig.clean(s.replace('&rarr;', '→'))


def flat(s):
    """PDF text → one line (wrapped lines joined; "error-\nfree" kept as error-free)."""
    s = c(s)
    s = re.sub(r'-\n(?=\w)', '-', s)
    s = re.sub(r'\s*\n\s*', ' ', s)
    return re.sub(r'\s{2,}', ' ', s).strip()


def paras(text, per=3):
    """A long unbroken intro → paragraphs of about [per] sentences."""
    sents = re.split(r'(?<=[.!?”])\s+(?=[A-Z“])', flat(text))
    return [' '.join(sents[i:i + per]) for i in range(0, len(sents), per)]


def numbered(text, n=None):
    """'1. … 2. … 3. …' (inline or on lines) → [item1, item2, …], cut at the sequential numbers."""
    t = ' ' + flat(text)
    out, pos, k = [], None, 1
    starts = []
    while True:
        m = re.compile(r'(?<=\s)' + str(k) + r'\.\s+').search(t, 0 if pos is None else pos)
        if not m or (n is not None and k > n):
            break
        starts.append((m.start(), m.end()))
        pos = m.end()
        k += 1
    for i, (a, b) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(t)
        out.append(t[b:end].strip())
    if out:
        out[-1] = cut_tail(out[-1])
    return out


def why_split(s):
    """'answer - Why: … - বাংলা: …' → (answer, why, bn)."""
    bn = ''
    m = re.search(r'\s*-?\s*বাংলা:\s*', s)
    if m:
        s, bn = s[:m.start()], s[m.end():]
    why = ''
    m = re.search(r'\s*-?\s*(?:Why|Trap):\s*', s)
    if m:
        s, why = s[:m.start()], s[m.end():]
    return s.strip(), why.strip(), bn.strip().rstrip('-').strip()


def section(text, start, end=None):
    i = text.find(start)
    if i < 0:
        raise ValueError(f'missing {start!r}')
    j = len(text) if end is None else text.find(end, i + len(start))
    return text[i + len(start):j if j >= 0 else len(text)]


def load(n):
    return json.loads((SRC / f'chapter{n}.json').read_text(encoding='utf-8'))


def blocks_of(d, t):
    return [b for b in d['blocks'] if b['type'] == t]


def ex(title, kind, instructions, items):
    return ['exercise', {'title': title, 'kind': kind, 'instructions': instructions, 'items': items}]


def item(prompt, answer, accepted=(), reason='', key=None, bn=''):
    out = {'prompt': prompt, 'answer': answer, 'accepted': list(accepted), 'reason': reason}
    if bn:
        out['_bn'] = bn  # moved to key_bn.json by main()
    return out


def chap(cid, title, group, blocks):
    return {'id': cid, 'title': title, 'group': group, 'blocks': blocks}


def strip_head(text, n):
    return re.sub(rf'^Chapter {n}:[^.]*?(?=(Most|Chapter 1 removed)\b)', '', flat(text)).strip()


K7 = load(7)
KEY = {b['source_chapter']: flat(b['content']) for b in K7['blocks'] if b['type'] == 'answer_key_section'}
# the Chapter 5/6 key sections in the source spill into the next block: rejoin the whole key text
KEY_ALL = flat('\n'.join(b.get('content', '') for b in K7['blocks']))


# ── Chapter 1 ──────────────────────────────────────────────────────────────────────────────────────────────────
def chapter1():
    d = load(1)
    g = 'Chapter 1 · L1 Interference Fixer'
    intro = blocks_of(d, 'intro')[0]
    matrix = blocks_of(d, 'error_matrix')[0]
    exs = blocks_of(d, 'exercise')
    out = [chap('v1_intro', 'The Bangladeshi L1 Interference Fixer', g,
                [['p', x] for x in paras(strip_head(intro['content'], 1))])]
    errs = matrix['items']
    for k in range(3):
        part = errs[k * 10:(k + 1) * 10]
        bl = []
        for e in part:
            bl += [
                ['h2', f'Error {e["number"]}'],
                ['pair', c(e['incorrect_sentence']), ' / '.join(c(x) for x in e['band_9_corrections']),
                 c(e['grammar_lexical_rule'])],
                ['box', 'l1', 'Bangla logic', c(e['bangla_logic']), []],
                ['note', '**Examiner view:** ' + c(e['examiner_insight'])],
            ]
        out.append(chap(f'v1_errors_{k + 1}', f'The 30 core errors ({part[0]["number"]}–{part[-1]["number"]})', g, bl))
    key = KEY[1]
    k11 = numbered(section(key, 'Exercise 1.1 · Spot the L1 Error', 'Exercise 1.2'), 15)
    k12 = numbered(section(key, 'Model answers with the trap each one targets.'), 10)
    e1, e2 = exs
    items1 = []
    for q, a in zip(e1['questions'], k11):
        ans, why, bn = why_split(a)
        items1.append(item(c(q['sentence']), ans, reason=why, key=q['id'], bn=bn))
    items2 = []
    for q, a in zip(e2['questions'], k12):
        ans, why, bn = why_split(a)
        items2.append(item(c(q['prompt']), ans, reason=('Trap: ' + why) if why else '', key=q['id'], bn=bn))
    assert len(items1) == 15 and len(items2) == 10, (len(items1), len(items2))
    out.append(chap('v1_practice', 'Practice · Spot and fix the L1 errors', g, [
        ['tip', c(e1['part_instructions'])],
        ex('Exercise 1.1 · Spot the L1 Error', 'essay_edit', c(e1['instructions']), items1),
        ex('Exercise 1.2 · Bangla to Band 9 Translation Challenge', 'essay_edit', c(e2['instructions']), items2),
    ]))
    return out


# ── Chapter 2 ──────────────────────────────────────────────────────────────────────────────────────────────────
def chapter2():
    d = load(2)
    g = 'Chapter 2 · Band Upgrade Matrix'
    intro = blocks_of(d, 'intro')[0]
    matrix = blocks_of(d, 'vocabulary_matrix')[0]
    e1, e2 = blocks_of(d, 'exercise')
    out = [chap('v2_intro', 'The Band Upgrade Matrix', g, [['p', x] for x in paras(strip_head(intro['content'], 2))])]
    words = matrix['items']
    cuts = [(0, 9), (9, 18), (18, 27), (27, 35)]
    for k, (a, b) in enumerate(cuts):
        part = words[a:b]
        bl = []
        for w in part:
            lv = w['levels']
            bl += [
                ['h2', f'{w["number"]}. {c(w["term"])}'],
                ['table', ['Level', 'What to use'], [
                    ['Band 5.5 (now)', c(lv['band_5_5'])],
                    ['Band 7.5', c(lv['band_7_5'])],
                    ['Band 9.0', c(lv['band_9_0'])],
                ]],
                ['note', '**Speaking vs Writing:** ' + c(w['speaking_vs_writing'])],
                ['box', 'l1', 'Bangla nuance', c(w['bangla_nuance']), []],
            ]
        out.append(chap(f'v2_matrix_{k + 1}', f'The upgrade matrix ({part[0]["number"]}–{part[-1]["number"]}: '
                        f'{c(part[0]["term"])} … {c(part[-1]["term"])})', g, bl))
    key = KEY[2]
    k21 = numbered(section(key, 'Other natural versions are valid.', '• Why (general)'), 10)
    gen = section(key, '• Why (general):', 'Exercise 2.2')
    gen_en, _, gen_bn = gen.partition('• বাংলা:')
    k22 = numbered(section(key, 'Exercise 2.2 · Context Match'), 15)
    items1 = []
    for q, a in zip(e1['questions'], k21):
        m = re.match(r'(.*?)\s*\((.*)\)\s*$', a)
        ans, note = (m.group(1), m.group(2)) if m else (a, '')
        items1.append(item(c(q['prompt']), ans.strip(), reason=('Upgrade: ' + note.rstrip('.') + '.') if note else ''))
    items2 = []
    for q, a in zip(e2['questions'], k22):
        ans, why, bn = why_split(a)
        ans = ans.rstrip('.')
        opts = re.search(r'\(([^)]*/[^)]*)\)\s*$', q['prompt'])
        items2.append(item(c(q['prompt']), ans, reason=why, key=q['id'], bn=bn))
        assert opts and ans in [o.strip() for o in opts.group(1).split('/')] or ans in q['prompt'], (ans, q['prompt'])
    assert len(items1) == 10 and len(items2) == 15
    out.append(chap('v2_practice', 'Practice · Upgrade and match', g, [
        ['tip', c(e1['part_instructions'])],
        ex('Exercise 2.1 · Lexical Upgrade Drill', 'essay_edit', c(e1['instructions']), items1),
        ['note', '**Why it works:** ' + gen_en.strip()],
        ex('Exercise 2.2 · Context Match', 'gap_fill',
           c(e2['instructions']) + ' Type the word.', items2),
    ]))
    KEY_BN['v2_ex1_general'] = gen_bn.strip()
    return out


# ── Chapter 3 ──────────────────────────────────────────────────────────────────────────────────────────────────
def chapter3():
    d = load(3)
    g = 'Chapter 3 · Verbs and Linking Words'
    vm = blocks_of(d, 'verb_matrix')[0]
    lg = blocks_of(d, 'linking_guide')[0]
    e1, e2 = blocks_of(d, 'exercise')
    hr = vm['how_to_read']

    def dash(x):
        return '—' if x in ('-', '', None) else c(x)

    out = []
    verbs = vm['items']
    for k, (a, b) in enumerate([(0, 50), (50, 100)]):
        bl = []
        if k == 0:
            bl += [['p', c(vm['instructions'])],
                   ['ul', [f'**{x}**: {c(y)}' for x, y in hr.items()]],
                   ['note', c(vm['spelling_note'])]]
        for s in range(a, b, 25):
            rows = [[f'**{c(v["base_v1"])}**', f'{c(v["past_v2"])} · {c(v["participle_v3"])} · {c(v["ing_v4"])}',
                     f'{dash(v["noun"])} · {dash(v["adjective"])}', dash(v['preposition'])]
                    for v in verbs[s:s + 25]]
            bl.append(['table', ['Verb (V1)', 'V2 · V3 · V4', 'Noun · Adjective', 'Prep.'], rows,
                       f'Verbs {s + 1}–{s + 25}'])
        if k == 1:
            bl += [['tip', c(n)] for n in vm['notes']]
        out.append(chap(f'v3_verbs_{k + 1}', f'The 100 high-impact verbs ({a + 1}–{b})', g, bl))
    bl = [['p', c(lg['introduction'])],
          ['table', ['Purpose', 'Basic', 'Band 7+ upgrade', 'Example'],
           [[f'**{c(x["category"])}**', ', '.join(c(y) for y in x['basic']), ', '.join(c(y) for y in x['upgrades']),
             c(x['example'])] for x in lg['categories']]],
          ['h', 'Traps to know']]
    for tr in lg['traps']:
        bl.append(['h2', c(tr['title'])])
        if tr.get('wrong'):
            bl.append(['pair', c(tr['wrong']), ' / '.join(c(x) for x in tr['right']), c(tr['explanation'])])
        else:
            bl.append(['p', c(tr['explanation'])])
    extra = [k for k in lg if k not in ('id', 'type', 'title', 'introduction', 'categories', 'traps', 'source_text')]
    for k in extra:
        v = lg[k]
        if isinstance(v, str) and v.strip():
            bl.append(['note', c(v)])
        elif isinstance(v, list):
            bl.append(['ul', [c(x) if isinstance(x, str) else c(json.dumps(x, ensure_ascii=False)) for x in v]])
    out.append(chap('v3_linking', 'The linking word upgrade guide', g, bl))
    key = KEY[3]
    k31 = numbered(section(key, 'Exercise 3.1 · Verb Form and Collocation Drill', 'Exercise 3.2'), 20)
    items = []
    for q, a in zip(e1['questions'], k31):
        ans, why, bn = why_split(a)
        ans = ans.rstrip('.')
        alts = [x.strip() for x in ans.split(' / ')]
        acc = alts[1:] + ([ans] if len(alts) > 1 else [])
        if '…' in ans:
            acc += [ans.replace('…', '...'), ans.replace(' … ', ' ')]
        items.append(item(c(q['prompt']), alts[0], accepted=acc, reason=why, key=q['id'], bn=bn))
    assert len(items) == 20
    model = section(key, 'Model rewrite:', '• Why:').strip()
    w32 = section(key, '• Why:', '• বাংলা:').strip()
    KEY_BN['ch3-exercise-3-2'] = section(key, '• বাংলা:', 'End of Chapter 7').strip()
    out.append(chap('v3_practice', 'Practice · Verb forms and cohesion', g, [
        ex('Exercise 3.1 · Verb Form and Collocation Drill', 'gap_fill', c(e1['instructions']), items),
        ex('Exercise 3.2 · Cohesive Device Transformation', 'essay_edit', c(e2['instructions']),
           [item(c(e2['prompt']), model, reason=w32, key='ch3-exercise-3-2', bn=KEY_BN['ch3-exercise-3-2'])]),
    ]))
    return out


# ── Chapter 4 ──────────────────────────────────────────────────────────────────────────────────────────────────
SEC_TITLE = {'academic_nouns': 'Academic nouns ({n})', 'precise_verbs': 'Precise verbs ({n}) · past, participle, -ing',
             'collocations_and_adjectives': 'Collocations and adjectives ({n})',
             'formal_task2_collocations': 'Formal Task 2 collocations ({n}) · Writing',
             'speaking_idioms': 'Speaking idioms and expressions ({n}) · Speaking only'}


def lead_bold(s):
    """'emission (নিঃসরণ): Industrial …' → '**emission** (নিঃসরণ): Industrial …'"""
    m = re.match(r'^(.+?)(\s*\([^)]*\))?:\s+(.*)$', s)
    if not m:
        return s
    return f'**{m.group(1).strip()}**{m.group(2) or ""}: {m.group(3)}'


def lead_and_items(text, n):
    t = flat(text)
    m = re.search(r'(?:^|\s)1\.\s', t)
    lead = t[:m.start()].strip() if m else t
    return lead, numbered(t[m.start():] if m else '', n)


def chapter4():
    d = load(4)
    g = 'Chapter 4 · Topic Vocabulary'
    intros = blocks_of(d, 'batch_intro')
    keys = '\n'.join(b['content'] for b in blocks_of(d, 'answer_key'))
    first = flat(re.sub(r'^Chapter 4:[^\n]*\n', '', intros[0]['content']))
    first = first.replace(' This batch covers the first five domains: Environment, Education, Technology, Health, and '
                          'Crime. Batches 2 and 3 cover the remaining ten.', '')
    out = [chap('v4_intro', 'Topic-based lexical mastery: how to use the 15 topics', g,
                [['p', x] for x in paras(first, 3)])]
    k4 = KEY[4]
    for b in blocks_of(d, 'topic_bundle'):
        n = b['topic_number']
        bl = []
        exercise_text = ''
        for s in b['sections']:
            if s['type'] == 'exercises':
                exercise_text = s['content']
                continue
            items = [lead_bold(x) for x in numbered(s['content'])]
            assert len(items) in (5, 10), (n, s['type'], len(items))
            bl += [['h2', SEC_TITLE[s['type']].format(n=len(items))], ['ul', items]]
        # exercises: match, completion, speaking drill
        t = c(exercise_text)
        m1 = re.search(rf'Exercise 4\.{n}\.1 · Vocabulary Match\.(.*?)Exercise 4\.{n}\.2', t, re.S).group(1)
        m2 = re.search(rf'Exercise 4\.{n}\.2 · Essay Sentence Completion\.(.*?)Exercise 4\.{n}\.3', t, re.S).group(1)
        m3 = re.search(rf'Exercise 4\.{n}\.3 · Speaking Simulation Drill\.(.*)$', t, re.S).group(1)
        instr1, _, rest = flat(m1).partition('(a to j).')
        if not rest:
            instr1, rest = 'Match each term (1 to 10) with its meaning', flat(m1)
        rest = ' ' + rest.strip()
        lettered = re.split(r'\s(?=[a-j]\.\s)', ' ' + rest.split(' a. ', 1)[1] if ' a. ' in rest else rest)
        meanings = {}
        body = 'a. ' + rest.split(' a. ', 1)[1]
        for mm in re.finditer(r'([a-j])\.\s+(.*?)(?=\s[a-j]\.\s|$)', body):
            meanings[mm.group(1)] = mm.group(2).strip()
        terms_part = rest.split(' a. ', 1)[0]
        terms = [x.strip() for x in re.split(r'\s*·\s*\d+\.\s*', re.sub(r'^\s*1\.\s*', '', terms_part))]
        assert len(terms) == 10 and len(meanings) == 10, (n, terms, meanings)
        km = re.search(rf'4\.{n}\.1 Match: (.*?)\. 4\.{n}\.2', flat(keys))
        pairs = dict(re.findall(r'(\d+)-([a-j])', km.group(1)))
        match_items = [item(terms[i], pairs[str(i + 1)], accepted=[meanings[pairs[str(i + 1)]]],
                            reason=f'{pairs[str(i + 1)]}. {meanings[pairs[str(i + 1)]]}') for i in range(10)]
        instr2, sents = lead_and_items(m2, 5)
        instr2 = instr2 or 'Complete each Task 2 sentence with a term from this topic.'
        kc = re.search(rf'4\.{n}\.2 Completion: (.*?)\. 4\.{n}\.3', flat(keys)).group(1)
        comp = re.findall(r'(?:^|,\s*)(\d)\s+([^,]+)', kc)
        assert len(comp) == 5 and len(sents) == 5, (n, comp, sents)
        # bilingual note from the master key (Chapter 7)
        note = re.search(rf'Topic {n} · [^.]*\.(.*?)(?=Topic {n + 1} ·|Batch \d|Judging the Speaking|$)', k4)
        why = bn = ''
        if note:
            _, why, bn = why_split(note.group(1))
        comp_items = []
        for i, (num, ans) in enumerate(comp):
            ans = ans.strip()
            alts = re.split(r'\s*/\s*|\s*\(or\s*', ans.rstrip(')'))
            alts = [x.strip(' )') for x in alts if x.strip(' )')]
            comp_items.append(item(sents[i], alts[0], accepted=alts[1:]))
        if bn:
            KEY_BN[f'v4_{n}_completion'] = bn
        instr3, qs = lead_and_items(m3, 3)
        instr3 = instr3 or ('Answer each Part 3 question in two to three sentences, using at least one target idiom '
                            'and one collocation.')
        km3 = re.search(rf'4\.{n}\.3 Models\.(.*?)(?=Topic \d+:|End of Chapter 4|$)', flat(keys))
        models = re.split(r'\s*-\s*Q\d:\s*', km3.group(1).strip())[1:]
        assert len(qs) == 3 and len(models) == 3, (n, qs, models)
        bl += [
            ['h', 'Practice'],
            ex(f'Exercise 4.{n}.1 · Vocabulary Match',
               'gap_fill', instr1.strip() + ' (a to j). Type the letter.\n\n' +
               '\n'.join(f'{k}. {v}' for k, v in sorted(meanings.items())), match_items),
            ex(f'Exercise 4.{n}.2 · Essay Sentence Completion', 'gap_fill', instr2.strip(), comp_items),
            *([['note', '**Why:** ' + why]] if why else []),
            ex(f'Exercise 4.{n}.3 · Speaking Simulation Drill', 'essay_edit',
               instr3.strip() + ' Then compare with the model answer.',
               [item(q, models[i].strip()) for i, q in enumerate(qs)]),
        ]
        out.append(chap(f'v4_topic_{n:02d}', f'Topic {n} · {c(b["title"])}', g, bl))
    return out


# ── Chapter 5 ──────────────────────────────────────────────────────────────────────────────────────────────────
def example_of(x):
    e = x.get('example') or ''
    if not e.strip() and x.get('bangla') and not re.search('[\u0980-\u09FF]', x['bangla']):
        e = x['bangla']  # the source swapped the two fields for a few entries
    return c(e)


def chapter5():
    d = load(5)
    g = 'Chapter 5 · Idioms and Register'
    rr = blocks_of(d, 'register_rule')[0]
    il = blocks_of(d, 'idiom_list')[0]
    cl = blocks_of(d, 'collocation_list')[0]
    e1, e2 = blocks_of(d, 'exercise')
    text = flat(rr['content'])
    text = text.split(' The decision rule.')[0]
    out = [chap('v5_rule', 'The strict separation rule', g, [['p', x] for x in paras(text, 3)] + [
        ['h2', 'The decision rule'],
        ['ul', ['**Safe for Task 2:** ' + c(rr['decision_rule']['safe_for_task2']) + ' If yes, use it in your essay.',
                '**Keep for Speaking:** ' + c(rr['decision_rule']['keep_for_speaking']) + ' If yes, keep it out of '
                'Writing Task 2.']],
        ['note', '**Phrasal verbs:** ' + c(rr['phrasal_verb_note'])],
    ])]
    idioms = il['items']
    for k, (a, b) in enumerate([(0, 25), (25, 50)]):
        bl = [['tip', c(il['intro'])]] if k == 0 else []
        groups = {}
        for x in idioms[a:b]:
            groups.setdefault(c(x['part']), []).append(x)
        for part, xs in groups.items():
            bl += [['h2', part], ['ul', [f'**{c(x["expression"])}**: {c(x["meaning"])}. Example: {example_of(x)}'
                                       for x in xs]]]
        out.append(chap(f'v5_idioms_{k + 1}', f'50 Speaking idioms ({a + 1}–{b})', g, bl))
    for k, (a, b) in enumerate([(0, 25), (25, 50)]):
        bl = [['tip', c(cl['intro'])]] if k == 0 else []
        groups = {}
        for x in cl['items'][a:b]:
            groups.setdefault(c(x['category']), []).append(x)
        for cat, xs in groups.items():
            bl += [['h2', cat], ['ul', [f'**{c(x["expression"])}**: {c(x["meaning"])}. Example: {example_of(x)}'
                                      for x in xs]]]
        out.append(chap(f'v5_collocations_{k + 1}', f'50 Writing collocations ({a + 1}–{b})', g, bl))
    key = section(KEY_ALL, 'Exercise 5.1 · Register and Style Sort', 'Exercise 5.2')
    k51 = numbered(key.split('• Why:')[0].split('a formal rewrite is given.', 1)[1], 20)
    w51 = section(key, '• Why:', '• বাংলা:').strip()
    KEY_BN['ch5-exercise-5-1'] = key.split('• বাংলা:')[1].strip()
    items1 = []
    for q, a in zip(e1['questions'], k51):
        m = re.match(r'^([SW])\.\s*(.*)$', a)
        mark, rest = m.group(1), m.group(2)
        if mark == 'W':
            items1.append(item(c(q['prompt']), 'W — appropriate for Task 2.'))
        else:
            mm = re.match(r'(.*?)\s*\(([^()]*)\)\s*$', rest)
            rew, why = (mm.group(1), mm.group(2)) if mm else (rest, '')
            items1.append(item(c(q['prompt']), f'S — {rew.strip()}', reason=why.strip().rstrip('.').capitalize() + '.'
                               if why else ''))
    key2 = section(KEY_ALL, 'Exercise 5.2 · Idiom Substitution', 'Chapter 6: Full Workbook')
    k52 = numbered(key2, len(e2['questions']))
    items2 = []
    for q, a in zip(e2['questions'], k52):
        ans, _, bn = why_split(a)
        m = re.match(r'(.*?)\s*\((.*)\)\.?\s*$', ans)
        ans, note = (m.group(1), m.group(2)) if m else (ans, '')
        alt = [ans.replace('’', "'")] if '’' in ans else []
        items2.append(item(cut_tail(c(q['prompt'])), ans.strip(), accepted=alt, reason=note[:1].upper() + note[1:] + '.'
                           if note else '', key=q['id'], bn=bn))
    assert len(items1) == 20 and len(items2) == len(e2['questions']), (len(items1), len(items2))
    out.append(chap('v5_practice', 'Practice · Register sort and idiom repair', g, [
        ex('Exercise 5.1 · Register and Style Sort', 'essay_edit', c(e1['instructions']), items1),
        ['note', '**Why:** ' + w51],
        ex('Exercise 5.2 · Idiom Substitution', 'gap_fill', c(e2['instructions']) + ' Type the correct idiom.', items2),
    ]))
    return out


# ── Chapter 6 ──────────────────────────────────────────────────────────────────────────────────────────────────
def chapter6():
    d = load(6)
    g = 'Chapter 6 · Workbook and Self-Assessment'
    intro, sp_intro = blocks_of(d, 'intro')
    e1, e2 = blocks_of(d, 'exercise')
    src = c(d['source_text'])
    k1 = section(src, 'Section 1: Sentence Transformations', 'Section 2: Essay Rewrites')
    lines = numbered(k1, 20)
    items1 = []
    for q, a in zip(e1['questions'], lines):
        m = re.match(r'(.*?)\s*\(([^()]*)\)\s*$', a)
        ans, why = (m.group(1), m.group(2)) if m else (a, '')
        items1.append(item(c(q['prompt']), ans.strip(), reason=('Upgrade: ' + why.rstrip('.') + '.') if why else ''))
    assert len(items1) == 20
    why1 = section(KEY_ALL, 'Section 1 · Sentence Transformations (Band 9 models)', 'Section 2 · Essay Rewrites')
    w_en = section(why1, '• Why:', '• বাংলা:').strip()
    KEY_BN['ch6-section1'] = why1.split('• বাংলা:')[1].strip()
    out = [chap('v6_intro', 'The full workbook: how to use it', g,
                [['p', c(intro['content'])], ['ol', [c(x) for x in intro['instructions']]]]),
           chap('v6_transformations', 'Section 1 · 20 sentence transformations', g, [
               ex(c(e1['title']), 'essay_edit', c(e1['instructions']).replace(
                   ' Model answers are in the key at the end of this file.', ''), items1),
               ['note', '**Why these work:** ' + w_en]])]
    for e in e2['essays']:
        n = e['number']
        out.append(chap(f'v6_essay_{n}', f'Section 2 · Essay rewrite {n} ({c(e["question_type"])})', g, [
            ['note', f'**Task 2 question ({c(e["question_type"])}):** {c(e["prompt"])}'],
            ex(f'Essay {n} · the Band 6.0 draft', 'essay_edit',
               'Rewrite this Band 6.0 essay at Band 8.5 to 9.0: keep the ideas, upgrade the language (remove L1 '
               'slips, replace overused words, use cohesive devices, add a formal collocation in each paragraph). '
               'Then compare with the model rewrite.',
               [item(c(e['draft']), c(e['model_answer']), reason='Key upgrades: ' + c(e['key_upgrades']))]),
        ]))
    hw = [c(x) for x in sp_intro['how_to_use']]
    for k, s in enumerate(blocks_of(d, 'speaking_simulation')):
        p2 = s['part2']
        bl = []
        if k == 0:
            bl += [['p', c(sp_intro['content'])], ['ol', hw]]
        bl += [['note', f'**Part 2 cue card · {c(p2["title"])}**\nYou should say:\n' +
                '\n'.join('• ' + c(x) for x in p2['prompts'])],
               ['h2', 'Model long turn'], ['model', c(s['model_long_turn'])],
               ['h2', 'Part 3 · Discussion']]
        for qa in s['part3']:
            bl += [['p', f'**{c(qa["question"])}**'], ['model', c(qa['answer'])]]
        bl += [['tip', '**Lexical analysis:** ' + c(s['lexical_analysis'])]]
        out.append(chap(f'v6_speaking_{s["simulation_number"]}',
                        f'Speaking simulation {s["simulation_number"]} · {c(p2["title"])}', g, bl))
    return out


def main():
    chapters = {1: chapter1(), 2: chapter2(), 3: chapter3(), 4: chapter4(), 5: chapter5(), 6: chapter6()}
    names = {1: 'l1_fixer', 2: 'upgrade_matrix', 3: 'verbs_linking', 4: 'topic_vocabulary', 5: 'idioms_register',
             6: 'workbook'}
    out_dir = ST / 'en'
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob('*.json'):
        old.unlink()
    total = 0
    hints = {}
    for chs in chapters.values():
        for ch in chs:
            for b in ch['blocks']:
                if b[0] != 'exercise':
                    continue
                for i, it in enumerate(b[1]['items'], 1):
                    bn = it.pop('_bn', '')
                    if bn:
                        hints.setdefault(ch['id'], {}).setdefault(b[1]['title'], {})[str(i)] = bn
    files = []
    for n, chs in chapters.items():
        if n == 4:  # 16 chapters: three files of five topics (the book's three batches)
            files += [('04a_topics_01_05.json', chs[:6]), ('04b_topics_06_10.json', chs[6:11]),
                      ('04c_topics_11_15.json', chs[11:])]
        else:
            files.append((f'{n:02d}_{names[n]}.json', chs))
    for name, chs in files:
        (out_dir / name).write_text(json.dumps(chs, ensure_ascii=False, indent=1), encoding='utf-8')
        ex_items = sum(len(b[1]['items']) for ch in chs for b in ch['blocks'] if b[0] == 'exercise')
        print(f'{name}: {len(chs)} chapters · {sum(len(ch["blocks"]) for ch in chs)} blocks · {ex_items} exercise items')
        total += len(chs)
    (ST / 'key_bn.json').write_text(json.dumps({'items': hints, 'notes': KEY_BN}, ensure_ascii=False, indent=1),
                                    encoding='utf-8')
    print(f'{total} chapters · {sum(len(x) for e in hints.values() for x in e.values())} Bangla item notes · '
          f'{len(KEY_BN)} Bangla general notes')


if __name__ == '__main__':
    main()
