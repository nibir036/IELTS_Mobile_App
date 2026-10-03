"""Parse sir's speaking HTML files (seed/sources/speaking/) into plain dicts.

Answers keep vocabulary marks as [[word]] (from the <w> tags).
Run directly to dump the parsed base data to seed/staging/speaking/base/.
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'seed' / 'sources' / 'speaking'
BASE = ROOT / 'seed' / 'staging' / 'speaking' / 'base'

P2_FILES = [
    ('people', 'People', 'part2_01_people.html'),
    ('places', 'Places', 'part2_02_places.html'),
    ('experiences', 'Experiences', 'part2_03_experiences.html'),
    ('objects', 'Objects', 'part2_04_objects.html'),
    ('activities', 'Activities & Ideas', 'part2_05_activities_abstract.html'),
]
P3_FILES = [
    ('people', 'People & Relationships', 'part3_01_people_relationships.html'),
    ('education', 'Education & Work', 'part3_02_education_work.html'),
    ('technology', 'Technology & Media', 'part3_03_technology_media.html'),
    ('culture', 'Culture & Lifestyle', 'part3_04_culture_lifestyle.html'),
    ('environment', 'Environment & Cities', 'part3_05_environment_urban.html'),
    ('society', 'Society & Values', 'part3_06_society_values.html'),
]
P1_CATS = [
    ('personal', 'Personal & Background'),
    ('lifestyle', 'Lifestyle & Habits'),
    ('interests', 'Interests & Hobbies'),
    ('culture', 'Entertainment & Culture'),
    ('daily', 'Daily Life & Opinions'),
]
TAGS = {
    'Opinion': 'opinion', 'Comparison': 'comparison', 'Cause & Effect': 'cause-effect',
    'Social Impact': 'social-impact', 'Future': 'future', 'Problem & Solution': 'problem-solution',
    'Adv & Disadv': 'adv-disadv', 'Agree / Disagree': 'agree-disagree',
}


def text(s: str) -> str:
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', '', s))).strip()


def marked(s: str) -> str:
    s = re.sub(r'<w>(.*?)</w>', lambda m: '[[' + text(m.group(1)) + ']]', s, flags=re.S)
    return text(s)


def marks(s: str) -> list:
    return re.findall(r'\[\[(.+?)\]\]', s)


def slug(s: str) -> str:
    return re.sub(r'[^a-z0-9]+', '-', s.lower().replace('&', 'and')).strip('-')


def part1() -> list:
    t = (SRC / 'speaking_part1_bank.html').read_text(encoding='utf-8')
    out = []
    for ci, chunk in enumerate(re.split(r'<h2>', t)[1:]):
        cat, label = P1_CATS[ci]
        for m in re.finditer(r'<div class="item">(.*?)</p></div>', chunk, re.S):
            it = m.group(1)
            n = int(re.search(r'class="num">(\d+)', it).group(1))
            topic = text(re.search(r'class="topic">(.*?)</div>', it).group(1))
            q = text(re.search(r'class="qtext">(.*?)</div>', it).group(1))
            ans = marked(re.search(r'class="ans">(.*)', it, re.S).group(1))
            out.append({
                'id': f'sp1_{n:03d}', 'number': n, 'category': cat, 'categoryLabel': label,
                'topic': topic,
                'questions': [{'q': q, 'answer': ans, 'vocab': marks(ans)}],
            })
    return out


def part2() -> list:
    out = []
    for cat, label, fn in P2_FILES:
        t = (SRC / fn).read_text(encoding='utf-8')
        for i, m in enumerate(re.finditer(r'<div class="card">(.*?)</p></div>', t, re.S), 1):
            c = m.group(1)
            ans = marked(re.search(r'class="ans">(.*?)</p>', c, re.S).group(1))
            out.append({
                'id': f'sp2_{cat}_{i:02d}', 'category': cat, 'categoryLabel': label,
                'number': int(re.search(r'class="num">(\d+)', c).group(1)),
                'title': text(re.search(r'class="title">(.*?)</div>', c).group(1)),
                'bullets': [text(b) for b in re.findall(r'<li>(.*?)</li>', c, re.S)],
                'answer': ans, 'vocab': marks(ans),
            })
    return out


def part3() -> list:
    out = []
    for cat, label, fn in P3_FILES:
        t = (SRC / fn).read_text(encoding='utf-8')
        for tp in re.split(r'<div class="topic">', t)[1:]:
            h = text(re.search(r'<h2>(.*?)</h2>', tp, re.S).group(1))
            dm = re.search(r'</h2>\s*<p>(.*?)</p>', tp, re.S)
            n, name = re.match(r'(\d+)\.\s*(.*)', h).groups()
            qs = []
            for qi, q in enumerate(re.findall(r'<div class="q">(.*?)</p></div>', tp, re.S), 1):
                tag = text(re.search(r'class="tag">(.*?)</span>', q).group(1))
                ans = marked(re.search(r'class="ans">(.*?)</p>', q, re.S).group(1))
                line = text(re.search(r'Vocabulary:</b>(.*)', q, re.S).group(1))
                qs.append({
                    'n': qi, 'tag': TAGS[tag], 'tagLabel': tag,
                    'q': text(re.search(r'class="qtext">(.*?)</div>', q).group(1)),
                    'answer': ans, 'vocab': marks(ans),
                    'sourceVocabLine': [v.strip() for v in line.split('·') if v.strip()],
                })
            out.append({
                'id': f'sp3_{cat}_{int(n):02d}', 'category': cat, 'categoryLabel': label,
                'number': int(n), 'topic': name, 'description': text(dm.group(1)) if dm else '', 'questions': qs,
            })
    return out


if __name__ == '__main__':
    BASE.mkdir(parents=True, exist_ok=True)
    data = {'part1': part1(), 'part2': part2(), 'part3': part3()}
    for k, v in data.items():
        (BASE / f'{k}.json').write_text(json.dumps(v, ensure_ascii=False, indent=1), encoding='utf-8')
    p3q = sum(len(t['questions']) for t in data['part3'])
    print(f"part1 {len(data['part1'])} · part2 {len(data['part2'])} · part3 {len(data['part3'])} topics / {p3q} qs")
    sys.exit(0)
