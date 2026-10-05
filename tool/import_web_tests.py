#!/usr/bin/env python3
"""Full tests from the website (NextEd-IELTS-V2) → assets/content/tests_bank.json.

usage: python3 tool/import_web_tests.py
Sources (seed/sources/web_tests/, copied from the website repo):
  listening/tests_11_14.json      website Listening Mock Tests 3–6 (db positions 11–14) + test1N-map.jpg;
                                  audio: the website's full.mp3 per test (scripts/r2-listening-seed/local_assets)
  listening/full/FT0N.json        Listening Full Tests 1, 2, 3, 6, 7 (ElevenLabs v4 scripts: parts, questions, answer
                                  keys, transcripts) + FT0N.srt (subtitles of the recording, for timing) + FT0N-plan.png
                                  (tool/draw_full_test_plans.py); audio: FT0N.mp3 in $FULL_AUDIO. Cut points and
                                  transcript times are kept in listening/full/timing.json, so a rebuild without the
                                  audio gives the same result.
  reading_tests_11_20.json        website Reading Mock Tests 11–20 (parsed from migrations/0015 + 0016 fixes)
  reading_tests_21_26.json        website Reading Mock Tests 21–26 (extract_21_26.py)
  writing/tests_11_20.json        website Writing Tests 11–20 (Task 1 picture + Task 2) + writing-test-NN.jpg
  writing/tests_21_26.json        website Writing Tests 21–26
  speaking_tests_11_20.json       website Speaking Tests 11–20 (Part 1 topics, cue card, Part 3 topics)
  speaking_tests_21_26.json       website Speaking Tests 21–26
  fixes.json                      prompt / summary repairs (website text cut off mid-sentence), topics
App ids and names (renumbered 1–N):
  Listening Test 1–4  lt_w01…  sets lt_w01_p1…p4 (one recording per part, cut from the full recording at the
                      half-minute pauses after each part), Section 2 plan image
  Listening Test 5–9  lt_w05…  = Full Tests 1, 2, 3, 6, 7 (one recording per part, cut at the check-your-answers
                      pause after each part; timed transcripts; Part 2 plans drawn for FT01 / FT03 / FT07)
  Reading Test 1–16   rt_w01…  passages rt_w01_p1…p3 (website 11–26)
  Writing Test 1–16   wt_01…   prompts wt_01_t1 / wt_01_t2 (website 11–26)
  Speaking Test 1–16  st_01…   Part 1 topic st_01_p1 (all three topics), cue card st_01_cc (+ Part 3 list),
                      Part 3 topics st_01_p3_1 / _2 (website 11–26)
  Full Mock Test 1–4  mt_01…   = Listening/Reading/Writing/Speaking Test 1–4 (website Full Mocks 1–3 used 11–13)
  Full Mock Test 5–9  mt_05…   = Listening Test 5–9 + Reading/Writing/Speaking Test 11–15 (website 21–25);
                      Reading/Writing/Speaking Test 16 waits for a sixth new listening test (Mock 10)
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'seed', 'sources', 'web_tests')
OUT = os.path.join(ROOT, 'assets', 'content', 'tests_bank.json')
AUDIO_SRC = os.environ.get('WEB_AUDIO', '/mnt/user-data/uploads/NextEd-IELTS-V2/scripts/r2-listening-seed/local_assets')
A_LIS = os.path.join(ROOT, 'assets', 'audio', 'listening')
A_MAP = os.path.join(ROOT, 'assets', 'listening', 'maps')
A_WRI = os.path.join(ROOT, 'assets', 'writing', 'tests')
FULL_AUDIO = os.environ.get('FULL_AUDIO', '/tmp/claude-0/-home-claude/9cae0284-11a4-5bea-93fa-6ab7396d4762/scratchpad/lt/audio')
# Listening Full Tests used (in this order → lt_w05…); timing anchors (line index → seconds) where the subtitles failed
FULL_TESTS = [('FT01', {}), ('FT02', {128: 1551.8, 143: 1913.9, 144: 1925.5}), ('FT03', {}), ('FT06', {}), ('FT07', {})]
# recordings that leave out narrator lines of the script (FT06: no part introductions)
FULL_DROP_SILENT_NARRATOR = {'FT06'}


def load(*p):
    return json.load(open(os.path.join(SRC, *p), encoding='utf-8'))


FIX = load('fixes.json') if os.path.exists(os.path.join(SRC, 'fixes.json')) else {}


def gap(s):
    return re.sub(r'_{2,}', '______', s or '').replace(' ______ .', ' ______.')


def accepted(alts):
    """'(camel) dung' → ['camel dung', 'dung']; '1200–900 BCE' kept."""
    out = []
    for a in alts or []:
        a = str(a).strip()
        if '(' in a:
            out += [re.sub(r'\s+', ' ', re.sub(r'[()]', '', a)).strip(), re.sub(r'\s+', ' ', re.sub(r'\([^)]*\)', '', a)).strip()]
        else:
            out.append(a)
    seen, res = set(), []
    for a in out:
        if a and a.lower() not in seen:
            seen.add(a.lower())
            res.append(a)
    return res


def crop_image(src, dst, max_w=1600):
    from PIL import Image, ImageChops
    im = Image.open(src).convert('RGB')
    bg = Image.new('RGB', im.size, (255, 255, 255))
    box = ImageChops.difference(im, bg).convert('L').point(lambda v: 255 if v > 18 else 0).getbbox()
    if box:
        pad = 16
        im = im.crop((max(0, box[0] - pad), max(0, box[1] - pad), min(im.width, box[2] + pad), min(im.height, box[3] + pad)))
    if im.width > max_w:
        im = im.resize((max_w, round(im.height * max_w / im.width)))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, 'JPEG', quality=86)


# ── Listening ────────────────────────────────────────────────────────────────────────────────────────────────

def pauses(mp3):
    err = subprocess.run(['ffmpeg', '-hide_banner', '-i', mp3, '-af', 'silencedetect=noise=-40dB:d=4', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    return [float(x) for x in re.findall(r'silence_end: ([0-9.]+)', err)]


def duration(mp3):
    return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', mp3],
                                capture_output=True, text=True).stdout)


SECTION_TITLE = {1: 'Section 1', 2: 'Section 2', 3: 'Section 3', 4: 'Section 4'}


def listening():
    tests, sets = [], []
    for n, t in enumerate(sorted(load('listening', 'tests_11_14.json'), key=lambda x: x['num']), 1):
        tid = f'lt_w{n:02d}'
        full = os.path.join(AUDIO_SRC, f'TEST{t["num"]}', 'full.mp3')
        cuts = None
        if os.path.exists(full):
            ends = pauses(full)  # 10 half-minute pauses: before / middle / check for Sections 1–3, before Section 4
            assert len(ends) == 10, (t['num'], ends)
            cuts = [0.0, ends[2] - 0.2, ends[5] - 0.2, ends[8] - 0.2, duration(full)]
        desc = dict(re.findall(r'Section (\d): ([^.]*(?:\([^)]*\))?[^.]*)\.', t['description']))
        by_pos = {}
        for s in t['sections']:
            by_pos.setdefault(s['position'], []).append(s)
        set_ids = []
        for part in (1, 2, 3, 4):
            sid = f'{tid}_p{part}'
            audio = f'assets/audio/listening/{sid}.mp3'
            if cuts:
                dst = os.path.join(ROOT, audio)
                if not os.path.exists(dst):
                    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', full, '-ss', f'{cuts[part - 1]:.2f}',
                                    '-to', f'{cuts[part]:.2f}', '-c', 'copy', dst], check=True)
            groups, num = [], 0
            for gi, s in enumerate(by_pos[part], 1):
                qs = s['questions']
                instr = s['instructions']
                head = ''
                m = re.match(r'^([A-Z][A-Z\' ]+[A-Z])\.\s*(.*)$', instr)
                if m:
                    head, instr = m.group(1).title(), m.group(2)
                kind = qs[0]['type']
                g = {'id': f'g{gi}'}
                if kind == 'text_input':
                    g.update(type='gap', title=head or ('Complete the notes' if 'notes' in instr else 'Complete the sentences'),
                             instruction=re.sub(r'^Complete the (notes|sentences) below\.\s*', '', instr))
                    g['questions'] = []
                    for q in qs:
                        num += 1
                        acc = accepted(q['accepted'])
                        g['questions'].append({'number': num, 'text': gap(q['prompt']), 'answer': acc[0], 'accepted': acc})
                elif kind == 'map_label':
                    img = f'assets/listening/maps/{tid}_plan.jpg'
                    crop_image(os.path.join(SRC, 'listening', f'test{t["num"]}-map.jpg'), os.path.join(ROOT, img))
                    letters = [o['letter'] for o in qs[0]['options']]
                    g.update(type='map', title='Label the plan', instruction=instr, image=img, layoutIntro='',
                             options=[{'key': L, 'text': ''} for L in letters])
                    g['questions'] = []
                    for q in qs:
                        num += 1
                        g['questions'].append({'number': num, 'text': q['prompt'], 'answer': q['accepted'][0].upper()})
                elif kind == 'single_choice':
                    g.update(type='mcq', title='Choose the correct letter, A, B or C')
                    g['questions'] = []
                    for q in qs:
                        num += 1
                        g['questions'].append({'number': num, 'text': q['prompt'],
                                               'options': [{'key': o['letter'], 'text': o['text']} for o in q['options']],
                                               'answer': q['accepted'][0].upper()})
                elif kind == 'matching':
                    title = re.split(r'\s+Choose|\s+A\.', instr)[0].strip()
                    g.update(type='matching', title=title,
                             instruction='Choose the correct letter, A, B or C, next to each task.',
                             options=[{'key': o['letter'], 'text': o['text']} for o in qs[0]['options']])
                    g['questions'] = []
                    for q in qs:
                        num += 1
                        g['questions'].append({'number': num, 'text': q['prompt'], 'answer': q['accepted'][0].upper()})
                else:
                    raise ValueError(kind)
                groups.append(g)
            assert num == 10, (sid, num)
            ctx = desc.get(str(part), '').strip()
            sets.append({
                'id': sid, 'part': part, 'test': tid,
                'title': (ctx[:1].upper() + ctx[1:]) if ctx else f'Part {part}',
                'context': ctx[:1].upper() + ctx[1:] if ctx else '',
                'audio': f'assets/audio/listening/{sid}.mp3',
                'durationSeconds': round(cuts[part] - cuts[part - 1]) if cuts else 0,
                'transcriptStatus': 'none', 'speakers': [], 'transcript': [], 'groups': groups,
                'source': f'website Listening Mock Test {n + 2} (test {t["num"]})',
            })
            set_ids.append(sid)
        tests.append({'id': tid, 'number': n, 'title': f'Listening Test {n}', 'sets': set_ids,
                      'description': t['description'], 'source': f'website test {t["num"]}'})
    return tests, sets


def silences(mp3, min_len=8.0):
    err = subprocess.run(['ffmpeg', '-hide_banner', '-i', mp3, '-af', f'silencedetect=noise=-40dB:d={min_len}', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    st = [float(x) for x in re.findall(r'silence_start: ([0-9.]+)', err)]
    en = [float(x) for x in re.findall(r'silence_end: ([0-9.]+)', err)]
    return list(zip(st, en))


def full_timing(code, anchors):
    """Cut points (s) for the four parts and a start time for every kept transcript line."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from listening_align import align
    t = load('listening', 'full', f'{code}.json')
    mp3 = os.path.join(FULL_AUDIO, f'{code}.mp3')
    lines, owner = [], []
    for pi, p in enumerate(t['parts']):
        for li, x in enumerate(p['transcript']):
            lines.append(x['text'])
            owner.append((pi, li))
    srt = open(os.path.join(SRC, 'listening', 'full', f'{code}.srt'), encoding='utf-8-sig').read()
    starts, rep = align(lines, srt, anchors)
    keep = [not (code in FULL_DROP_SILENT_NARRATOR and t['parts'][owner[i][0]]['transcript'][owner[i][1]]['speaker'] == 'Narrator'
                 and not rep['heard'][i]) for i in range(len(lines))]
    sil = silences(mp3)
    short = silences(mp3, 1.0)
    cues = [(int(h) * 3600 + int(m) * 60 + int(s_) + int(ms) / 1000, re.sub(r'\s+', ' ', body).strip())
            for h, m, s_, ms, body in re.findall(r'(\d+):(\d+):(\d+)[,.](\d+)\s*-->[^\n]*\n(.*?)(?:\n\s*\n|\Z)', srt, re.S)]
    words = {2: 'two', 3: 'three', 4: 'four'}
    cuts = [0.0]
    for pi in range(1, 4):
        n = pi + 1
        # 1) the narrator's "Part N. You will hear …" in the subtitles, snapped to the pause just before it
        ts = None
        for k, (t_, body) in enumerate(cues):
            if t_ <= cuts[-1] + 60:
                continue
            if re.match(rf'(part|section)\s+({n}|{words[n]})\b', body, re.I) and \
                    'you will hear' in ' '.join(b for _, b in cues[k:k + 3]).lower():
                ts = t_
                break
        if ts is not None:
            ends = [e for s0, e in short if ts - 4 <= e <= ts + 1.0]
            cuts.append(round((max(ends) if ends else ts - 0.3) - 0.5, 2))
            continue
        # 2) otherwise: the end of the check-your-answers pause after "That is the end of Part N-1"
        prev = [i for i in range(len(lines)) if owner[i][0] == pi - 1 and 'end of' in lines[i].lower()]
        t0 = starts[prev[-1]] if prev else starts[next(i for i in range(len(lines)) if owner[i][0] == pi)] - 40
        nxt = min(s1 for s0, s1 in sil if s0 >= t0 - 5)
        cuts.append(round(nxt - 0.5, 2))
    cuts.append(round(duration(mp3), 2))
    parts = []
    for pi in range(4):
        parts.append([round(max(0.0, starts[i] - cuts[pi]), 1) if keep[i] else None
                      for i in range(len(lines)) if owner[i][0] == pi])
    return {'cuts': cuts, 'starts': parts, 'coverage': rep['coverage']}


def full_listening(first_number):
    tests, sets = [], []
    tpath = os.path.join(SRC, 'listening', 'full', 'timing.json')
    timing = json.load(open(tpath)) if os.path.exists(tpath) else {}
    for k, (code, anchors) in enumerate(FULL_TESTS):
        n = first_number + k
        tid = f'lt_w{n:02d}'
        t = load('listening', 'full', f'{code}.json')
        mp3 = os.path.join(FULL_AUDIO, f'{code}.mp3')
        if os.path.exists(mp3):
            timing[code] = full_timing(code, anchors)
        tm = timing[code]
        cuts = tm['cuts']
        set_ids = []
        for p in t['parts']:
            part = p['part']
            sid = f'{tid}_p{part}'
            audio = f'assets/audio/listening/{sid}.mp3'
            dst = os.path.join(ROOT, audio)
            if os.path.exists(mp3) and not os.path.exists(dst):
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', mp3, '-ss', f'{cuts[part - 1]:.2f}', '-to', f'{cuts[part]:.2f}',
                                '-c', 'copy', dst], check=True)
            groups = json.loads(json.dumps(p['groups']))
            for g in groups:
                if g['type'] == 'map':
                    img = f'assets/listening/maps/{tid}_plan.jpg'
                    crop_image(os.path.join(SRC, 'listening', 'full', f'{code}-plan.png'), os.path.join(ROOT, img))
                    g['image'] = img
            num = sum(g.get('pick', 1) if g['type'] == 'multi' else 1 for g in groups for _ in g['questions'])
            assert num == 10, (sid, num)
            transcript = []
            for x, st in zip(p['transcript'], tm['starts'][part - 1]):
                if st is None:
                    continue
                transcript.append({'id': f't{len(transcript) + 1}', 'speaker': x['speaker'], 'text': x['text'], 'start': st,
                                   'directions': [], 'keywords': [], 'answerTags': []})
            sets.append({
                'id': sid, 'part': part, 'test': tid, 'title': p['title'], 'context': p['context'],
                'audio': audio, 'durationSeconds': round(cuts[part] - cuts[part - 1]),
                'transcriptStatus': 'timed', 'transcriptTiming': 'audio',
                'speakers': [{'name': s_['name'], 'role': s_.get('role', '')} for s_ in p.get('speakers', [])],
                'transcript': transcript, 'groups': groups,
                'source': f'Listening Full Test {int(code[2:])} (ElevenLabs v4)',
            })
            set_ids.append(sid)
        desc = ' '.join(f'Part {p["part"]}: {p["context"].rstrip(".")}.' for p in t['parts'])
        tests.append({'id': tid, 'number': n, 'title': f'Listening Test {n}', 'sets': set_ids, 'description': desc,
                      'source': f'Listening Full Test {int(code[2:])}'})
    json.dump(timing, open(tpath, 'w'), indent=1)
    return tests, sets


# ── Reading ──────────────────────────────────────────────────────────────────────────────────────────────────

TYPE_OF = [
    (r'information given in the passage\? Write TRUE', 'tfng'),
    (r'claims of the writer\? Write YES', 'ynng'),
    (r'Complete the notes below', 'gap_notes'),
    (r'Complete the sentences below', 'gap_sentences'),
    (r'Choose the correct heading', 'heading'),
    (r'Which paragraph contains', 'matching'),
    (r'Choose the correct letter', 'mcq'),
    (r'Complete the summary below', 'summary'),
]


def split_options(opts):
    """Option lists; a website row sometimes holds all choices in one text
    ("… B. … C. … D. …") — split those back into A–D."""
    out = []
    for o in opts:
        parts = re.split(r'\s+(?=[B-H]\.\s)', o['text'].strip())
        if len(parts) > 1 and all(re.match(r'[B-H]\.\s', x) for x in parts[1:]):
            out.append({'key': o['letter'], 'text': parts[0].strip()})
            for x in parts[1:]:
                out.append({'key': x[0], 'text': x[2:].strip()})
        else:
            out.append({'key': o['letter'], 'text': o['text']})
    keys = [o['key'] for o in out]
    assert keys == sorted(set(keys)), keys
    return out


def merge_fragments(frags):
    """'… a b ____ c…' windows over one summary → the whole text with ____ for each gap, in order."""
    text = ''
    for f in frags:
        f = f.strip().strip('…').strip()
        if not text:
            text = f
            continue
        best = 0
        for k in range(min(len(text), len(f)), 8, -1):
            if text.endswith(f[:k]):
                best = k
                break
        if best == 0:  # find the longest prefix of f that occurs near the end of text
            for k in range(min(len(f), 200), 8, -1):
                i = text.rfind(f[:k])
                if i >= 0:
                    text = text[:i]
                    best = 0
                    text += f
                    break
            else:
                text += ' ' + f
        else:
            text += f[best:]
    return text


def gap_sentence(text, n):
    """The sentence of a summary that holds gap (n) — the question line in a mock test."""
    text = re.sub(r'\s+', ' ', text)
    for sent in re.split(r'(?<=[.!?])\s+(?=[A-Z(])', text):
        if f'({n}) ______' in sent:
            return re.sub(r'\((\d+)\) ______', lambda m: '______' if int(m.group(1)) == n else '…', sent).strip()
    return '______'


def paragraphs(passage):
    out = []
    for block in re.split(r'\n\s*\n|\n(?=[A-H]\.\s)', passage.strip()):
        block = block.strip()
        m = re.match(r'^([A-H])\.\s+(.*)$', block, re.S)
        if m:
            out.append({'letter': m.group(1), 'text': re.sub(r'\s+', ' ', m.group(2)).strip()})
        elif block and out:
            out[-1]['text'] += ' ' + re.sub(r'\s+', ' ', block)
    return out


def reading():
    tests, passages = [], []
    fx = FIX.get('reading', {})
    for n, t in enumerate(load('reading_tests_11_20.json') + load('reading_tests_21_26.json'), 1):
        tid = f'rt_w{n:02d}'
        pids = []
        for pi, s in enumerate(t['sections'], 1):
            pid = f'{tid}_p{pi}'
            ranges = [(int(a), int(b), txt) for a, b, txt in re.findall(r'Questions (\d+)-(\d+): ([^\n]*)', s['instructions'])]
            qs = {q['qnumber']: q for q in s['questions']}
            first = min(qs)
            groups = []
            for gi, (a, b, txt) in enumerate(ranges, 1):
                kind = next(k for pat, k in TYPE_OF if re.search(pat, txt))
                items = [qs[i] for i in range(a, b + 1)]
                local = lambda i: i - first + 1  # noqa: E731
                g = {'id': f'g{gi}'}
                if kind in ('tfng', 'ynng'):
                    g.update(type=kind, title='True / False / Not Given' if kind == 'tfng' else 'Yes / No / Not Given',
                             instruction=re.sub(r'\s*Write .*$', '', txt),
                             options=['TRUE', 'FALSE', 'NOT GIVEN'] if kind == 'tfng' else ['YES', 'NO', 'NOT GIVEN'],
                             questions=[{'number': local(q['qnumber']), 'text': q['prompt'], 'answer': q['accepted'][0].upper()}
                                        for q in items])
                elif kind.startswith('gap'):
                    g.update(type='gap', title='Complete the notes' if kind == 'gap_notes' else 'Complete the sentences',
                             instruction=re.sub(r'^Complete the \w+ below\.\s*', '', txt), questions=[])
                    for q in items:
                        key = f'{pid}_q{local(q["qnumber"])}'
                        text = fx.get('prompts', {}).get(key, q['prompt'])
                        acc = accepted(q['accepted'])
                        g['questions'].append({'number': local(q['qnumber']), 'text': gap(text), 'answer': acc[0], 'accepted': acc})
                elif kind == 'heading':
                    g.update(type='heading', title='Match each paragraph to a heading',
                             instruction='Choose the correct heading for each paragraph from the list of headings. '
                                         'There are more headings than paragraphs.',
                             headings=[{'key': o['letter'], 'text': o['text']} for o in items[0]['options']],
                             questions=[{'number': local(q['qnumber']), 'text': q['prompt'],
                                         'paragraph': q['prompt'].replace('Paragraph', '').strip(), 'answer': q['accepted'][0]}
                                        for q in items])
                elif kind == 'matching':
                    g.update(type='matching', title='Which paragraph contains the following information?',
                             instruction='Write the correct letter. You may use any letter more than once.',
                             options=[o['letter'] for o in items[0]['options']],
                             questions=[{'number': local(q['qnumber']), 'text': q['prompt'], 'answer': q['accepted'][0].upper()}
                                        for q in items])
                elif kind == 'mcq':
                    g.update(type='mcq', title='Choose the correct letter, A, B, C or D',
                             questions=[{'number': local(q['qnumber']), 'text': q['prompt'],
                                         'options': split_options(q['options']),
                                         'answer': q['accepted'][0].upper()} for q in items])
                elif kind == 'summary':
                    text = fx.get('summaries', {}).get(pid) or merge_fragments([q['prompt'] for q in items])
                    parts = text.split('____')
                    assert len(parts) == len(items) + 1, (pid, len(parts), text)
                    body = parts[0]
                    for q, rest in zip(items, parts[1:]):
                        body += f'({local(q["qnumber"])}) ______' + rest
                    body = re.sub(r'______\s+([.,;:])', r'______\1', body)
                    g.update(type='summary', title=fx.get('summaryTitles', {}).get(pid, 'Complete the summary'),
                             instruction='Complete the summary using the list of words below.', wordLimit=None,
                             options=[{'key': o['letter'], 'text': o['text']} for o in items[0]['options']],
                             text=re.sub(r'\s+', ' ', body).strip(),
                             questions=[{'number': local(q['qnumber']), 'text': gap_sentence(body, local(q['qnumber'])),
                                         'answer': q['accepted'][0].upper(),
                                         'accepted': [q['accepted'][0].upper()]} for q in items])
                groups.append(g)
            paras = paragraphs(s['passage_text'])
            words = sum(len(p['text'].split()) for p in paras)
            passages.append({'id': pid, 'title': s['title'], 'topic': fx.get('topics', {}).get(pid, ''),
                             'difficulty': ['easy', 'medium', 'hard'][pi - 1], 'words': words, 'test': tid,
                             'paragraphs': paras, 'groups': groups})
            pids.append(pid)
        tests.append({'id': tid, 'number': n, 'title': f'Academic Reading Test {n}', 'passages': pids,
                      'source': f'website Reading Mock Test {10 + n}'})
    return tests, passages


# ── Writing ──────────────────────────────────────────────────────────────────────────────────────────────────

T1_TYPES = [('process', 'process', 'Process diagram'), ('life cycle', 'process', 'Diagram'), ('diagram', 'process', 'Diagram'),
            ('map', 'map', 'Maps'), ('table and', 'mixed', 'Mixed charts'), ('and line graph', 'mixed', 'Mixed charts'),
            (', and', 'mixed', 'Mixed charts'), ('line graph', 'line', 'Line graph'), ('bar chart', 'bar', 'Bar chart'),
            ('pie chart', 'pie', 'Pie chart'), ('table', 'table', 'Table')]
T2_TYPES = [('discuss both views', 'discussion', 'Discussion'), ('advantages', 'advantages', 'Advantages & disadvantages'),
            ('what are the main reasons', 'problem', 'Causes & solutions'), ('what problems', 'problem', 'Problem & solution'),
            ('what are the causes', 'problem', 'Causes & solutions'), ('to what extent', 'opinion', 'Opinion'),
            ('?', 'two_part', 'Two-part question')]

T1_TAIL = 'Summarise the information by selecting and reporting the main features, and make comparisons where relevant.'
T2_TAIL = 'Give reasons for your answer and include any relevant examples from your own knowledge or experience.'


def writing():
    tests, prompts = [], []
    for n, t in enumerate(load('writing', 'tests_11_20.json') + load('writing', 'tests_21_26.json'), 1):
        tid = f'wt_{n:02d}'
        img = f'assets/writing/tests/{tid}_task1.jpg'
        crop_image(os.path.join(SRC, 'writing', f'writing-test-{t["num"]}.jpg'), os.path.join(ROOT, img), 1400)
        t1 = t['task1'].strip()
        low = t1.lower().split('summarise')[0]
        kinds = [k for pat, k in (('line graph', 'line'), ('bar chart', 'bar'), ('pie chart', 'pie'), ('table', 'table'))
                 if pat in low]
        if len(kinds) > 1:
            ty, label = 'mixed', 'Mixed charts'
        else:
            ty, label = next(((k, lab) for pat, k, lab in T1_TYPES if pat in low and pat not in (', and', 'table and', 'and line graph')),
                             ('mixed', 'Mixed charts'))
        ty, label = FIX.get('task1Types', {}).get(tid, (ty, label))
        statement = t1.replace(T1_TAIL, '').strip()
        q2 = t['task2'].replace(T2_TAIL, '').strip()
        ty2, label2 = next(((k, lab) for pat, k, lab in T2_TYPES if pat in q2.lower()), ('opinion', 'Opinion'))
        ty2, label2 = FIX.get('task2Types', {}).get(tid, (ty2, label2))
        prompts.append({
            'id': f'{tid}_t1', 'task': 1, 'bank': 'Writing test', 'test': tid, 'number': n, 'type': ty, 'typeLabel': label,
            'title': FIX.get('writingTitles', {}).get(tid, statement.split(' below ')[-1][:80]),
            'statement': statement, 'prompt': f'{statement} {T1_TAIL}',
            'instructions': ['You should spend about 20 minutes on this task.', statement, T1_TAIL, 'Write at least 150 words.'],
            'timeMinutes': 20, 'minWords': 150, 'image': img,
        })
        prompts.append({
            'id': f'{tid}_t2', 'task': 2, 'bank': 'Writing test', 'test': tid, 'number': n, 'type': ty2, 'typeLabel': label2,
            'title': FIX.get('task2Titles', {}).get(tid, ''), 'question': q2, 'prompt': f'{q2}\n\n{T2_TAIL}',
            'instructions': ['You should spend about 40 minutes on this task.', 'Write about the following topic:', q2,
                             T2_TAIL, 'Write at least 250 words.'],
            'timeMinutes': 40, 'minWords': 250,
        })
        tests.append({'id': tid, 'number': n, 'title': f'Writing Test {n}', 'task1': f'{tid}_t1', 'task2': f'{tid}_t2',
                      'source': f'website Writing Test {t["num"]}'})
    return tests, prompts


# ── Speaking ─────────────────────────────────────────────────────────────────────────────────────────────────

def speaking():
    tests, part1, cards, part3 = [], [], [], []
    for n, t in enumerate(load('speaking_tests_11_20.json') + load('speaking_tests_21_26.json'), 1):
        tid = f'st_{n:02d}'
        sc = t['script']
        topics = sc['part1']['topics']
        part1.append({'id': f'{tid}_p1', 'test': tid, 'topic': ' · '.join(x['topic'] for x in topics),
                      'category': 'test', 'categoryLabel': f'Speaking Test {n}', 'intro': True,
                      'examinerIntro': sc['part1'].get('intro', ''),
                      'sections': [{'topic': x['topic'], 'questions': x['questions']} for x in topics],
                      'questions': [q for x in topics for q in x['questions']]})
        p3 = sc['part3']['topics']
        p3ids = []
        for k, x in enumerate(p3, 1):
            p3ids.append(f'{tid}_p3_{k}')
            part3.append({'id': f'{tid}_p3_{k}', 'test': tid, 'topic': x['topic'], 'category': 'test',
                          'categoryLabel': f'Speaking Test {n}',
                          'questions': [{'q': q, 'tag': '', 'tagLabel': '', 'answer': ''} for q in x['questions']]})
        c2 = sc['part2']
        title = c2['cueCardTitle'].rstrip('.')
        bullets = [b.rstrip('.') for b in c2['points']]
        cards.append({'id': f'{tid}_cc', 'test': tid, 'number': n, 'cardNumber': n, 'category': 'test',
                      'categoryLabel': f'Speaking Test {n}', 'topic': f'Speaking Test {n}', 'title': title, 'prompt': title,
                      'bullets': bullets, 'followUps': [{'q': q, 'answer': ''} for q in c2.get('roundingOff', [])],
                      'part3Topics': p3ids, 'part3': [q for x in p3 for q in x['questions']]})
        tests.append({'id': tid, 'number': n, 'title': f'Speaking Test {n}', 'part1': f'{tid}_p1', 'cueCard': f'{tid}_cc',
                      'part3': p3ids, 'description': t['description'], 'source': f'website Speaking Test {10 + n}'})
    return tests, part1, cards, part3


def plain_dashes(text):
    """Em dashes → a spaced normal dash ("word - word"), as the server's plainDashes does for every response."""
    def rep(m):
        b1 = text[m.start() - 1] if m.start() > 0 else ''
        b2 = text[m.start() - 2] if m.start() > 1 else ''
        a1 = text[m.end()] if m.end() < len(text) else ''
        a2 = text[m.end() + 1] if m.end() + 1 < len(text) else ''
        no_lead = b1 == '' or (b1 == '"' and b2 != '\\') or (b1 == 'n' and b2 == '\\') or b1 in '([{'
        no_trail = a1 == '' or (a1 == '\\' and a2 == 'n') or a1 in '")]},.;:'
        return f"{'' if no_lead else ' '}-{'' if no_trail else ' '}"
    return re.sub(r'[ \t]*\u2014[ \t]*', rep, text)


def main():
    l_tests, l_sets = listening()
    f_tests, f_sets = full_listening(len(l_tests) + 1)
    l_tests, l_sets = l_tests + f_tests, l_sets + f_sets
    r_tests, r_passages = reading()
    w_tests, w_prompts = writing()
    s_tests, s_p1, s_cards, s_p3 = speaking()
    mocks = []
    for n in range(1, len(l_tests) + 1):
        k = n if n <= 4 else n + 6  # Mocks 5+ use Reading / Writing / Speaking 11+ (website 21–26)
        mocks.append({'id': f'mt_{n:02d}', 'number': n, 'letter': str(n), 'title': f'Full Mock Test {n}',
                      'listeningTest': f'lt_w{n:02d}', 'readingTest': f'rt_w{k:02d}',
                      'task1': f'wt_{k:02d}_t1', 'task2': f'wt_{k:02d}_t2',
                      'speaking': {'part1': f'st_{k:02d}_p1', 'cueCard': f'st_{k:02d}_cc'},
                      'writingTest': f'wt_{k:02d}', 'speakingTest': f'st_{k:02d}'})
    bank = {
        'meta': {'source': 'NextEd-IELTS-V2 (website) full tests', 'importer': 'tool/import_web_tests.py'},
        'listening': {'tests': l_tests, 'sets': l_sets},
        'reading': {'tests': r_tests, 'passages': r_passages},
        'writing': {'tests': w_tests, 'prompts': w_prompts},
        'speaking': {'tests': s_tests, 'part1Topics': s_p1, 'cueCards': s_cards, 'part3Topics': s_p3},
        'mock': {'tests': mocks},
    }
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(plain_dashes(json.dumps(bank, ensure_ascii=False, separators=(',', ':'))))
    print(f'{len(l_tests)} listening tests ({len(l_sets)} parts) · {len(r_tests)} reading tests ({len(r_passages)} passages) · '
          f'{len(w_tests)} writing · {len(s_tests)} speaking · {len(mocks)} mocks → {OUT} ({os.path.getsize(OUT) // 1024} KB)')


if __name__ == '__main__':
    main()
