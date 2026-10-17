#!/usr/bin/env python3
"""Listening Full Test script (seed/sources/listening_full_tests/FT0N.json, the ElevenLabs v4
script with question_groups) → the website format the importer reads
(seed/sources/web_tests/listening/full/FT0N.json).

usage: python3 tool/convert_full_test.py FT04 [FT05 …]
       python3 tool/convert_full_test.py --check     (rebuilds FT01/02/03/06/07 and compares)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.environ.get('FULL_RAW', os.path.join(ROOT, 'seed', 'sources', 'listening_full_tests'))
WEB = os.path.join(ROOT, 'seed', 'sources', 'web_tests', 'listening', 'full')

TYPES = {
    'note_completion': 'notes', 'form_completion': 'form', 'table_completion': 'table',
    'summary_completion': 'summary', 'flow_chart_completion': 'notes', 'sentence_completion': 'notes',
    'multiple_choice': 'mcq', 'multi_select': 'multi', 'matching': 'matching', 'map_labelling': 'map',
}
TEXT = {'notes', 'form', 'table', 'summary'}


def clean(text):
    """Script line → transcript line: audio tags like [warm] dropped."""
    t = re.sub(r'\[[^\]]*\]', '', text)
    t = re.sub(r'\s*"/[^"/]*/"', '', t)  # pronunciation hints for the voice: Niamh "/niːv/"
    return re.sub(r'\s+', ' ', t).strip()


def prompt(text):
    """"the (21) ___" → "the ___"; flow-chart arrows dropped."""
    t = re.sub(r'\(\d+\)\s*(?=_)', '', text)
    return re.sub(r'^\s*[↓→]\s*', '', t).strip()


def accepted(item):
    out = []
    for a in [item['answer'], *item.get('accepted', [])]:
        if a and a not in out:
            out.append(a)
    return out


def opts(d):
    return [{'key': k, 'text': v} for k, v in d.items()]


def group(g, gid, first):
    kind = TYPES[g['type']]
    instr = g.get('instructions', '').strip()
    num = lambda n: n - first + 1
    out = {'id': gid, 'type': kind}
    if kind in TEXT:
        def q(it):
            acc = accepted(it)
            src = prompt(it['prompt'])
            return {'number': num(it['n']), 'text': src.replace('___', '______'), 'source': src,
                    'answer': it['answer'], 'answerDisplay': ' / '.join(acc), 'accepted': acc}
        if kind == 'form':
            m = re.match(r'(Complete the [a-z ]+? below)\.\s*(.*)', instr)
            out.update(title='Complete the form', instruction=m.group(2) if m else instr,
                       formTitle=g.get('heading', ''), formSubtitle='', questions=[])
            for it in g['items']:
                acc = accepted(it)
                src = prompt(it['prompt'])
                label, colon, rest = src.partition(':')
                if not colon:
                    # "Bag was placed on the ___": the words before the gap are the label
                    label, _, rest = src.partition('___')
                    rest = '___' + rest
                before, _, after = rest.partition('___')
                out['questions'].append({'number': num(it['n']), 'label': label.strip(), 'before': before.strip(),
                                         'after': after.strip(), 'answer': it['answer'],
                                         'answerDisplay': ' / '.join(acc), 'accepted': acc})
            return out
        out.update(title=g.get('heading', ''), instruction=instr, questions=[q(it) for it in g['items']])
        return out
    if kind == 'mcq':
        out.update(title='Choose the correct letter, A, B or C', instruction='',
                   questions=[{'number': num(it['n']), 'text': it['prompt'], 'options': opts(it['options']),
                               'answer': it['answer']} for it in g['items']])
        return out
    if kind == 'multi':
        title = instr.rstrip('.')
        n0 = num(g['items'][0]['n'])
        out.update(title=title, instruction=instr, pick=len(g['answers']),
                   questions=[{'number': n0, 'text': g['items'][0]['prompt'], 'options': opts(g['options']),
                               'answer': list(g['answers']),
                               'answerKey': {str(i + 1): f'{a} (in either order)' for i, a in enumerate(g['answers'])}}])
        return out
    if kind == 'matching':
        m = re.match(r'(.*?\?)\s*(.*)', instr)
        out.update(title=m.group(1) if m else instr, instruction=m.group(2) if m else '', options=opts(g['options']),
                   questions=[{'number': num(it['n']), 'text': it['prompt'], 'answer': it['answer']} for it in g['items']])
        return out
    if kind == 'map':
        letters = sorted({it['answer'] for it in g['items']} | set(re.findall(r'\b([A-Z]) = ', g.get('layout', ''))))
        out.update(title=g.get('heading', ''), instruction=instr, image='__PLAN__', layoutIntro='',
                   options=[{'key': k, 'text': ''} for k in letters],
                   questions=[{'number': num(it['n']), 'text': it['prompt'], 'answer': it['answer']} for it in g['items']])
        return out
    raise ValueError(g['type'])


def convert(raw):
    parts = []
    for p in raw['parts']:
        first = int(p['question_groups'][0]['range'].split('-')[0])
        speakers = []
        for v in p.get('voices', []):
            if v['label'] == 'Narrator':
                continue
            role = v.get('desc', '').split(' — ')[0].strip()
            speakers.append({'name': v['label'], 'role': role})
        plan = None
        for g in p['question_groups']:
            if g['type'] == 'map_labelling':
                plan = {'title': g.get('heading', ''), 'description': g.get('layout', '')}
        parts.append({
            'part': p['part'], 'title': p['title'], 'context': p.get('scenario', ''), 'speakers': speakers,
            'transcript': [{'speaker': x['speaker'], 'text': clean(x['text'])} for x in p['script'] if clean(x['text'])],
            'plan': plan,
            'groups': [group(g, f'g{i + 1}', first) for i, g in enumerate(p['question_groups'])],
        })
    return {'test': raw['id'], 'title': raw['title'], 'parts': parts}


def main(argv):
    if argv == ['--check']:
        bad = 0
        for code in ['FT01', 'FT02', 'FT03', 'FT06', 'FT07']:
            got = convert(json.load(open(os.path.join(RAW, f'{code}.json'), encoding='utf-8')))
            want = json.load(open(os.path.join(WEB, f'{code}.json'), encoding='utf-8'))
            if got != want:
                bad += 1
                print('DIFF', code)
        return bad
    for code in argv:
        out = convert(json.load(open(os.path.join(RAW, f'{code}.json'), encoding='utf-8')))
        json.dump(out, open(os.path.join(WEB, f'{code}.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print('wrote', code)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
