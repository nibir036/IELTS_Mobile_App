"""Builds server/data/plan_catalog.json: every item a study plan can schedule.

    python3 tool/build_plan_catalog.py

One entry per course lesson, Sentence Builder set, reading passage / type
lesson / practice test, listening set, writing prompt, speaking topic / cue
card, pronunciation set and full mock:

    {id, ref, module, type, level, minutes, after, order, trains, testType,
     title, route, args, repeat?}

- id      'lesson:w1_l2', 'sb:contrast_set01', 'rb:rb_mcq_01' …
- ref     what the app records when the item is finished (lesson id or the
          attempt's refId) - plan tasks with this ref tick themselves off.
          null = no automatic tick (the student ticks it).
- module  writing | speaking | reading | listening | grammar | vocab
- type    lesson | practice | test | ai_task | mock
- level   1 (easy) … 4 (hard)
- trains  sub-skill tags (see TAGS) - how plans target weak areas.
- route / args  the app screen that opens it (checked against routes.dart).
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'server', 'data', 'plan_catalog.json')

READING_TYPES = ['mcq', 'tfng', 'ynng', 'matching_info', 'headings', 'matching_features',
                 'sentence_endings', 'sentence_completion', 'summary_completion', 'note_completion',
                 'table_completion', 'flowchart_completion', 'diagram_label', 'short_answer']
LISTENING_FORMATS = ['fn', 'mc', 'ma', 'pm', 'sc', 'tc', 'sm', 'sa']

# The sub-skills a plan can target. Writing/speaking criteria follow the
# official band descriptors; reading/listening follow question types.
TAGS = sorted(
    ['writing.t1', 'writing.t2', 'writing.ta', 'writing.cc', 'writing.lr', 'writing.gra',
     'speaking.p1', 'speaking.p2', 'speaking.p3', 'speaking.fc', 'speaking.lr', 'speaking.gra', 'speaking.pron',
     'reading.strategy', 'listening.strategy', 'listening.p1', 'listening.p2', 'listening.p3', 'listening.p4']
    + [f'reading.{t}' for t in READING_TYPES]
    + [f'listening.{f}' for f in LISTENING_FORMATS])

# Course stage → sub-skills it teaches.
STAGE_TAGS = {
    'w1': ['writing.ta', 'writing.cc'], 'w2': ['writing.ta'], 'w3': ['writing.t1', 'writing.ta'],
    'w4': ['writing.t1', 'writing.ta'], 'w5': ['writing.t2', 'writing.ta'], 'w6': ['writing.t2', 'writing.cc'],
    'w7': ['writing.lr'],
    's1': ['speaking.fc'], 's2': ['speaking.fc', 'speaking.lr', 'speaking.gra', 'speaking.pron'], 's3': ['speaking.fc'],
    's4': ['speaking.p1'], 's5': ['speaking.p2'], 's6': ['speaking.p3'], 's7': ['speaking.fc'],
    'r1': ['reading.strategy'], 'r2': ['reading.strategy'], 'r3': ['reading.strategy'],
    'l1': ['listening.strategy', 'listening.p1'], 'l2': ['listening.strategy', 'listening.p3'],
    'l3': ['listening.strategy', 'listening.p4'], 'l4': ['listening.fn', 'listening.sc', 'listening.tc', 'listening.sm'],
    'l5': ['listening.mc', 'listening.ma', 'listening.pm'], 'l6': ['listening.strategy', 'listening.p4'],
    'l7': ['listening.strategy'],
    'g1': ['writing.gra', 'speaking.gra'], 'g2': ['writing.gra', 'speaking.gra'], 'g3': ['writing.gra', 'speaking.gra'],
    'g4': ['writing.gra', 'speaking.gra'], 'g5': ['writing.gra', 'writing.cc'], 'g6': ['writing.gra', 'writing.t1'],
    'g7': ['writing.gra', 'speaking.gra'], 'g8': ['writing.gra'], 'g9': ['writing.gra', 'writing.lr'],
    'g10': ['writing.gra'],
    'v1': ['writing.lr', 'speaking.lr'], 'v2': ['writing.lr', 'speaking.lr'], 'v3': ['writing.lr', 'speaking.lr'],
    'v4': ['writing.cc', 'writing.lr'], 'v5': ['writing.lr', 'speaking.lr'], 'v6': ['writing.lr', 'speaking.lr'],
    'v7': ['writing.lr', 'speaking.lr'], 'v8': ['speaking.lr', 'writing.lr'], 'v9': ['writing.lr'],
    'v10': ['speaking.lr', 'speaking.fc'],
}

SB_TAGS = {
    'relative': ['writing.gra', 'writing.cc'], 'adding': ['writing.cc'], 'contrast': ['writing.cc'],
    'concession': ['writing.cc', 'writing.gra'], 'cause': ['writing.cc'], 'result': ['writing.cc'],
    'purpose': ['writing.cc', 'writing.gra'], 'condition': ['writing.gra', 'writing.cc'], 'time': ['writing.cc'],
    'examples': ['writing.cc', 'writing.ta'], 'comparison': ['writing.cc', 'writing.t1'],
    'summary': ['writing.cc', 'writing.ta'], 'task1': ['writing.t1', 'writing.cc'],
}

ROUTES = {
    'lesson': '/course/lesson', 'sentenceBuilder': '/writing/sentence-builder',
    'readingPassage': '/reading/passage', 'readingQuestions': '/reading/questions',
    'readingTypeLesson': '/reading/bank/lesson', 'listeningPlayer': '/listening/player',
    'listeningAnswerSheet': '/listening/answer-sheet',
    'writingTask1Editor': '/writing/task1', 'writingEditor': '/writing/task2',
    'speakingPart13': '/speaking/part-1-3', 'cueCard': '/speaking/cue-card',
    'pronunciation': '/speaking/pronunciation', 'mockSystemCheck': '/mock/system-check',
}


def load(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
        return json.load(f)


def clean_title(v, part=None):
    t = v.get('en', '') if isinstance(v, dict) else str(v)
    t = re.sub(r'^\s*(Chapter\s+)?\d+(\.\d+)*[.)]?\s+', '', t).strip()
    p = v.get('part') if isinstance(v, dict) else None
    return f'{t} · Part {p}' if p else t


def main():
    items = []

    def add(**kw):
        kw.setdefault('after', None)
        kw.setdefault('testType', 'both')
        items.append(kw)

    # Course lessons, in course order.
    for module in ['writing', 'speaking', 'reading', 'listening', 'grammar', 'vocab']:
        stages = load(f'assets/content/lessons/{module}.json')['stages']
        prev = None
        order = 0
        for si, st in enumerate(stages):
            level = 1 + (3 * si) // max(1, len(stages))
            for le in st['lessons']:
                lid = le['id']
                order += 1
                add(id=f'lesson:{lid}', ref=lid, module=module, type='lesson', level=level,
                    minutes=int(le.get('minutes') or 8), after=prev, order=order,
                    trains=STAGE_TAGS.get(st['id'], []), title=clean_title(le['title']),
                    route=ROUTES['lesson'], args={'lesson': lid})
                prev = f'lesson:{lid}'

    # Sentence Builder sets.
    sb = load('assets/content/sentence_bank.json')
    for c in sb['categories']:
        n = len(c['sets'])
        for i, s in enumerate(c['sets']):
            level = 1 + (3 * i) // max(1, n)
            add(id=f'sb:{s["id"]}', ref=s['id'], module='writing', type='practice', level=level,
                minutes=max(6, len(s['drills'])), order=i + 1, trains=SB_TAGS[c['id']],
                title=f'Sentence Builder · {c["title"]} · {s["title"]}',
                route=ROUTES['sentenceBuilder'], args={'set': s['id']})

    # Reading: type lessons, bank passages, practice tests.
    rb = load('assets/content/reading_bank.json')
    for le in rb['lessons']:
        qt = le['questionType']
        add(id=f'rtl:{qt}', ref=None, module='reading', type='lesson', level=1, minutes=8, order=0,
            trains=[f'reading.{qt}', 'reading.strategy'], title=le['title'],
            route=ROUTES['readingTypeLesson'], args={'type': qt})
    dl = {'easy': 1, 'medium': 2, 'hard': 3}
    for p in rb['passages']:
        qt = p['questionType']
        minutes = max(10, round(p.get('questionCount', 8) * 1.5 + p.get('words', 700) / 150))
        add(id=f'rb:{p["id"]}', ref=p['id'], module='reading', type='practice',
            level=dl.get(p.get('difficulty'), 2), minutes=minutes, order=p.get('bankSet', 0),
            trains=[f'reading.{qt}'], title=f'{p["questionTypeName"]} · {p["title"]}',
            route=ROUTES['readingPassage'], args={'passageId': p['id']})
    for t in rb['tests']:
        add(id=f'rpt:{t["id"]}', ref=t['id'], module='reading', type='test', level=3,
            minutes=int(t.get('minutes') or 35), order=t.get('number', 0),
            trains=sorted({f'reading.{q}' for q in t.get('questionTypes', [])} | {'reading.strategy'}),
            title=t['title'], route=ROUTES['readingQuestions'], args={'testId': t['id']})

    # Listening bank sets.
    lb = load('assets/content/listening_bank.json')
    for s in lb['sets']:
        part = int(s['part'])
        fmt = s['formatCode'].lower()
        add(id=f'lb:{s["id"]}', ref=s['id'], module='listening', type='practice',
            level=min(3, part), minutes=int(s.get('minutes') or 12), order=part,
            trains=[f'listening.p{part}', f'listening.{fmt}'],
            title=f'Part {part} · {s["formatLabel"]} · {s["title"]}',
            route=ROUTES['listeningPlayer'], args={'setId': s['id'], 'fresh': True})

    # Full listening tests (checkpoint section tests): four parts in one sitting.
    tb = load('assets/content/tests_bank.json')
    for t in tb['listening']['tests']:
        add(id=f'lt:{t["id"]}', ref=t['id'], module='listening', type='test', level=3, minutes=40,
            order=t.get('number', 0),
            trains=['listening.p1', 'listening.p2', 'listening.p3', 'listening.p4', 'listening.strategy'],
            title=t.get('title') or 'Listening Test', route=ROUTES['listeningAnswerSheet'],
            args={'testId': t['id'], 'fresh': True})

    # Writing prompts (AI-scored).
    wb = load('assets/content/writing_bank.json')
    for p in wb['task1']:
        add(id=f'w1:{p["id"]}', ref=p['id'], module='writing', type='ai_task', level=2, minutes=25,
            order=p.get('number', 0), testType='academic',
            trains=['writing.t1', 'writing.ta', 'writing.cc', 'writing.lr', 'writing.gra'],
            title=f'Task 1 · {p["typeLabel"]} · {p["title"]}',
            route=ROUTES['writingTask1Editor'], args={'promptId': p['id']})
    d2 = {'Moderate': 2, 'Upper-moderate': 3, 'Difficult': 4}
    for p in wb['task2']:
        add(id=f'w2:{p["id"]}', ref=p['id'], module='writing', type='ai_task',
            level=d2.get(p.get('difficulty'), 3), minutes=45, order=p.get('number', 0),
            trains=['writing.t2', 'writing.ta', 'writing.cc', 'writing.lr', 'writing.gra'],
            title=f'Task 2 · {p["typeLabel"]} · {p["title"]}',
            route=ROUTES['writingEditor'], args={'promptId': p['id']}, topic=p.get('topic', ''))

    # Speaking.
    spk = load('assets/content/speaking_bank.json')
    for i, t in enumerate(spk['part1Topics']):
        add(id=f'sp1:{t["id"]}', ref=t['id'], module='speaking', type='ai_task', level=1, minutes=8,
            order=i, trains=['speaking.p1', 'speaking.fc'], title=f'Speaking Part 1 · {t["topic"]}',
            route=ROUTES['speakingPart13'], args={'part': 1, 'topicId': t['id']})
    for i, c in enumerate(spk['cueCards']):
        add(id=f'sp2:{c["id"]}', ref=c['id'], module='speaking', type='ai_task', level=2, minutes=10,
            order=i, trains=['speaking.p2', 'speaking.fc', 'speaking.lr'],
            title=f'Speaking Part 2 · {c["title"]}', route=ROUTES['cueCard'], args={'cardId': c['id']})
    for i, t in enumerate(spk['part3Topics']):
        add(id=f'sp3:{t["id"]}', ref=t['id'], module='speaking', type='ai_task', level=3, minutes=10,
            order=i, trains=['speaking.p3', 'speaking.lr', 'speaking.gra'],
            title=f'Speaking Part 3 · {t["topic"]}', route=ROUTES['speakingPart13'],
            args={'part': 3, 'part3TopicId': t['id']})
    add(id='pron:daily', ref='pron_daily', module='speaking', type='practice', level=1, minutes=10, order=0,
        trains=['speaking.pron'], title='Pronunciation · 10 words', route=ROUTES['pronunciation'], args={},
        repeat=True)

    # Full mock tests (checkpoints).
    tb = load('assets/content/tests_bank.json')
    for i, m in enumerate(tb['mock']['tests']):
        add(id=f'mock:{m["id"]}', ref=m['id'], module='mock', type='mock', level=3, minutes=170, order=i,
            trains=[], title=m.get('title') or f'Full Mock Test {i + 1}',
            route=ROUTES['mockSystemCheck'], args={'mockId': m['id']})

    # ── checks ──
    routes_src = open(os.path.join(ROOT, 'lib', 'app', 'routes.dart'), encoding='utf-8').read()
    errs = []
    ids = set()
    for it in items:
        if it['id'] in ids:
            errs.append(f'duplicate id {it["id"]}')
        ids.add(it['id'])
        if f"'{it['route']}'" not in routes_src:
            errs.append(f'{it["id"]}: unknown route {it["route"]}')
        for tg in it['trains']:
            if tg not in TAGS:
                errs.append(f'{it["id"]}: unknown tag {tg}')
        if it['after'] and it['after'] not in ids:
            errs.append(f'{it["id"]}: prerequisite {it["after"]} not defined before it')
        if not it['title']:
            errs.append(f'{it["id"]}: empty title')
    if errs:
        print('\n'.join(errs))
        sys.exit(1)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out = {'version': 1, 'tags': TAGS, 'items': items}
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    by = {}
    for it in items:
        by[it['type']] = by.get(it['type'], 0) + 1
    print(f'wrote {OUT}: {len(items)} items {by}')


if __name__ == '__main__':
    main()
