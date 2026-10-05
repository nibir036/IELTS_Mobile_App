"""Website tests 21–26 (Reading / Writing / Speaking) → source JSON in the same shape as the 11–20 files.
usage: python3 seed/sources/web_tests/extract_21_26.py [path to NextEd-IELTS-V2]"""
import json, os, re, shutil, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sqlparse import tuples
WEB = sys.argv[1] if len(sys.argv) > 1 else '/mnt/user-data/uploads/NextEd-IELTS-V2'
NUMS = range(21, 27)
mig = lambda f: open(os.path.join(WEB, 'migrations', f), encoding='utf-8').read()

# reading
sql = mig('0015_seed_reading_test_bank.sql')
tests = [t for t in tuples(sql, 'tests') if t['skill'] == 'reading']
secs = tuples(sql, 'test_sections')
qs = tuples(sql, 'test_questions')
ans = {a['question_id']: a['accepted'] for a in tuples(sql, 'test_answers')}
for m in re.finditer(r"UPDATE test_questions SET options = '((?:[^']|'')*)'::jsonb WHERE id = '([^']+)'", mig('0016_fix_reading_mcq_options.sql')):
    fixed = json.loads(m.group(1).replace("''", "'"))
    for q in qs:
        if q['id'] == m.group(2):
            q['options'] = fixed
out = []
for n in NUMS:
    t = next(t for t in tests if t['title'] == f'IELTS Reading Mock Test {n}')
    t = {k: t[k] for k in ('id', 'title', 'description', 'instructions', 'duration_seconds', 'position')}
    t['sections'] = []
    for s in sorted((s for s in secs if s['test_id'] == t['id']), key=lambda s: s['position']):
        sq = sorted((q for q in qs if q['section_id'] == s['id']), key=lambda q: q['qnumber'])
        for q in sq:
            q.setdefault('options', None)
            q['accepted'] = ans[q['id']]
        t['sections'].append({'title': s['title'], 'instructions': s['instructions'], 'passage_text': s['passage_text'],
                              'position': s['position'], 'questions': sq})
    assert sum(len(s['questions']) for s in t['sections']) == 40, n
    if n == 24:  # summary gaps 37 / 38 are in reverse order in the website text: swap them so they run in order
        q = {x['qnumber']: x for x in t['sections'][2]['questions']}
        for k in ('prompt', 'accepted'):
            q[37][k], q[38][k] = q[38][k], q[37][k]
    out.append(t)
json.dump(out, open(os.path.join(HERE, 'reading_tests_21_26.json'), 'w'), ensure_ascii=False, indent=1)

# writing
man = json.load(open(os.path.join(WEB, 'scripts', 'r2-writing-seed', 'manifest.json')))
w = [x for x in man if x['num'] in NUMS]
assert len(w) == 6
json.dump(w, open(os.path.join(HERE, 'writing', 'tests_21_26.json'), 'w'), ensure_ascii=False, indent=1)
for x in w:
    shutil.copy(os.path.join(WEB, 'scripts', 'r2-writing-seed', x['local_file']), os.path.join(HERE, 'writing', f'writing-test-{x["num"]}.jpg'))

# speaking
sql = mig('seed_speaking_tests.sql')
st = {t['id']: t for t in tuples(sql, 'tests') if t['skill'] == 'speaking'}
res = tuples(sql, 'test_resources')
sp = []
for n in NUMS:
    t = next(t for t in st.values() if t['title'] == f'IELTS Speaking Test {n}')
    r = [x for x in res if x['test_id'] == t['id']]
    script = next(x['content'] for x in r if isinstance(x.get('content'), (dict, str)))
    if isinstance(script, str):
        script = json.loads(script)
    sp.append({'position': t['position'], 'title': t['title'], 'description': t['description'], 'script': script})
json.dump(sp, open(os.path.join(HERE, 'speaking_tests_21_26.json'), 'w'), ensure_ascii=False, indent=1)
print('reading', [t['title'] for t in out]); print('writing', [x['num'] for x in w]); print('speaking', [x['title'] for x in sp])
