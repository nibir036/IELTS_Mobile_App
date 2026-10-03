"""Builds seed/formats/*.json (one format file per data type, with a
description of the table + 1-2 real example records) and seed/data/*.json
(the current content bank exported in the same format as a starting seed).

Run: python3 tool/build_seed_formats.py   (reads assets/demo/demo_data.json)
"""
import json, os, glob, copy, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = json.load(open(os.path.join(ROOT, 'assets/demo/demo_data.json'), encoding='utf-8'))
OUT_F = os.path.join(ROOT, 'seed', 'formats')
OUT_D = os.path.join(ROOT, 'seed', 'data')
os.makedirs(OUT_F, exist_ok=True); os.makedirs(OUT_D, exist_ok=True)
C = D['content']
NOW = datetime.datetime(2026, 9, 29, 12, 0, 0)

def iso(dt): return dt.replace(microsecond=0).isoformat() + 'Z'

def fields(items):
    """Field → type list from all items (top level)."""
    out = {}
    for it in items:
        for k, v in it.items():
            t = type(v).__name__.replace('str', 'string').replace('dict', 'object').replace('list', 'array').replace('float', 'number').replace('int', 'integer').replace('bool', 'boolean').replace('NoneType', 'null')
            out.setdefault(k, set()).add(t)
    return {k: '|'.join(sorted(v)) for k, v in out.items()}

MANIFEST = []

def emit(num, name, group, table, key, desc, items, source, required=None,
         relations=None, notes=None, examples=2, export=True, fields_override=None,
         parts=None, pick=None):
    fn = f'{num:02d}_{name}.json'
    items = [i for i in items if i is not None]
    fmt = {
        '_format': {
            'name': name,
            'group': group,
            'table': table,
            'primaryKey': key,
            'description': desc,
            'currentSourceInApp': source,
            'fields': fields_override or fields(items),
            'required': required or [key],
            'relations': relations or [],
            'notes': notes or [],
            'recordCountToday': len(items),
            **({'practiceParts': parts} if parts else {}),
        },
        'items': copy.deepcopy(pick(items) if pick else items[:examples]),
    }
    json.dump(fmt, open(os.path.join(OUT_F, fn), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    if export and items:
        json.dump({'table': table, 'items': items},
                  open(os.path.join(OUT_D, fn), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    MANIFEST.append({'file': fn, 'group': group, 'table': table, 'records': len(items) if export else 0,
                     'exported': bool(export and items)})

def audio_key(path):  # assets/audio/listening/ls_01.mp3 → listening/ls_01.mp3 (R2 object key)
    return path.replace('assets/audio/', '') if path else path

# ── CONTENT BANK ────────────────────────────────────────────────────────────
PASSAGE_PART = {}
for t in C['reading']['tests']:
    for i, pid in enumerate(t['passages']): PASSAGE_PART[pid] = i + 1
passages = copy.deepcopy(C['reading']['passages'])
for p_ in passages: p_['part'] = PASSAGE_PART.get(p_['id'], {'easy': 1, 'medium': 2, 'hard': 3}.get(p_.get('difficulty'), 1))
READING_PARTS = [
    {'part': 1, 'label': 'Reading Part 1 (Passage 1)', 'difficulty': 'easy', 'questions': '13', 'words': '700-900',
     'typicalQuestionTypes': ['tfng', 'gap', 'matching'], 'practisedOn': 'Reading library → Passage 1 filter; full test Q1-13'},
    {'part': 2, 'label': 'Reading Part 2 (Passage 2)', 'difficulty': 'medium', 'questions': '13', 'words': '750-950',
     'typicalQuestionTypes': ['heading', 'matching', 'mcq', 'gap'], 'practisedOn': 'Passage 2 filter; full test Q14-26'},
    {'part': 3, 'label': 'Reading Part 3 (Passage 3)', 'difficulty': 'hard', 'questions': '14', 'words': '800-950',
     'typicalQuestionTypes': ['ynng', 'mcq', 'matching', 'gap'], 'practisedOn': 'Passage 3 filter; full test Q27-40'}]
def one_per(key, n):
    def f(items):
        out = []
        for v in range(1, n + 1):
            for it in items:
                if it.get(key) == v: out.append(it); break
        return out
    return f
emit(1, 'reading_passages', 'content', 'reading_passages', 'id',
     'One Academic reading passage = one Reading part (Part 1, 2 or 3) with its question groups (12-14 questions, numbered 1..n locally).',
     passages, 'assets/demo/content/reading_*.json → reading.passages',
     ['id', 'part', 'title', 'topic', 'difficulty', 'paragraphs', 'groups'],
     ['groups[].questions[].evidenceParagraph → paragraphs[].letter', 'part = the passage position it fills in a full test (reading_tests.passages[part-1])'],
     ['Group types: tfng, ynng, heading, matching, mcq, gap (see CONTENT_SCHEMA.md).',
      'Every question needs answer, evidenceParagraph, evidence (verbatim phrase) and explanation.',
      'part: 1|2|3 (Passage 1 easy, 2 medium, 3 hard). One example per part below.',
      'difficulty: easy|medium|hard; topic from the fixed topic list.'], parts=READING_PARTS, pick=one_per('part', 3))
emit(2, 'reading_tests', 'content', 'reading_tests', 'id',
     'A full Academic Reading test = 3 passages, 40 questions, 60 minutes.',
     C['reading']['tests'], 'reading.tests', ['id', 'number', 'title', 'passages'],
     ['passages[] → reading_passages.id (order = Passage 1,2,3; question counts must sum to 40)'])
sets = copy.deepcopy(C['listening']['sets'])
for s in sets: s['audio'] = audio_key(s.get('audio'))
emit(3, 'listening_sets', 'content', 'listening_sets', 'id',
     'One Listening part (10 questions) with its audio, speakers and timed transcript.',
     sets, 'listening.sets', ['id', 'part', 'title', 'audio', 'durationSeconds', 'transcript', 'groups'],
     ['audio → R2 object key (bucket ielts-ai-recordings or a content bucket)'],
     ['part: 1 social dialogue · 2 social monologue · 3 academic discussion · 4 lecture.',
      'transcript[].start = seconds from the start of the audio; answerTags link lines to questions.',
      'audio is an R2 object key (was an app asset path); the app resolves it to a URL.',
      'Group types: form, gap, mcq, multi (pick N, counts as N questions), matching.',
      'One example per part below (Parts 1-4 share one table, filtered by part).'],
     parts=[
      {'part': 1, 'label': 'Listening Part 1', 'context': 'Everyday social conversation, 2 speakers (e.g. booking, enquiry)', 'questions': 10, 'minutes': '4-5', 'typicalQuestionTypes': ['form', 'gap'], 'practisedOn': 'Part practice / Mini practice → Part 1; full test Q1-10'},
      {'part': 2, 'label': 'Listening Part 2', 'context': 'Everyday monologue (tour, talk, announcement)', 'questions': 10, 'minutes': '4-5', 'typicalQuestionTypes': ['mcq', 'matching', 'map'], 'practisedOn': 'Part 2 filter; full test Q11-20'},
      {'part': 3, 'label': 'Listening Part 3', 'context': 'Academic discussion, 2-4 speakers (students, tutor)', 'questions': 10, 'minutes': '4-6', 'typicalQuestionTypes': ['mcq', 'multi', 'matching'], 'practisedOn': 'Part 3 filter; full test Q21-30'},
      {'part': 4, 'label': 'Listening Part 4', 'context': 'Academic lecture, 1 speaker, no break', 'questions': 10, 'minutes': '4-6', 'typicalQuestionTypes': ['gap', 'form'], 'practisedOn': 'Part 4 filter; full test Q31-40'}],
     pick=one_per('part', 4))
emit(4, 'listening_tests', 'content', 'listening_tests', 'id',
     'A full Listening test = 4 sets (Parts 1-4), 40 questions.',
     C['listening']['tests'], 'listening.tests', ['id', 'number', 'title', 'sets'],
     ['sets[] → listening_sets.id, one per part, in order'])
emit(5, 'writing_task1_prompts', 'content', 'writing_prompts', 'id',
     'Academic Writing Task 1 prompt with chart data and an optional model answer.',
     C['writing']['task1'], 'writing.task1', ['id', 'type', 'title', 'prompt', 'chart'],
     [], ['type: line|bar|pie|table|process|map|mixed; chart shape depends on type (CONTENT_SCHEMA.md).',
          'Stored in one writing_prompts table with task = 1.'],
     parts=[{'part': 'task1', 'label': 'Writing Task 1', 'minWords': 150, 'minutes': 20, 'weight': 'one third of the Writing band', 'practisedOn': 'Writing → Task 1 editor (C2); mock G6'}])
emit(6, 'writing_task2_prompts', 'content', 'writing_prompts', 'id',
     'Writing Task 2 essay question with idea bank, vocabulary and optional model answer.',
     C['writing']['task2'], 'writing.task2', ['id', 'type', 'topic', 'title', 'prompt'],
     [], ['type: opinion|discussion|advantages|problem|two-part.', 'Stored in writing_prompts with task = 2.',
          'ideas.for/against/vocabulary feed the Ideas screen (C11).'],
     parts=[{'part': 'task2', 'label': 'Writing Task 2', 'minWords': 250, 'minutes': 40, 'weight': 'two thirds of the Writing band', 'practisedOn': 'Writing → Task 2 editor (C3); mock G6'}])
emit(7, 'speaking_part1_topics', 'content', 'speaking_part1_topics', 'id',
     'Speaking Part 1 topic with 4-5 questions.', C['speaking']['part1Topics'], 'speaking.part1Topics',
     ['id', 'topic', 'questions'],
     parts=[{'part': 1, 'label': 'Speaking Part 1', 'minutes': '4-5', 'format': 'Examiner asks 4-5 questions on 2-3 familiar topics', 'practisedOn': 'Speaking → Part 1 (D2); mock G7'}])
emit(8, 'speaking_cue_cards', 'content', 'speaking_cue_cards', 'id',
     'Speaking Part 2 cue card with bullets, Part 3 follow-ups and sample notes.',
     C['speaking']['cueCards'], 'speaking.cueCards', ['id', 'topic', 'title', 'prompt', 'bullets', 'part3'],
     [], ['topic: People|Places|Objects|Events|Experiences|Media.',
          'Add "season" (e.g. "2026-09/2026-12") when you rotate cue cards by exam season.',
          'part3 inside the card is kept for the linked Part 3 discussion; Part 3 is also its own table (26).'],
     parts=[{'part': 2, 'label': 'Speaking Part 2 (long turn)', 'minutes': '3-4', 'format': '1 min preparation, then speak for up to 2 min on the cue card', 'practisedOn': 'Speaking → cue card (D3) → recording (D4); mock G7'}])
emit(9, 'mock_tests', 'content', 'mock_tests', 'id',
     'A full mock test assembling one Listening test, one Reading test, two Writing tasks and Speaking.',
     C['mock']['tests'], 'mock.tests', ['id', 'letter', 'title', 'listeningTest', 'readingTest', 'task1', 'task2', 'speaking'],
     ['listeningTest → listening_tests.id', 'readingTest → reading_tests.id', 'task1/task2 → writing_prompts.id',
      'speaking.part1 → speaking_part1_topics.id', 'speaking.cueCard → speaking_cue_cards.id (Part 3 = its part3)'])
emit(10, 'vocab_quizzes', 'content', 'vocab_quizzes', 'id',
     'A 10-question vocabulary quiz round (choose the meaning).', C['resources']['quizzes'], 'resources.quizzes',
     ['id', 'title', 'level', 'questions'], ['questions[].wordId → vocabulary_words.id (optional)'],
     ['questions[].answer = index into options.'], examples=1)
emit(11, 'phrasal_verbs', 'content', 'phrases', 'id', 'Phrasal verb with meaning, example, register and topic.',
     C['resources']['phrasalVerbs'], 'resources.phrasalVerbs', ['id', 'phrase', 'meaning', 'example', 'register'],
     [], ['register: speaking|writing|both. Stored in phrases with kind = "phrasal".'])
emit(12, 'idioms', 'content', 'phrases', 'id', 'Idiom with meaning, example, register, topic and a use-with-care note.',
     C['resources']['idioms'], 'resources.idioms', ['id', 'phrase', 'meaning', 'example', 'register'],
     [], ['Stored in phrases with kind = "idiom". caution = optional note for informal idioms.'])
vw = copy.deepcopy(D['resources']['vault']['words'])
wod = D['resources']['hub'].get('wordOfTheDay')
if wod and not any(w['id'] == wod['id'] for w in vw):
    vw.append({'id': wod['id'], 'word': wod['word'], 'partOfSpeech': wod['partOfSpeech'],
               'definition': wod['definition'], 'band': 8, 'category': 'Band 7+ words'})
for w in vw:
    if wod and w['id'] == wod['id']:
        w['phonetic'] = wod.get('phonetic'); w['example'] = wod.get('example')
emit(13, 'vocabulary_words', 'content', 'vocabulary_words', 'id',
     'Vocabulary vault word (also used for word of the day and quiz links).', vw,
     'assets/demo/parts/resources.json → vault.words + hub.wordOfTheDay',
     ['id', 'word', 'partOfSpeech', 'definition', 'band', 'category'], [],
     ['phonetic and example are optional but needed for word of the day.',
      'category: one of vault.categories (Band 7+ words, Linking words, Phrasal verbs, Topic words).'])
aw = copy.deepcopy(D['resources']['academicWords']['words'])
for i, w in enumerate(aw): w.setdefault('day', 1); w.setdefault('sublist', 2)
emit(14, 'academic_words', 'content', 'academic_words', 'id',
     'Academic Word List entry assigned to a study day (30 days x 20 words).', aw,
     'resources.academicWords.words', ['id', 'word', 'partOfSpeech', 'meaning', 'day'], [],
     ['day: 1-30 study day; sublist: AWL sublist 1-10.'])
iv = copy.deepcopy(D['resources']['irregularVerbs']['verbs'])
for v in iv: v.setdefault('id', 'iv_' + v['base'])
emit(15, 'irregular_verbs', 'content', 'irregular_verbs', 'id', 'Irregular verb forms.',
     iv, 'resources.irregularVerbs.verbs', ['id', 'base', 'past', 'participle'], [],
     ['Alternatives separated by "/" (learnt/learned) are accepted by the practice mode.'])
pw = []
for w in D['speaking']['pronunciation']['words']:
    pw.append({'id': 'pw_' + w['word'], 'word': w['word'], 'ipa': w.get('ipa'), 'partOfSpeech': w.get('pos'),
               'syllables': [{'text': s['text'], 'stress': s.get('state') == 'stress'} for s in w.get('syllables', [])],
               'tip': w.get('tip'), 'set': 'default'})
emit(16, 'pronunciation_words', 'content', 'pronunciation_words', 'id',
     'Word for the pronunciation drill (D7) with IPA and stressed syllable.', pw,
     'speaking.pronunciation.words (demo feedback fields removed: those are per attempt)',
     ['id', 'word', 'ipa', 'syllables'], [], ['set groups words into a drill of ~7 words.'])
emit(17, 'reading_lessons', 'content', 'lessons', 'id', 'Bite-size Reading lesson with key idea and exercises.',
     D['reading']['lessons'], 'reading.lessons', ['id', 'title', 'keyIdea', 'exercises'], [],
     ['Stored in lessons with skill = reading; order = position in the list.'], examples=1)
emit(18, 'listening_lessons', 'content', 'lessons', 'id', 'Bite-size Listening lesson with an audio exercise.',
     D['listening']['lessons'], 'listening.lessons', ['id', 'title', 'body', 'rows'], [],
     ['Stored in lessons with skill = listening. Add "audio" (R2 key) once lesson audio exists.'], examples=1)
emit(19, 'writing_lessons', 'content', 'lessons', 'id', 'Writing masterclass lesson (C8).',
     D['writing']['masterclass']['lessons'], 'writing.masterclass.lessons', ['id', 'title', 'formula', 'keyPoints'],
     [], ['Stored in lessons with skill = writing.'])
emit(20, 'sentence_drills', 'content', 'sentence_drills', 'id', 'Writing Booster sentence-combining drill (C7).',
     D['writing']['sentenceBuilder']['drills'], 'writing.sentenceBuilder.drills',
     ['id', 'instruction', 'sentences', 'answer', 'bank'], [], ['answer = the tokens in the correct order; bank = distractors + answer tokens.'])
emit(21, 'writing_templates', 'content', 'writing_templates', 'id', 'Essay/report template with fill-in slots (C10).',
     # (the app's `variant` label is not a table column; the title names the version)
     [{k: v for k, v in it.items() if k != 'variant'} for it in D['writing']['templates']['items']],
     'writing.templates.items', ['id', 'type', 'title', 'task', 'sections'],
     [], ['segments[] are text or {slot} pieces; task: task1|task2.'], examples=1)
sa = D['writing']['sampleAnswers']
emit(22, 'writing_sample_answers', 'content', 'writing_sample_answers', 'promptId',
     'Band 6 / 7 / 8 sample answers for one prompt, with why each got its band (C13).', [sa],
     'writing.sampleAnswers', ['promptId', 'answers'], ['promptId → writing_prompts.id'])
emit(23, 'articles', 'content', 'articles', 'id', 'Tips article (H11) in a series.', D['resources']['articles'],
     'resources.articles', ['id', 'series', 'title', 'tips'], [],
     ['series: listening|reading|writing|speaking; tryIt.target = an app screen key.'], examples=1)
# Table columns key/name/intro + criteria (Json) = the page's facts and blocks.
emit(24, 'band_descriptors', 'content', 'band_descriptors', 'key', 'Scoring criteria per skill (H10).',
     [{'key': s['key'], 'name': s['name'], 'intro': s.get('intro'),
       'criteria': s['criteria'] if 'criteria' in s else {'facts': s.get('facts', []), 'blocks': s.get('blocks', [])}}
      for s in D['resources']['scoring']['skills']],
     'resources.scoring.skills', ['key', 'name', 'criteria'], [],
     ['Write your own plain-English summaries; do not copy the official descriptors verbatim.'], examples=1)
emit(25, 'word_of_the_day', 'content', 'word_of_the_day', 'date', 'Which vocabulary word is shown on each day.',
     [{'date': '2026-09-29', 'wordId': wod['id'] if wod else 'word_ubiquitous'}],
     'resources.hub.wordOfTheDay (single fixed word today)', ['date', 'wordId'],
     ['wordId → vocabulary_words.id'], ['One row per day (Asia/Dhaka date).'])

p3 = []
for cc in C['speaking']['cueCards']:
    if cc.get('part3'):
        p3.append({'id': 'p3_' + cc['id'], 'topic': cc.get('topic'), 'theme': cc.get('title'),
                   'cueCardId': cc['id'], 'questions': cc['part3']})
emit(26, 'speaking_part3_sets', 'content', 'speaking_part3_sets', 'id',
     'Speaking Part 3 discussion set: 4-5 abstract questions on a theme, usually linked to a Part 2 cue card.',
     p3, 'speaking.cueCards[].part3 (the app builds Part 3 from the linked cue card today)',
     ['id', 'topic', 'theme', 'questions'], ['cueCardId → speaking_cue_cards.id (optional; empty = standalone Part 3 practice)'],
     ['Exported from the cue cards, one set per card. New Part 3 sets can be written without a cue card.'],
     parts=[{'part': 3, 'label': 'Speaking Part 3 (discussion)', 'minutes': '4-5', 'format': 'Examiner asks deeper follow-up questions on the Part 2 theme', 'practisedOn': 'Speaking → Part 3 (D2); mock G7'}])

# ── CONFIG ──────────────────────────────────────────────────────────────────
pl = D['home']['plans']
emit(30, 'plans', 'config', 'plans', 'id', 'Subscription plans shown on the Plans screen.', pl['plans'],
     'home.plans.plans', ['id', 'name', 'priceMonthly', 'priceYearly'], [],
     ['Prices in BDT (currency ৳). Replace the placeholder Pro prices before launch.'])
emit(31, 'plan_features', 'config', 'plan_features', 'id', 'Feature comparison rows (Free vs Pro).', pl['features'],
     'home.plans.features', ['id', 'label', 'free', 'pro'], [],
     ['free/pro: "yes", "no" or a short text such as "1 / month". Also the source for usage limits.'])
emit(32, 'certificates', 'config', 'certificate_definitions', 'id', 'Milestone certificate definitions and the rule that awards them.',
     D['home']['certificates']['items'], 'home.certificates.items', ['id', 'code', 'title', 'rule'], [],
     ['rule.type: count|band|streak|parts — evaluated against the user\'s attempts.'])
lg = D['access']['legal']
emit(33, 'legal_documents', 'config', 'legal_documents', 'id', 'Terms of Use and Privacy Policy (versioned).',
     [dict(id='terms', version=lg.get('updated'), **lg['terms']), dict(id='privacy', version=lg.get('updated'), **lg['privacy'])],
     'access.legal', ['id', 'version', 'title', 'sections'], [],
     ['Draft pending legal review. Keep old versions: users accept a specific version.'], examples=1)
rooms = copy.deepcopy(D['resources']['community']['rooms'])
for r in rooms:
    for k in ('preview', 'unread', 'live'): r.pop(k, None)
    r.setdefault('topic', 'General'); r.setdefault('official', True)
emit(34, 'community_rooms', 'config', 'rooms', 'id', 'Official community rooms (user-created rooms live in the same table).',
     rooms, 'resources.community.rooms (preview/unread/live are computed at runtime)',
     ['id', 'name', 'letter', 'tone', 'topic'], [],
     ['tone: pink|lavender|cream|… (card colour). official = created by nextED.'])
emit(35, 'app_config', 'config', 'app_config', 'key', 'Tunable settings the app reads at start-up.',
     [{'key': 'diagnostic', 'value': D['access']['diagnostic']},
      {'key': 'mock.timing', 'value': D['mock'].get('timing')},
      {'key': 'mock.systemChecks', 'value': D['mock'].get('systemChecks')}],
     'access.diagnostic, mock.timing, mock.systemChecks', ['key', 'value'], [],
     ['Key/value JSON. UI copy stays in the app; only values you want to change without a release go here.'], examples=3)

# ── USER DATA (not seeded for real users; used for demo/test accounts + migration) ──
acc = D['accounts'][0]
u = copy.deepcopy(acc['account'])
u.pop('password', None)
u['passwordHash'] = 'argon2id$…'
u['createdAt'] = iso(NOW - datetime.timedelta(days=106))
u['profile'].pop('examDaysFromNow', None); u['profile']['examDate'] = '2026-11-16'
emit(40, 'users', 'user', 'users', 'id', 'Student account + onboarding profile.', [u],
     'Store (SharedPreferences) accounts[]; demo seed assets/demo/parts/accounts.json',
     ['id', 'name', 'phone', 'passwordHash', 'createdAt', 'profile'], [],
     ['phone = 10 digits without 0/+880 (1XXXXXXXXX).', 'Never store plain passwords; the demo file does only for the local demo.',
      'profile: plan, targetBand, examDate, testType (always Academic), focusSkills, dailyMinutes, feedbackLanguage, photo (R2 key).'],
     export=False)
ats = []
for f in sorted(glob.glob(os.path.join(ROOT, 'assets/demo/parts/seed_*.json'))):
    for a in json.load(open(f, encoding='utf-8')).get('attempts', []):
        ats.append(a)
seen = set(); ex = []
for a in ats:
    k = (a['skill'], a['kind'])
    if k in seen or a['kind'] == 'session': continue
    seen.add(k)
    b = copy.deepcopy(a)
    days = b.pop('daysAgo', 0); mins = b.pop('minutesAgo', None); hour = b.pop('hour', None)
    t = NOW - datetime.timedelta(days=days)
    if hour is not None: t = t.replace(hour=hour, minute=0)
    if mins is not None: t = NOW - datetime.timedelta(minutes=mins)
    b['userId'] = u['id']; b['createdAt'] = iso(t)
    ex.append(b)
emit(41, 'attempts', 'user', 'attempts', 'id',
     'Every practice result (one row per attempt). data holds the kind-specific details.', ex,
     'Store attempts; demo seeds assets/demo/parts/seed_*.json', ['id', 'userId', 'skill', 'kind', 'createdAt'],
     ['userId → users.id', 'refId → the content item (passage, set, test, prompt, card, mock, quiz, lesson)'],
     ['skill: listening|reading|writing|speaking|mock|vocab. One example per skill+kind below.',
      'band = 0-9 in 0.5 steps (null for unscored); durationSec = time spent.'], examples=len(ex), export=False)
s_home = json.load(open(os.path.join(ROOT, 'assets/demo/parts/seed_home.json'), encoding='utf-8'))
n = copy.deepcopy(s_home['notifications'][0]); n['userId'] = u['id']; n['createdAt'] = iso(NOW - datetime.timedelta(minutes=n.pop('minutesAgo', 0)))
emit(42, 'notifications', 'user', 'notifications', 'id', 'In-app notification.', [n], 'Store notifications',
     ['id', 'userId', 'type', 'title', 'createdAt'], ['userId → users.id'], ['target = app route to open.'], export=False)
t = copy.deepcopy(s_home['tasks'][0]); t['userId'] = u['id']; t['date'] = (NOW + datetime.timedelta(days=t.pop('dayOffset', 0))).date().isoformat()
emit(43, 'tasks', 'user', 'study_tasks', 'id', 'Study-plan task on the schedule (B5).', [t], 'Store tasks',
     ['id', 'userId', 'title', 'date'], ['userId → users.id'], ['kind: goal|mock|reminder|…; time = HH:mm local.'], export=False)
kv = {}
for f in glob.glob(os.path.join(ROOT, 'assets/demo/parts/seed_*.json')):
    kv.update(json.load(open(f, encoding='utf-8')).get('kv', {}))
kv_items = [{'userId': u['id'], 'key': k, 'value': v} for k, v in sorted(kv.items())[:6]]
emit(44, 'user_state', 'user', 'user_state', 'userId+key', 'Per-user saved state: saved words, bookmarks, drafts, progress.',
     kv_items, 'Store kv', ['userId', 'key', 'value'], ['userId → users.id'],
     [f'{len(kv)} keys in use today, e.g. ' + ', '.join(sorted(kv)[:12]) + ' …',
      'Drafts and in-progress tests can stay on the device; saved words/cards/bookmarks should sync.'],
     examples=6, export=False)
emit(45, 'recordings', 'user', 'recordings', 'id', 'Speaking recording stored in R2.',
     [{'id': 'rec_01', 'userId': u['id'], 'attemptId': 'att_s_p2_1', 'r2Key': f"recordings/{u['id']}/att_s_p2_1.wav",
       'format': 'wav', 'durationMs': 118000, 'bytes': 3776044, 'createdAt': iso(NOW)}],
     'speaking attempts data + VoiceRecorder', ['id', 'userId', 'r2Key', 'durationMs'], ['attemptId → attempts.id'], [], export=False)
emit(46, 'room_messages', 'user', 'room_messages', 'id', 'Community chat message (text, voice, image, AI partner).',
     [{'id': 'm1', 'roomId': 'room_speaking_p2', 'userId': 'usr_anika', 'type': 'text',
       'text': 'Anyone up for Part 3 practice? Topic is environment.', 'createdAt': iso(NOW)},
      {'id': 'm2', 'roomId': 'room_speaking_p2', 'userId': u['id'], 'type': 'voice',
       'r2Key': f"chat/{u['id']}/m2.m4a", 'durationMs': 14000, 'createdAt': iso(NOW)}],
     'resources.speakingRoom.messages + kv community.sent.*', ['id', 'roomId', 'userId', 'type', 'createdAt'],
     ['roomId → rooms.id', 'userId → users.id'], ['type: text|voice|image|ai|system.'], export=False)
emit(47, 'subscriptions', 'user', 'subscriptions', 'id', 'A user\'s paid plan (when payments launch).',
     [{'id': 'sub_01', 'userId': u['id'], 'planId': 'pro', 'period': 'yearly', 'status': 'active',
       'startedAt': iso(NOW), 'renewsAt': iso(NOW + datetime.timedelta(days=365)), 'provider': 'bkash', 'providerRef': '…'}],
     'profile.plan today', ['id', 'userId', 'planId', 'status'], ['planId → plans.id', 'userId → users.id'],
     ['provider: bkash|nagad|card — decided when payments are built.'], export=False)

# formats written by other importers (e.g. tool/import_reading_bank.py → 27-29)
_known = {m['file'] for m in MANIFEST}
for fn in sorted(os.listdir(OUT_F)):
    if fn.endswith('.json') and fn not in _known:
        f_ = json.load(open(os.path.join(OUT_F, fn), encoding='utf-8'))['_format']
        dp = os.path.join(OUT_D, fn)
        n_ = len(json.load(open(dp, encoding='utf-8'))['items']) if os.path.exists(dp) else 0
        MANIFEST.append({'file': fn, 'group': f_.get('group'), 'table': f_.get('table'), 'records': n_, 'exported': n_ > 0})
MANIFEST.sort(key=lambda m: m['file'])
json.dump({'generatedFrom': 'assets/demo/demo_data.json', 'formats': MANIFEST},
          open(os.path.join(ROOT, 'seed', 'manifest.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
for m in MANIFEST: print(m['file'], m['group'], m['records'])
