#!/usr/bin/env python3
"""Builds assets/content/lessons/<module>.json - the bite-sized course.

Stages hand-written in tool/lessons_src/<module>_stage*.json are kept as they
are (interactive steps: choice, concepts, contrast, practice …). The rest of
the module's study guide is chunked automatically: each chapter becomes one or
more lessons (split at its main headings, ~1,100 words max), and each lesson a
row of short "read" cards (split at sub-headings, ~260 words max) that point
back into the guide by block range, so translations follow automatically.

Usage: python3 tool/build_lessons.py [writing]
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PLANS = {
    # (stage id, en title, bn title, en subtitle, chapter ids). Stage 1 of
    # every module is hand-written (tool/lessons_src/<module>_stage1.json).
    'writing': [
        ('w2', 'Marking and Bands', 'Marking ও Band', 'Read your writing through the examiner’s eyes',
         ['intro_marking']),
        ('w3', 'Task 1: Rules and Line Graphs', 'Task 1: নিয়ম ও Line Graph', 'Ground rules, then line graphs step by step',
         ['t1_rules', 't1_line_intro_overview', 't1_line_body', 't1_line_double', 't1_line_complex']),
        ('w4', 'Task 1: Other Visuals', 'Task 1: অন্যান্য Visual', 'Bar charts, tables, pies, processes and maps',
         ['t1_bar', 't1_table', 't1_pie', 't1_combination', 't1_process', 't1_map', 't1_sample_lessons']),
        ('w5', 'Task 2: Questions and Planning', 'Task 2: প্রশ্ন ও Plan', 'Recognise the question type and plan your essay',
         ['t2_rules', 't2_arg_plan']),
        ('w6', 'Task 2: Writing the Essay', 'Task 2: Essay লেখা', 'Body, conclusion and every essay type',
         ['t2_arg_write', 't2_narrative', 't2_combination', 't2_sample_lessons']),
        ('w7', 'Vocabulary and Practice', 'Vocabulary ও Practice', 'Topic words, exercises and a weekly plan',
         ['vocab_topic_words', 'practice_exercises']),
    ],
    'speaking': [
        ('s2', 'The Four Criteria in Depth', 'চারটি Criteria বিস্তারিত', 'Fluency, vocabulary, grammar and pronunciation',
         ['sp_fluency_coherence', 'sp_lexical_resource', 'sp_grammatical_range_accuracy', 'sp_pronunciation_accent']),
        ('s3', 'Test Day and Top Tips', 'Test Day ও সেরা Tips', 'What happens on the day, and ten habits that lift your band',
         ['sp_ch_2', 'sp_10_speaking_tips']),
        ('s4', 'Part 1: Introduction and Interview', 'Part 1: Introduction ও Interview', 'Short answers that still show your range',
         ['sp_part_1', 'sp_part_1_2']),
        ('s5', 'Part 2: The Cue Card', 'Part 2: Cue Card', 'One-minute notes and a two-minute talk',
         ['sp_part_2_cue_card', 'sp_1_note', 'sp_2_talk', 'sp_2']),
        ('s6', 'Part 3: Discussion', 'Part 3: Discussion', 'Question types and the A.R.E + Balance framework',
         ['sp_part_3_discussion', 'sp_part_3_8', 'sp_a_r_e_balance_part_3_framewo', 'sp_worked_example_topic_part_3']),
        ('s7', 'Practice and the Final Week', 'Practice ও শেষ সপ্তাহ', 'How to practise, and your last-week checklist',
         ['sp_part_2_3_practice', 'sp_checklist', 'sp_ch']),
    ],
    'reading': [
        ('r2', 'Skills, Time and Question Types', 'Skill, সময় ও প্রশ্নের ধরন', 'The core skills, a 60-minute plan and the 14 types',
         ['skills', 'time', 'types']),
        ('r3', 'Mistakes, Practice and Test Day', 'ভুল, Practice ও Test Day', 'What costs the most marks and how to prepare',
         ['mistakes', 'plan', 'testday', 'intro']),
    ],
    'listening': [
        ('l2', 'Prediction and Paraphrase', 'Prediction ও Paraphrase', 'Keywords, prediction and recognising paraphrase',
         ['l01_foundations_practice', 'l02_prediction', 'l02_prediction_practice']),
        ('l3', 'Signposts and Distractors', 'Signpost ও Distractor', 'Follow the speaker and avoid the traps',
         ['l03_distractors', 'l03_distractors_practice']),
        ('l4', 'Completion Questions', 'Completion প্রশ্ন', 'Forms, notes, tables, sentences and summaries',
         ['l04_completion', 'l04_completion_practice']),
        ('l5', 'Selection and Matching', 'Selection ও Matching', 'Multiple choice, matching, maps and diagrams',
         ['l05_selection_1', 'l05_selection_2', 'l05_selection_practice']),
        ('l6', 'Recovery and Time Strategy', 'Recovery ও সময়ের Strategy', 'What to do when you miss an answer',
         ['l06_recovery', 'l06_recovery_practice']),
        ('l7', 'Practice and Module Close', 'Practice ও শেষ কথা', 'Put everything together',
         ['l07_practice']),
    ],
    'grammar': [
        ('g2', 'Agreement Practice and Tenses', 'Agreement Practice ও Tense', 'Lock in agreement, then master time',
         ['g01_agreement_practice', 'g02_tenses_1', 'g02_tenses_2', 'g02_tenses_practice']),
        ('g3', 'Articles and Nouns', 'Article ও Noun', 'A, an, the - and countable vs uncountable',
         ['g03_articles', 'g03_articles_practice']),
        ('g4', 'Prepositions', 'Preposition', 'Dependent prepositions and the rules behind them',
         ['g04_prepositions', 'g04_prepositions_practice']),
        ('g5', 'Complex Sentences', 'Complex বাক্য', 'Subordinate clauses for Band 7+',
         ['g05_complex', 'g05_complex_practice']),
        ('g6', 'The Passive Voice', 'Passive Voice', 'Academic detachment, used correctly',
         ['g06_passive', 'g06_passive_practice']),
        ('g7', 'Conditionals and Hedging', 'Conditional ও Hedging', 'Hypotheticals and cautious claims',
         ['g07_conditionals', 'g07_conditionals_practice']),
        ('g8', 'Inversion and Emphasis', 'Inversion ও Emphasis', 'Cleft sentences and advanced emphasis',
         ['g08_inversion', 'g08_inversion_practice']),
        ('g9', 'Nominalisation', 'Nominalisation', 'Academic density without losing clarity',
         ['g09_nominalisation', 'g09_nominalisation_practice']),
        ('g10', 'Editing and Exam Routine', 'Editing ও Exam Routine', 'Polish full essays and speaking transcripts',
         ['g10_editing', 'g10_editing_practice', 'g11_review']),
    ],
    'vocab': [
        ('v2', 'More L1 Errors and Practice', 'আরও L1 ভুল ও Practice', 'Errors 11–30, then spot and fix',
         ['v1_errors_2', 'v1_errors_3', 'v1_practice']),
        ('v3', 'The Band Upgrade Matrix', 'Band Upgrade Matrix', 'Swap common words for precise ones',
         ['v2_intro', 'v2_matrix_1', 'v2_matrix_2', 'v2_matrix_3', 'v2_matrix_4', 'v2_practice']),
        ('v4', 'Verbs and Linking Words', 'Verb ও Linking Word', '100 high-impact verbs and better connectors',
         ['v3_verbs_1', 'v3_verbs_2', 'v3_linking', 'v3_practice']),
        ('v5', 'Topic Vocabulary 1–5', 'Topic Vocabulary ১–৫', 'Environment, education, technology, health, crime',
         ['v4_intro', 'v4_topic_01', 'v4_topic_02', 'v4_topic_03', 'v4_topic_04', 'v4_topic_05']),
        ('v6', 'Topic Vocabulary 6–10', 'Topic Vocabulary ৬–১০', 'Globalisation, cities, business, arts, media',
         ['v4_topic_06', 'v4_topic_07', 'v4_topic_08', 'v4_topic_09', 'v4_topic_10']),
        ('v7', 'Topic Vocabulary 11–15', 'Topic Vocabulary ১১–১৫', 'Government, transport, family, science, tourism',
         ['v4_topic_11', 'v4_topic_12', 'v4_topic_13', 'v4_topic_14', 'v4_topic_15']),
        ('v8', 'Idioms and Register', 'Idiom ও Register', 'Idioms for Speaking, collocations for Writing',
         ['v5_rule', 'v5_idioms_1', 'v5_idioms_2', 'v5_collocations_1', 'v5_collocations_2', 'v5_practice']),
        ('v9', 'Workbook: Rewrites', 'Workbook: Rewrite', 'Sentence transformations and five essay rewrites',
         ['v6_intro', 'v6_transformations', 'v6_essay_1', 'v6_essay_2', 'v6_essay_3', 'v6_essay_4', 'v6_essay_5']),
        ('v10', 'Workbook: Speaking Simulations', 'Workbook: Speaking Simulation', 'Five full Part 2 simulations',
         ['v6_speaking_1', 'v6_speaking_2', 'v6_speaking_3', 'v6_speaking_4', 'v6_speaking_5']),
    ],
}

LESSON_MAX = 1100
LESSON_MIN = 300
CARD_MAX = 260


def words(block):
    return len(re.findall(r"[A-Za-z0-9']+", json.dumps(block[1:], ensure_ascii=False)))


def split_at(blocks, start, end, kinds):
    """Index ranges [a, b) inside [start, end) starting at blocks of `kinds`."""
    cuts = [i for i in range(start, end) if blocks[i][0] in kinds and i != start]
    edges = [start] + cuts + [end]
    return [(edges[k], edges[k + 1]) for k in range(len(edges) - 1) if edges[k] < edges[k + 1]]


def merge(ranges, blocks, lo, hi):
    """Joins neighbouring ranges until each is at least `lo` words (max `hi`)."""
    out = []
    for a, b in ranges:
        w = sum(words(x) for x in blocks[a:b])
        if out:
            pa, pb, pw = out[-1]
            if pw < lo or (w < lo / 2 and pw + w <= hi):
                out[-1] = (pa, b, pw + w)
                continue
        out.append((a, b, w))
    if len(out) > 1 and out[-1][2] < lo / 2:
        a, b, w = out.pop()
        pa, pb, pw = out[-1]
        out[-1] = (pa, b, pw + w)
    return out


def clean_title(t, heading=False):
    """Drops the book's own numbering ("2. Tense Mastery", and for headings
    "2 The complete map …") - the app numbers lessons itself."""
    t = re.sub(r'^\d+(\.\d+)*\.\s+', '', t.strip())
    if heading:
        t = re.sub(r'^\d+(\.\d+)*\.?\s+(?=[A-Z])', '', t)
    return t.strip()


def heading(blocks, a, b):
    for i in range(a, b):
        if blocks[i][0] in ('h', 'h2'):
            return i, clean_title(blocks[i][1], heading=True)
    return None, ''


def cards(blocks, a, b):
    """Card ranges: split at h / h2, merged up to CARD_MAX words; big
    single sections are split further at paragraph boundaries."""
    out = []
    for ca, cb, w in merge(split_at(blocks, a, b, ('h', 'h2')), blocks, 60, CARD_MAX):
        if w <= CARD_MAX * 1.6:
            out.append((ca, cb))
            continue
        start, acc = ca, 0
        for i in range(ca, cb):
            acc += words(blocks[i])
            if acc >= CARD_MAX and i + 1 < cb:
                out.append((start, i + 1))
                start, acc = i + 1, 0
        if start < cb:
            out.append((start, cb))
    return out


def auto_lessons(module, chapter, n0):
    blocks = chapter['blocks']
    ranges = split_at(blocks, 0, len(blocks), ('h',))
    lessons = []
    for k, (a, b, w) in enumerate(merge(ranges, blocks, LESSON_MIN, LESSON_MAX)):
        hi, htext = heading(blocks, a, b)
        title = clean_title(chapter['title']) if (k == 0 or not htext) else htext
        steps = []
        for ca, cb in cards(blocks, a, b):
            ci, ctext = heading(blocks, ca, cb)
            step = {'type': 'read', 'chapter': chapter['id'], 'from': ca, 'to': cb}
            if ctext:
                step['title'] = {'ref': [chapter['id'], ci], 'en': ctext}
            steps.append(step)
        exercises = sum(1 for x in blocks[a:b] if x[0] == 'exercise')
        lessons.append({
            'id': f"{chapter['id']}_{k + 1}",
            'title': ({'chapterTitle': chapter['id'], 'en': title} if k == 0 or not htext
                      else {'ref': [chapter['id'], hi], 'en': title}),
            'minutes': max(3, round(w / 160) + 1),
            'xp': 20 + 5 * min(len(steps), 6),
            'auto': True,
            'steps': steps,
            'practice': exercises,
        })
    return lessons


def tidy(lessons):
    return _fold(_split(_fold(lessons)))


def _fold(lessons):
    """Splits lessons with too many cards (≤ 6 each, "· Part 2") and folds a
    one-card lesson into the previous one when that stays ≤ 7 cards."""
    out = []
    for l in lessons:
        if (out and len(l['steps']) == 1 and len(out[-1]['steps']) <= 6
                and l['steps'][0].get('chapter') == out[-1]['steps'][-1].get('chapter')):
            prev = out[-1]
            prev['steps'] += l['steps']
            prev['minutes'] += l['minutes']
            prev['practice'] += l['practice']
            prev['xp'] = 20 + 5 * min(len(prev['steps']), 6)
            continue
        out.append(l)
    return out


def _split(lessons):
    final = []
    for l in lessons:
        n = len(l['steps'])
        if n <= 7:
            final.append(l)
            continue
        parts = -(-n // 6)
        size = -(-n // parts)
        for k in range(parts):
            chunk = l['steps'][k * size:(k + 1) * size]
            part = dict(l)
            part['id'] = l['id'] if k == 0 else f"{l['id']}p{k + 1}"
            part['steps'] = chunk
            part['minutes'] = max(3, round(l['minutes'] * len(chunk) / n))
            part['xp'] = 20 + 5 * min(len(chunk), 6)
            part['practice'] = l['practice'] if k == parts - 1 else 0
            if k:
                t = dict(l['title'])
                t['part'] = k + 1
                part['title'] = t
            final.append(part)
    return final


def build(module):
    guide = json.load(open(os.path.join(ROOT, 'assets', 'content', f'{module}_guide.json')))
    by_id = {c['id']: c for c in guide['chapters']}
    stages = []
    for src in sorted(glob.glob(os.path.join(ROOT, 'tool', 'lessons_src', f'{module}_stage*.json'))):
        stages.append(json.load(open(src)))
    for sid, en, bn, sub, chapters in PLANS.get(module, []):
        lessons = []
        for cid in chapters:
            lessons.extend(auto_lessons(module, by_id[cid], len(lessons)))
        lessons = tidy(lessons)
        stages.append({'id': sid, 'title': {'en': en, 'bn': bn}, 'subtitle': {'en': sub}, 'lessons': lessons})
    # Hand-written quick checks for auto lessons: {lessonId: {intro?, checks: [choice …]}}
    # - each check goes after the reading card it follows (`after`: card index,
    # default: the end), the intro becomes the lesson's cover line.
    extra = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'tool', 'lessons_src', f'{module}_checks*.json'))):
        extra.update(json.load(open(path)))
    if extra:
        for s in stages:
            for l in s['lessons']:
                e = extra.get(l['id'])
                if not e:
                    continue
                if e.get('intro'):
                    l['intro'] = e['intro']
                if e.get('learned'):
                    l['learned'] = e['learned']
                steps = list(l['steps'])
                placed = sorted(e.get('checks', []), key=lambda c: c.get('after', len(steps)), reverse=True)
                for c in placed:
                    at = min(max(int(c.get('after', len(steps))), 0), len(steps))
                    step = {k: v for k, v in c.items() if k != 'after'}
                    step.setdefault('type', 'choice')
                    steps.insert(at, step)
                l['steps'] = steps
                l['xp'] = l['xp'] + 5 * len(e.get('checks', []))
        unknown = set(extra) - {l['id'] for s in stages for l in s['lessons']}
        assert not unknown, f'checks for unknown lessons: {sorted(unknown)}'
    # Sanity: read ranges inside their chapter, answers inside the options,
    # known step types, unique ids, practice prompts that exist.
    known = {'choice', 'roadmap', 'concepts', 'contrast', 'read', 'practice', 'sampleFeedback'}
    wbank = json.load(open(os.path.join(ROOT, 'assets', 'content', 'writing_bank.json')))
    prompt_ids = {q['id'] for k in ('task1', 'task2') for q in wbank.get(k, [])}
    home = open(os.path.join(ROOT, 'lib', 'features', 'home', 'widgets.dart')).read()
    targets = set(re.findall(r"case '([A-Za-z0-9]+)':", home[home.index('String homeRouteFor'):home.index('void openHomeTarget')]))
    ids = set()
    for s in stages:
        for l in s['lessons']:
            assert l['id'] not in ids, l['id']
            ids.add(l['id'])
            for st in l['steps']:
                assert st['type'] in known, (l['id'], st['type'])
                if st['type'] == 'read':
                    n = len(by_id[st['chapter']]['blocks'])
                    assert 0 <= st['from'] < st['to'] <= n, (l['id'], st)
                if st['type'] == 'choice':
                    assert 0 <= st['answer'] < len(st['options']), (l['id'], st['title'])
                if st['type'] == 'practice' and st.get('promptId'):
                    assert st['promptId'] in prompt_ids, (l['id'], st['promptId'])
                if st['type'] == 'practice':
                    for it in st.get('items', []):
                        if it.get('target'):
                            assert it['target'] in targets, (l['id'], it['target'])
                if st['type'] == 'concepts':
                    assert st.get('cards'), (l['id'], 'concepts without cards')
                if st['type'] == 'contrast':
                    assert st.get('weak', {}).get('text') and st.get('strong', {}).get('text'), (l['id'], 'contrast')
    # Nepali / Arabic / Indonesian for the hand-written text: tool/lessons_src/l10n/<lang>_*.json
    # ({english: translation}) - added wherever a text has "en" + "bn".
    tr = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'tool', 'lessons_src', 'l10n', '*_*.json'))):
        lang = os.path.basename(path).split('_')[0]
        if lang in ('ne', 'ar', 'id'):
            tr.setdefault(lang, {}).update(json.load(open(path)))

    def add_langs(x):
        if isinstance(x, dict):
            if 'en' in x and 'bn' in x and isinstance(x['en'], str):
                for lang, table in tr.items():
                    t = table.get(x['en'])
                    if isinstance(t, str) and t.strip():
                        x[lang] = t
            for v in x.values():
                add_langs(v)
        elif isinstance(x, list):
            for v in x:
                add_langs(v)

    add_langs(stages)

    # Concept cards and roadmap rows sit next to a numbered badge already.
    num = re.compile(r'^[0-9০-৯०-९٠-٩]+[.।)]\s+')
    for st in stages:
        for l in st['lessons']:
            for step in l['steps']:
                for card in step.get('cards', []) if step['type'] == 'concepts' else []:
                    t = card.get('title')
                    if isinstance(t, dict):
                        card['title'] = {k: num.sub('', v) if isinstance(v, str) else v for k, v in t.items()}
    out = {'module': module, 'title': guide['title'], 'stages': stages}
    os.makedirs(os.path.join(ROOT, 'assets', 'content', 'lessons'), exist_ok=True)
    path = os.path.join(ROOT, 'assets', 'content', 'lessons', f'{module}.json')
    json.dump(out, open(path, 'w'), ensure_ascii=False, separators=(',', ':'))
    total = sum(len(s['lessons']) for s in stages)
    print(f"{module}: {len(stages)} stages, {total} lessons → {os.path.relpath(path, ROOT)}")
    for s in stages:
        print('  ', s['id'], s['title']['en'], '·', len(s['lessons']), 'lessons:',
              ', '.join(f"{l['title'].get('en')}{' ·' + str(l['title']['part']) if l['title'].get('part') else ''} ({len(l['steps'])})" for l in s['lessons']))


if __name__ == '__main__':
    for m in (sys.argv[1:] or ['writing', 'speaking', 'reading', 'listening', 'grammar', 'vocab']):
        build(m)
