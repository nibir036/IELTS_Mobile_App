"""Export the English sources for translation (seed/staging/l10n/reading/src/).

usage: python3 tool/export_l10n_src.py
Writes the parts that live in demo_data.json (library passages, skill lessons, tips) and the in-app Reading
Guide (assets/content/reading_guide.json). The bank sources (passages_NN.json, type_lessons.json) were
exported once from assets/content/reading_bank.json and are left untouched.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'seed' / 'staging' / 'l10n' / 'reading' / 'src'


def write(name, data):
    (SRC / name).write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding='utf-8')
    print(name, len(data))


def main():
    demo = json.loads((ROOT / 'assets' / 'demo' / 'demo_data.json').read_text(encoding='utf-8'))
    SRC.mkdir(parents=True, exist_ok=True)
    lib = []
    for p in demo['content']['reading']['passages']:
        qs = [q for g in p.get('groups', []) for q in g.get('questions', [])]
        lib.append({'id': p['id'], 'title': p.get('title', ''), 'questions': [
            {'n': q['number'], 'q': q.get('text', ''), 'answer': q.get('answer'), 'evidence': q.get('evidence', ''),
             'explanation': q['explanation']} for q in qs if q.get('explanation')]})
    write('library_passages.json', lib)
    write('skill_lessons.json', [
        {'id': l['id'], 'title': l['title'], 'keyIdea': l['keyIdea'],
         'uses': [{'label': u['label'], 'value': u['value']} for u in l.get('uses', [])]}
        for l in demo['reading']['lessons']])
    write('tips.json', [
        {'id': a['id'], 'chip': a['chip'], 'title': a['title'],
         'tips': [{'title': t['title'], 'body': t['body']} for t in a['tips']],
         'tryIt': a.get('tryIt', {}).get('text', '')}
        for a in demo['resources']['articles'] if a['series'] == 'reading'])
    guide = ROOT / 'assets' / 'content' / 'reading_guide.json'
    if guide.exists():
        write('guide.json', json.loads(guide.read_text(encoding='utf-8'))['chapters'])


if __name__ == '__main__':
    main()
