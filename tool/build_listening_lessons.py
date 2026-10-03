#!/usr/bin/env python3
"""Build the Listening Bite-size Lessons from clips of the real recordings.

Each lesson is a short stretch of one question-bank recording (assets/audio/listening/<code>.mp3) that holds a few
completion questions. The clip is cut between pauses (from the set's timed transcript), saved as
assets/audio/listening/<lesson id>.mp3, and the lesson's gap-fill rows are the bank questions answered inside it,
renumbered from 1 (answers and accepted spellings come from the bank).

usage: python3 tool/build_listening_lessons.py      (then python3 tool/merge_demo.py)
Writes assets/demo/parts/listening.json → lessons, and the clip files. Needs ffmpeg / ffprobe.
"""
import json
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BANK = os.path.join(ROOT, 'assets', 'content', 'listening_bank.json')
PART = os.path.join(ROOT, 'assets', 'demo', 'parts', 'listening.json')
AUDIO = os.path.join(ROOT, 'assets', 'audio', 'listening')

# id, title, set code, first transcript line, last transcript line, lesson note
LESSONS = [
    ('ll_06', 'Spelling names', 'P1-FN', 2, 13,
     'Part 1 speakers often **spell** names and streets letter by letter. Write each letter as you hear it, then '
     'check the whole word. Phone numbers come in small groups — write them exactly as they are read.'),
    ('ll_07', 'Numbers & prices', 'P2-FN', 12, 16,
     'Numbers are easy marks if you are ready for them. Before the audio, look at what sits next to each gap '
     '(**£**, a phone code, "under …") so you know exactly which kind of number to listen for.'),
    ('ll_08', 'Signpost words', 'P4-FN', 0, 5,
     'In a lecture, the notes follow the speaker\'s order. **Signposts** such as "before we start", "to count '
     'species" or "the frames we use" tell you the speaker has moved to the next line of your notes.'),
    ('ll_09', 'Hearing the correction', 'P1-FN', 14, 22,
     'Speakers change their minds: "here in Hadley?" — "No… **actually**, Ashford." Words like **actually**, '
     '**but** and **so** warn you that the first idea is not the answer, so wait for the final version.'),
    ('ll_10', 'Predict the gap', 'P1-SC', 1, 9,
     'Before the audio starts, read each sentence and **predict** the missing word: a day? a length of time? '
     'a number? Knowing what you need makes the answer stand out — and the distractor (12 weeks) easier to skip.'),
    ('ll_11', 'Reading a table', 'P1-TC', 0, 10,
     'Read a table **across each row**: company, price, what is included, notice needed. The speaker usually '
     'follows that order, so move your eyes along the row as you listen.'),
    ('ll_12', 'Word limits', 'P1-SA', 15, 22,
     'Short answers have a **word limit**. "Closed shoes" is two words — fine; "a pair of closed shoes" is too '
     'many and is marked wrong. Write only the key words you hear.'),
    ('ll_13', 'Paraphrase in lectures', 'P4-SC', 0, 7,
     'The sentences you complete **paraphrase** the lecture: "in the dark" becomes "at night". Listen for the '
     'meaning, not for the exact words printed in the question.'),
    ('ll_14', 'Following a discussion', 'P3-FN', 1, 11,
     'In Part 3, students and a tutor talk things through and often **change the plan**: "we\'d planned for 20 '
     'minutes…". Note the final decision, and who is doing which part.'),
]

LETTER_TYPES = ('mcq', 'multi', 'matching', 'map')
WORD_LIMIT = re.compile(r'Write (.+?) for each answer\.?', re.I)


def silences(path):
    """[(start, end)] of the pauses in a recording."""
    err = subprocess.run(['ffmpeg', '-hide_banner', '-i', path, '-af', 'silencedetect=noise=-40dB:d=0.25',
                          '-f', 'null', '-'], capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r'silence_start: ([0-9.]+)', err)]
    ends = [float(x) for x in re.findall(r'silence_end: ([0-9.]+)', err)]
    return list(zip(starts, ends))


def snap(t, quiet, before, after, at_end):
    """Move a cut to the middle-ish of the nearest pause around [t]; unchanged if none is close."""
    near = [(a, b) for a, b in quiet if b >= t - before and a <= t + after]
    if not near:
        return t
    a, b = min(near, key=lambda ab: abs((ab[0] + ab[1]) / 2 - t))
    return min(a + 0.25, (a + b) / 2) if at_end else max(b - 0.2, (a + b) / 2)


def ffprobe_duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip())


def row_text(group, q):
    """(before, after) for the gap line, from the bank question."""
    t = group['type']
    if t == 'form':
        before = q.get('label', '').strip()
        before = f'{before}:' if before else ''
        if q.get('before'):
            before = f'{before} {q["before"]}'.strip()
        return before, q.get('after', '')
    if t == 'table':
        before = f'{q.get("label", "")}:'.replace(' · ', ' — ')
        if q.get('before'):
            before = f'{before} {q["before"]}'
        return before, q.get('after', '')
    if t == 'short':
        return q.get('text', ''), ''
    text = q.get('text') or q.get('source') or ''
    parts = re.split(r'_{2,}', text, maxsplit=1)
    if len(parts) == 2:
        return parts[0].strip(), parts[1].strip()
    return text, ''


def main():
    bank = {s['code']: s for s in json.load(open(BANK, encoding='utf-8'))['sets']}
    part = json.load(open(PART, encoding='utf-8'))
    lessons = []
    for lid, title, code, first, last, body in LESSONS:
        s = bank[code]
        tr = s['transcript']
        qs = {q['number']: (g, q) for g in s['groups'] if g['type'] not in LETTER_TYPES for q in g['questions']}
        numbers = []
        for line in tr[first:last + 1]:
            for tag in line.get('answerTags', []):
                if tag['question'] in qs and tag['question'] not in numbers:
                    numbers.append(tag['question'])
        numbers.sort()
        # cut inside the pauses around the window
        src = os.path.join(AUDIO, f'{code}.mp3')
        quiet = silences(src)
        start = 0.0 if first == 0 else max(0.0, snap(tr[first]['start'], quiet, 1.0, 0.6, False))
        end = (snap(tr[last + 1]['start'], quiet, 1.5, 0.4, True) if last + 1 < len(tr)
               else ffprobe_duration(src))
        out = os.path.join(AUDIO, f'{lid}.mp3')
        length = end - start
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{start:.2f}', '-t', f'{length:.2f}', '-i', src,
                        '-af', f'afade=t=in:d=0.25,afade=t=out:st={max(0, length - 0.4):.2f}:d=0.4',
                        '-ac', '1', '-ar', '44100', '-b:a', '96k', out], check=True)
        rows = []
        limit = ''
        for i, n in enumerate(numbers, 1):
            g, q = qs[n]
            before, after = row_text(g, q)
            if after.strip() in ('.', ',', '?'):
                after = ''
            m = WORD_LIMIT.search(g.get('instruction', ''))
            limit = limit or (m.group(1) if m else '')
            rows.append({'number': i, 'before': before, 'after': after,
                         'answer': q.get('answerDisplay') or q['answer'],
                         'accepted': q.get('accepted') or [q['answer']]})
        lessons.append({
            'id': lid,
            'title': title,
            'body': body,
            'audio': f'assets/audio/listening/{lid}.mp3',
            'audioDurationSeconds': round(ffprobe_duration(out), 1),
            'instruction': f'Exercise · Write {limit}' if limit else 'Exercise',
            'source': {'set': s['id'], 'code': code, 'title': s['title'], 'from': round(start, 2), 'to': round(end, 2)},
            'rows': rows,
        })
        print(f'{lid}  {code}  {start:6.1f}–{end:6.1f}s  {len(rows)} rows  {title}')
    part['lessons'] = lessons
    with open(PART, 'w', encoding='utf-8') as f:
        json.dump(part, f, ensure_ascii=False, indent=2)
        f.write('\n')


if __name__ == '__main__':
    main()
