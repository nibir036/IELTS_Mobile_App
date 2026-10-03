#!/usr/bin/env python3
"""Attach the recorded audio to the Listening bank sets (assets/content/listening_bank.json).

usage: python3 tool/apply_listening_audio.py [path/to/audio_folder_or_zip]
  With a folder/zip: copies each recording to assets/audio/listening/<code>.mp3 and its timestamped transcript to
  seed/sources/listening_audio/<code>.txt (matched to a set by its words), then applies them.
  Without: re-applies what is already in seed/sources/listening_audio/ (run it after import_listening_bank.py).

Per set with a recording:
  transcript  = the recording's own transcript ("[m:ss] Speaker: text" lines from ElevenLabs), with real start
                times; speaker labels mapped to the set's speakers where they match (Receptionist → Emma);
                a line the transcriber cut mid-sentence is joined to the next one;
  answerTags  = completion answers located in the new transcript (same rules as the importer);
  audioStatus = 'ready', durationSeconds = the file's length, durationEstimated = false, transcriptTiming = 'audio'.
  fixes       = seed/sources/listening_audio/fixes/<code>.json {"note": "...", "groups": {"g2": <full group>}}:
                question groups rewritten to match the recording (the audio is the reference); the answer key is
                rebuilt from the groups.
  srt         = seed/sources/listening_audio/srt/<code>.srt (Whisper / Subtitle Edit, same recording): when present,
                each line's start is taken from the words' real times in the SRT (then moved to the nearest pause
                within 0.8 s) instead of being estimated from word counts.
  --srt <folder_or_zip>: copy the .srt files in (matched to a set by the recording's checksum), then apply.
Prints, per set, completion answers it could not find in the recording's words (check those by ear).
--check: apply in memory and report only (writes nothing).
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tool'))
import import_listening_bank as ilb  # noqa: E402  (answer_needles)

BANK = os.path.join(ROOT, 'assets', 'content', 'listening_bank.json')
AUDIO = os.path.join(ROOT, 'assets', 'audio', 'listening')
SRC = os.path.join(ROOT, 'seed', 'sources', 'listening_audio')
LINE = re.compile(r'^\[(\d+):(\d{2})(?:\.(\d+))?\]\s*([^:]{1,40}):\s*(.*)$')
PLAIN = re.compile(r'^\[(\d{1,2}):(\d{2}):(\d{2})\]\s*(.*)$')  # "[00:01:10] text" (one speaker, no labels)
LETTER_TYPES = ('mcq', 'multi', 'matching', 'map')


def words(s):
    return re.findall(r"[a-z0-9']+", s.lower())


def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
                         capture_output=True, text=True).stdout.strip()
    return float(out)


def parse_txt(path):
    lines = []
    for raw in open(path, encoding='utf-8').read().splitlines():
        p = PLAIN.match(raw.strip())
        if p:
            start = int(p.group(1)) * 3600 + int(p.group(2)) * 60 + int(p.group(3))
            lines.append({'speaker': '', 'text': p.group(4).strip(), 'start': start})
            continue
        m = LINE.match(raw.strip())
        if m:
            start = int(m.group(1)) * 60 + int(m.group(2)) + (float('0.' + m.group(3)) if m.group(3) else 0)
            lines.append({'speaker': m.group(4).strip(), 'text': m.group(5).strip(), 'start': start})
        elif raw.strip() and lines and not raw.startswith('['):
            lines[-1]['text'] += ' ' + raw.strip()
    # some transcripts restart the clock every minute ([0:59] → [0:01]): add the lost minutes back
    offset, prev = 0, -1.0
    for ln in lines:
        t = ln['start'] + offset
        if t < prev - 20:
            offset += 60
            t = ln['start'] + offset
        ln['start'] = t
        prev = t
    # join a line the transcriber cut mid-sentence ("… In colder" + "weather, the water …")
    out = []
    for ln in lines:
        if not ln['text']:
            continue
        if out and out[-1]['speaker'] == ln['speaker'] and not re.search(r'[.!?…"”)\]]$', out[-1]['text']):
            out[-1]['text'] += ' ' + ln['text']
            continue
        out.append(dict(ln))
    return out


def pauses(mp3):
    """Ends of the short silences in the recording (where a new line can start)."""
    err = subprocess.run(['ffmpeg', '-hide_banner', '-i', mp3, '-af', 'silencedetect=noise=-38dB:d=0.3', '-f', 'null', '-'],
                         capture_output=True, text=True).stderr
    ends = [(float(e), float(d)) for e, d in re.findall(r'silence_end: ([0-9.]+) \| silence_duration: ([0-9.]+)', err)]
    starts = [float(x) for x in re.findall(r'silence_start: ([0-9.]+)', err)]
    return ends, starts


def spoken_length(text):
    """Roughly how many words long a line sounds: a spelled name (B-R-A-N-D-O-N) or a phone number takes far
    longer to say than one word."""
    n = 0.0
    for tok in text.split():
        core = tok.strip('.,;:!?()"“”')
        if re.fullmatch(r'(?:[A-Za-z]-){2,}[A-Za-z]', core):
            n += 1.8 * (core.count('-') + 1)
        elif re.fullmatch(r'\d{3,}', core):
            n += 0.7 * len(core)
        else:
            n += 1
    return n


def align(lines, mp3, total):
    """Line start times for the recording. The transcripts' own clocks run fast or restart every minute, so a
    line's start is estimated from the words before it (spread over the spoken part of the file) and then moved
    to the nearest pause in the audio."""
    ends, starts = pauses(mp3)
    t0 = ends[0][0] if ends and starts and starts[0] < 0.2 else 0.0
    t1 = starts[-1] if starts and starts[-1] > total - 6 and starts[-1] > t0 else total
    weights = [spoken_length(l['text']) + 1.5 for l in lines]
    span, acc, out, prev = sum(weights), 0.0, [], -1.0
    for w in weights:
        guess = t0 + (t1 - t0) * acc / span
        # prefer real gaps between turns (longer silences) over the short ones inside a spelled name
        near = [(e, d) for e, d in ends if abs(e - guess) <= 3.5 and e > prev + 0.4]
        t = min(near, key=lambda ed: abs(ed[0] - guess) - 2.5 * min(ed[1], 0.9))[0] if near else max(guess, prev + 0.5)
        out.append(round(t, 1))
        prev = t
        acc += w
    return out


def parse_srt(path):
    """[(start, end, text)] of an SRT file."""
    cues = []
    for block in re.split(r'\n\s*\n', open(path, encoding='utf-8-sig').read().replace('\r', '')):
        m = re.search(r'(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)\s*\n(.*)', block, re.S)
        if not m:
            continue
        g = [int(x) for x in m.groups()[:8]]
        a = g[0] * 3600 + g[1] * 60 + g[2] + g[3] / 1000
        b = g[4] * 3600 + g[5] * 60 + g[6] + g[7] / 1000
        cues.append((a, b, ' '.join(m.group(9).split())))
    return cues


def srt_times(lines, srt, mp3):
    """Line start times from the SRT: every SRT word gets a time (spread over its cue by length), the line's words
    are matched to the SRT's words, and a line starts at its first matched word (lines with no match are placed
    between their neighbours). Each start is then moved to the nearest end of a pause within 0.8 s."""
    import difflib
    sw, st = [], []
    for a, b, text in parse_srt(srt):
        ws = words(norm(text))
        n = sum(len(w) + 1 for w in ws) or 1
        acc = 0
        for w in ws:
            sw.append(w)
            st.append(a + (b - a) * acc / n)
            acc += len(w) + 1
    lw, owner = [], []
    for i, l in enumerate(lines):
        for w in words(norm(l['text'])):
            lw.append(w)
            owner.append(i)
    first = [None] * len(lines)
    for blk in difflib.SequenceMatcher(None, lw, sw, autojunk=False).get_matching_blocks():
        for k in range(blk.size):
            i = owner[blk.a + k]
            # only trust a match near the start of the line (its first 3 words)
            pos = blk.a + k - owner.index(i)
            if first[i] is None and pos < 3:
                first[i] = st[blk.b + k] - pos * 0.3
    known = [(i, t) for i, t in enumerate(first) if t is not None]
    out = []
    for i, t in enumerate(first):
        if t is None:
            before = [(j, u) for j, u in known if j < i]
            after = [(j, u) for j, u in known if j > i]
            if before and after:
                (j0, u0), (j1, u1) = before[-1], after[0]
                t = u0 + (u1 - u0) * (i - j0) / (j1 - j0)
            else:
                t = before[-1][1] + 2 if before else (after[0][1] - 2 if after else 0)
        out.append(max(t, 0.0))
    ends, _ = pauses(mp3)
    res, prev = [], -1.0
    for t in out:
        near = [e for e, d in ends if abs(e - t) <= 0.8 and e > prev + 0.3]
        if near:
            t = min(near, key=lambda e: abs(e - t))
        t = max(t, prev + 0.3)
        res.append(round(t, 1))
        prev = t
    return res, sum(1 for t in first if t is None)


def import_srt(src):
    """Copy the .srt files of a folder/zip to SRC/srt/<code>.srt, matched by the recording's checksum."""
    import hashlib
    tmp = None
    if src.endswith('.zip'):
        tmp = tempfile.mkdtemp()
        zipfile.ZipFile(src).extractall(tmp)
        src = tmp
    md5 = lambda p: hashlib.md5(open(p, 'rb').read()).hexdigest()
    have = {md5(p): os.path.basename(p)[:-4] for p in glob.glob(os.path.join(AUDIO, '*.mp3'))}
    os.makedirs(os.path.join(SRC, 'srt'), exist_ok=True)
    done = {}
    for srt in sorted(glob.glob(os.path.join(src, '**', '*.srt'), recursive=True), key=lambda p: ('(1)' in p, p)):
        mp3 = srt[:-4] + '.mp3'
        code = have.get(md5(mp3)) if os.path.exists(mp3) else None
        name = os.path.basename(srt)
        if not code:
            print('no matching recording in the app for', name)
            continue
        if code in done:
            print(f'skip {name}: {code} already has {done[code]}')
            continue
        done[code] = name
        shutil.copyfile(srt, os.path.join(SRC, 'srt', f'{code}.srt'))
        print(f'{code}  {name}')
    with open(os.path.join(SRC, 'srt', 'sources.json'), 'w', encoding='utf-8') as f:
        json.dump(done, f, ensure_ascii=False, indent=1, sort_keys=True)
    if tmp:
        shutil.rmtree(tmp)


def speaker_map(labels, speakers):
    """Transcript labels (Receptionist, Parent, Lecturer) → the set's speaker names where they match."""
    out = {}
    for lab in labels:
        low = lab.lower()
        best = None
        for s in speakers:
            name, role = s.get('name', ''), s.get('role', '') + ' ' + s.get('description', '')
            first = name.split()[0].lower() if name else ''
            if low == name.lower() or (first and first in low.split()) or (low and low in name.lower().split()):
                best = name
                break
            if re.search(r'\b' + re.escape(low) + r'\b', role.lower()):
                best = best or name
        if best is None and len(speakers) == 1:
            best = speakers[0]['name']
        out[lab] = best or lab
    return out


def norm(s):
    """lower case; hyphens, '£', '%' and 'wi-fi' spellings evened out (same length kept is not needed)."""
    s = s.lower().replace('wi-fi', 'wifi').replace('wi fi', 'wifi').replace('’', "'")
    s = re.sub(r'(?<=\w)-(?=\w)', ' ', s)
    return s.replace('£', '').replace('%', ' percent').replace('  ', ' ')


def original_span(text, cand):
    """The words of [text] that matched the normalised [cand] (for the transcript's highlight)."""
    pat = r'[\s\-]*'.join(re.escape(w) for w in cand.replace(' percent', '%').split())
    m = re.search(pat.replace('wifi', 'wi[\\s\\-]?fi').replace('%', '(?:%|\\s*percent)'), text, re.I)
    return text[m.start():m.end()] if m else cand


def locate_answers(lines, groups):
    cursor, missing = 0, []
    for g in groups:
        if g['type'] in LETTER_TYPES:
            continue
        for q in g['questions']:
            hit = None
            for li in range(cursor, len(lines)):
                low = norm(lines[li]['text'])
                for needle in ilb.answer_needles(q):
                    nd = norm(needle)
                    nd = re.sub(r'^the ', '', nd)
                    letters = '-'.join(nd.replace(' ', '')) if re.fullmatch(r'[a-z]+', nd) and len(nd) > 3 else None
                    spaced = ' '.join(nd.replace(' ', '')) if letters else None
                    for cand in [nd] + ([letters, spaced] if letters else []):
                        m = re.search(r'(?<![a-z0-9])' + re.escape(cand) + r'(?![a-z0-9])', low)
                        if m:
                            hit = (li, original_span(lines[li]['text'], cand))
                            break
                    if hit:
                        break
                if hit:
                    break
            if hit:
                li, phrase = hit
                lines[li]['keywords'].append(phrase)
                lines[li]['answerTags'].append({'after': phrase, 'question': q['number']})
                cursor = li
            else:
                missing.append((q['number'], q.get('accepted') or [q.get('answer')]))
    return missing


def import_folder(src, sets):
    """Copy recordings + transcripts in, matched to set codes by their words."""
    tmp = None
    if src.endswith('.zip'):
        tmp = tempfile.mkdtemp()
        zipfile.ZipFile(src).extractall(tmp)
        src = tmp
    by_code = {s['code']: set(words(' '.join(l['text'] for l in s['transcript']))) for s in sets}
    os.makedirs(AUDIO, exist_ok=True)
    os.makedirs(SRC, exist_ok=True)
    done = {}
    for txt in sorted(glob.glob(os.path.join(src, '**', '*.txt'), recursive=True), key=lambda p: ('(1)' in p, p)):
        base = txt[:-4]
        mp3 = next((p for p in (base + '.mp3', re.sub(r'_plain_text$', '', base) + '.mp3') if os.path.exists(p)), None)
        if not mp3:
            print('no audio for', os.path.basename(txt))
            continue
        w = set(words(' '.join(l['text'] for l in parse_txt(txt))))
        code, score = max(((c, len(w & v) / len(w | v)) for c, v in by_code.items()), key=lambda x: x[1])
        name = os.path.basename(txt)
        if code in done:  # the same recording twice (e.g. "…(1)"): keep the first
            print(f'skip {name}: {code} already has {done[code]}')
            continue
        done[code] = name
        shutil.copyfile(mp3, os.path.join(AUDIO, f'{code}.mp3'))
        shutil.copyfile(txt, os.path.join(SRC, f'{code}.txt'))
        print(f'{code}  {score:.2f}  {name}')
    with open(os.path.join(SRC, 'sources.json'), 'w', encoding='utf-8') as f:
        json.dump(done, f, ensure_ascii=False, indent=1, sort_keys=True)
    if tmp:
        shutil.rmtree(tmp)


def apply_fixes(s):
    f = os.path.join(SRC, 'fixes', f'{s["code"]}.json')
    if not os.path.exists(f):
        return False
    fx = json.load(open(f, encoding='utf-8'))
    by_id = {g['id']: i for i, g in enumerate(s['groups'])}
    for gid, g in fx.get('groups', {}).items():
        g = dict(g, id=gid)
        if gid in by_id:
            s['groups'][by_id[gid]] = g
        else:
            s['groups'].append(g)
    for old, new in fx.get('renameSpeakers', {}).items():
        for sp in s.get('speakers', []):
            if sp['name'] == old:
                sp['name'] = new
    s['_speakerMap'] = fx.get('speakerMap', {})
    s['_speakerSplit'] = fx.get('speakerSplit', {})
    for k in ('title', 'instructions', 'context', 'scenario', 'listeningContext'):
        if k in fx:
            s[k] = fx[k]
    key = {}
    for g in s['groups']:
        for q in g['questions']:
            key[str(q['number'])] = q.get('answerDisplay') or q.get('answer')
    s['answerKey'] = dict(sorted(key.items(), key=lambda kv: int(kv[0])))
    s['questionCount'] = len(key)
    return True


def main():
    check_only = '--check' in sys.argv
    args = [a for a in sys.argv[1:] if a != '--check']
    if args[:1] == ['--srt']:
        import_srt(args[1])
        args = args[2:]
    bank = json.load(open(BANK, encoding='utf-8'))
    sets = bank['sets']
    if args:
        import_folder(args[0], sets)
    applied, total_missing = 0, 0
    for s in sets:
        txt = os.path.join(SRC, f'{s["code"]}.txt')
        mp3 = os.path.join(AUDIO, f'{s["code"]}.mp3')
        if not (os.path.exists(txt) and os.path.exists(mp3)):
            continue
        fixed = apply_fixes(s)
        raw = parse_txt(txt)
        smap = speaker_map(sorted({l['speaker'] for l in raw}), s.get('speakers', []))
        smap.update(s.pop('_speakerMap', {}))
        split = s.pop('_speakerSplit', {})
        for lab, parts in split.items():  # one label used for two people: switch at the first line containing "from"
            who = parts[0]['name']
            for l in raw:
                if l['speaker'] != lab:
                    continue
                for p in parts[1:]:
                    if p['from'].lower() in l['text'].lower():
                        who = p['name']
                l['speaker_resolved'] = who
        total = duration(mp3)
        srt = os.path.join(SRC, 'srt', f'{s["code"]}.srt')
        if os.path.exists(srt):
            times, unmatched = srt_times(raw, srt, mp3)
            if unmatched:
                print(f'{s["code"]}: {unmatched} lines placed between neighbours (no words matched in the SRT)')
        else:
            times = align(raw, mp3, total)
        lines = [{'id': f't{i + 1}', 'speaker': l.get('speaker_resolved') or smap[l['speaker']], 'text': l['text'],
                  'start': times[i],
                  'directions': [], 'keywords': [], 'answerTags': []} for i, l in enumerate(raw)]
        missing = locate_answers(lines, s['groups'])
        s['transcript'] = lines
        s['audioStatus'] = 'ready'
        s['durationSeconds'] = round(total)
        s['durationEstimated'] = False
        s['transcriptTiming'] = 'audio'
        applied += 1
        total_missing += len(missing)
        if fixed:
            print(f'{s["code"]}: questions fixed to match the recording')
        if missing:
            print(f'{s["code"]}: not found in the recording: ' + '; '.join(f'Q{n} {a}' for n, a in missing))
    if not check_only:
        with open(BANK, 'w', encoding='utf-8') as f:
            json.dump(bank, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{applied} sets with audio; {total_missing} completion answers not found in the recordings')


if __name__ == '__main__':
    main()
