"""Build assets/content/l10n/<lang>/reading.json (+ index.json) from seed/staging/l10n/reading/<lang>/.

usage: python3 tool/build_l10n.py
Only languages that pass tool/check_l10n.py are built. English is the source (the banks themselves).
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ST = ROOT / 'seed' / 'staging' / 'l10n' / 'reading'
OUT = ROOT / 'assets' / 'content' / 'l10n'
LANGS = ['bn', 'ne', 'ar', 'id']
SCRIPTS = {'bn': re.compile(r'[ঀ-৿]'), 'ne': re.compile(r'[ऀ-ॿ]'), 'ar': re.compile(r'[؀-ۿ]'), 'id': None}


def build(lang):
    d = ST / lang
    if not d.exists():
        return None
    ok = subprocess.run([sys.executable, str(ROOT / 'tool' / 'check_l10n.py'), lang], capture_output=True, text=True)
    if ok.returncode != 0:
        print(f'{lang}: skipped (check_l10n errors)\n{ok.stdout[:400]}')
        return None
    passages = {}
    for f in sorted(d.glob('passages_*.json')):
        for p in json.loads(f.read_text(encoding='utf-8')):
            passages[p['id']] = {'lesson': p['lesson'], 'explanations': p['explanations']}
    lib = d / 'library_passages.json'
    if lib.exists():
        for p in json.loads(lib.read_text(encoding='utf-8')):
            passages[p['id']] = {'explanations': p['explanations']}

    def by_id(name, keep):
        f = d / name
        if not f.exists():
            return {}
        return {x['id']: {k: x[k] for k in keep if k in x} for x in json.loads(f.read_text(encoding='utf-8'))}

    extra = {
        'skillLessons': by_id('skill_lessons.json', ('title', 'keyIdea', 'uses')),
        'tips': by_id('tips.json', ('title', 'tips', 'tryIt')),
        'guide': by_id('guide.json', ('title', 'blocks')),
    }
    lessons = {x['id']: {'title': x['title'], 'sections': x['sections']}
               for x in json.loads((d / 'type_lessons.json').read_text(encoding='utf-8'))}
    out = OUT / lang
    out.mkdir(parents=True, exist_ok=True)
    (out / 'reading.json').write_text(json.dumps({'typeLessons': lessons, 'passages': passages, **extra}, ensure_ascii=False,
                                                 separators=(',', ':')), encoding='utf-8')
    n = sum(len(p['explanations']) for p in passages.values())
    print(f'{lang}: {len(lessons)} type lessons · {len(passages)} passages · {n} explanations · '
          f'{len(extra["skillLessons"])} skill lessons · {len(extra["tips"])} tips · {len(extra["guide"])} guide chapters · '
          f'{(out / "reading.json").stat().st_size // 1024} KB')
    return lang


GUIDES = {
    'writing': ('writing_guide', 'IELTS Academic Writing Complete Guide',
                'Task 1 and Task 2 step by step, marking and bands, vocabulary and exercises — '
                'from the nextED Writing book'),
    'grammar': ('grammar_guide', 'IELTS Grammar Course',
                'From sentence foundations to Band 9 structures: 11 chapters with rules, Bangla-speaker error fixes '
                'and exercises with answers'),
    'listening': ('listening_guide', 'IELTS Listening Guide',
                  'Zero to Band 9: the listening mindset, prediction and paraphrase, signposting and distractors, '
                  'every question type, recovery and time strategy, with drills — from the nextED field guide'),
    'vocab': ('vocab_guide', 'Vocabulary Lessons',
              'Zero to Band 9, the full nextED vocabulary book: 30 Bangla-speaker errors, the 35-word upgrade matrix, '
              '100 verbs and linking words, 15 topic bundles, idioms and register, and the full workbook — every '
              'exercise with its answer'),
    'speaking': ('speaking_guide', 'IELTS Speaking Complete Guide',
                 'Band 7+ strategy: marking criteria, fluency, vocabulary, grammar, pronunciation, '
                 'Parts 1, 2 and 3 — from the nextED Speaking book'),
}


def build_guide(module):
    """Study guide (sir's book): English → assets/content/<module>_guide.json, other languages →
    assets/content/l10n/<lang>/<module>.json {guide, tips}. Needs tool/check_writing_guide.py to pass."""
    folder, title, subtitle = GUIDES[module]
    base = ROOT / 'seed' / 'staging' / folder
    ok = subprocess.run([sys.executable, str(ROOT / 'tool' / 'check_writing_guide.py'), '--guide', folder],
                        capture_output=True, text=True)
    if ok.returncode != 0:
        print(f'{module} guide: skipped (check errors)\n{ok.stdout[:400]}')
        return []
    files = sorted((base / 'bn').glob('*.json'))
    en = [c for f in files for c in json.loads((base / 'en' / f.name).read_text(encoding='utf-8'))]
    for c in en:
        c.pop('part', None)
    (ROOT / 'assets' / 'content' / f'{module}_guide.json').write_text(
        json.dumps({'title': title, 'subtitle': subtitle, 'chapters': en}, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8')
    built = []
    for lang in LANGS:
        d = base / lang
        if not d.exists():
            continue
        if lang != 'bn':
            chk = subprocess.run([sys.executable, str(ROOT / 'tool' / 'check_writing_guide.py'), '--guide', folder,
                                  '--lang', lang], capture_output=True, text=True)
            if chk.returncode != 0:
                print(f'{lang}: {module} guide skipped (check errors)\n{chk.stdout[:400]}')
                continue
        chs = [c for f in files if (d / f.name).exists() for c in json.loads((d / f.name).read_text(encoding='utf-8'))]
        tips_f = base / f'tips_{lang}.json'
        tips = {a['id']: {'title': a['title'], 'tips': a['tips'], 'tryIt': a.get('tryIt', '')}
                for a in json.loads(tips_f.read_text(encoding='utf-8'))} if tips_f.exists() else {}
        out = OUT / lang
        out.mkdir(parents=True, exist_ok=True)
        (out / f'{module}.json').write_text(json.dumps(
            {'guide': {c['id']: {'title': c['title'], **({'group': c['group']} if c.get('group') else {}),
                                 'blocks': c['blocks']} for c in chs}, 'tips': tips},
            ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
        print(f'{lang}: {module} guide {len(chs)} chapters · {len(tips)} tip articles · '
              f'{(out / f"{module}.json").stat().st_size // 1024} KB')
        built.append(lang)
    print(f'en: {module} guide {len(en)} chapters')
    return built


def build_resources():
    """Easy Bangla (etc.) meanings of the Resources words: seed/staging/l10n/resources/<lang>/batch_*.json
    ({id: meaning}) → assets/content/l10n/<lang>/resources.json {meanings: {id: meaning}}."""
    built = []
    for lang in LANGS:
        d = ROOT / 'seed' / 'staging' / 'l10n' / 'resources' / lang
        files = sorted(d.glob('batch_*.json')) if d.exists() else []
        if not files:
            continue
        meanings = {}
        for f in files:
            meanings.update(json.loads(f.read_text(encoding='utf-8')))
        # every source id needs a non-empty meaning in the target script
        src_ids = [x['id'] for f in sorted((d.parent / 'src').glob('batch_*.json'))
                   for x in json.loads(f.read_text(encoding='utf-8'))]
        script = SCRIPTS.get(lang)
        bad = [i for i in src_ids if not str(meanings.get(i, '')).strip()
               or (script is not None and not script.search(meanings[i]))]
        if bad:
            print(f'{lang}: resources skipped — {len(bad)} of {len(src_ids)} meanings missing or not in {lang} '
                  f'(e.g. {bad[:3]})')
            continue
        out = OUT / lang
        out.mkdir(parents=True, exist_ok=True)
        (out / 'resources.json').write_text(json.dumps({'meanings': meanings}, ensure_ascii=False, separators=(',', ':')),
                                            encoding='utf-8')
        print(f'{lang}: resources {len(meanings)} meanings · {(out / "resources.json").stat().st_size // 1024} KB')
        built.append(lang)
    return built


if __name__ == '__main__':
    built = [l for l in LANGS if build(l)]
    index = {'reading': built, **{m: build_guide(m) for m in GUIDES}, 'resources': build_resources()}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'index.json').write_text(json.dumps(index, indent=1), encoding='utf-8')
    print('index:', index)
