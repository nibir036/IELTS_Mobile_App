#!/usr/bin/env python3
"""Build assets/content/reading_bank.json for the app from the seed files.

Input:  seed/data/27_reading_bank_passages.json (280 sets)
        seed/data/28_reading_type_lessons.json  (14 "How to attempt" lessons)
        seed/data/29_reading_practice_tests.json (20 short tests)
Output: assets/content/reading_bank.json  {passages, lessons, tests}  (minified)

Diagram-label sets get "diagram": "assets/diagrams/app/diagram_label_NN.webp".
The WebP copies (about 1.4 MB for all 20, instead of 11 MB of PNG) are made
here from the reviewed PNG masters in assets/diagrams/ (needs Pillow). Run again after re-importing the bank:
    python tool/build_reading_bank_asset.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'seed', 'data')


def items(name):
    with open(os.path.join(DATA, name), encoding='utf-8') as f:
        return json.load(f)['items']


passages = items('27_reading_bank_passages.json')
lessons = items('28_reading_type_lessons.json')
tests = items('29_reading_practice_tests.json')

missing = []
for p in passages:
    if p['questionType'] == 'diagram_label':
        src = os.path.join(ROOT, 'assets', 'diagrams', 'diagram_label_%02d.png' % p['bankSet'])
        rel = 'assets/diagrams/app/diagram_label_%02d.webp' % p['bankSet']
        dst_img = os.path.join(ROOT, rel)
        if os.path.exists(src):
            if not os.path.exists(dst_img) or os.path.getmtime(dst_img) < os.path.getmtime(src):
                from PIL import Image
                os.makedirs(os.path.dirname(dst_img), exist_ok=True)
                Image.open(src).convert('RGB').save(dst_img, 'WEBP', quality=88, method=6)
            p['diagram'] = rel
        else:
            missing.append(src)

# Sanity: every practice-test passage exists.
ids = {p['id'] for p in passages}
for t in tests:
    for pid in t['passages']:
        assert pid in ids, (t['id'], pid)

out_dir = os.path.join(ROOT, 'assets', 'content')
os.makedirs(out_dir, exist_ok=True)
dst = os.path.join(out_dir, 'reading_bank.json')
with open(dst, 'w', encoding='utf-8') as f:
    json.dump({'passages': passages, 'lessons': lessons, 'tests': tests}, f,
              ensure_ascii=False, separators=(',', ':'))
print('wrote', dst, os.path.getsize(dst), 'bytes;', len(passages), 'passages,',
      len(lessons), 'lessons,', len(tests), 'tests;',
      'missing diagrams: %s' % missing if missing else 'all 20 diagrams linked')
