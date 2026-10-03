#!/usr/bin/env python3
"""Import the IELTS Listening Question Bank PDF into the app.

Input:  the Eleven v4 production edition PDF (32 sets = 4 parts x 8 formats)
Output: assets/content/listening_bank.json  {meta, sets}

Everything in the PDF is kept:
  meta  - edition notes (what changed, how answers were checked, what to know),
          the Eleven v4 production guide, the set index, accent mix, part intros
  sets  - code, format, title, band, accent, time, tags, listening context,
          scenario, instructions, voices + production setup, the tagged
          ElevenLabs script (with chunks), questions in the app's group format,
          the answer key, the "Fields Summary" block
plus what the app derives from it: a student transcript (tags stripped,
spelled names joined, estimated line timings until real audio exists) and
answer locations for the transcript's "show answers" markers.

Question formats -> app group types:
  Form / Note Completion -> form (label: before ___ after) or notes
  Sentence Completion    -> sentence      Short-Answer Questions -> short
  Multiple Choice        -> mcq (+ multi for "choose TWO")
  Matching               -> matching (option box per group)
  Plan / Map / Diagram   -> map (letters A-J with their written positions)
  Table Completion       -> table (columns + rows; one question per blank)
  Summary Completion     -> summary (the paragraph; one question per blank)

Needs pdfplumber:  pip install pdfplumber
Usage:  python tool/import_listening_bank.py path/to/IELTS_Listening_Question_Bank.pdf
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'content', 'listening_bank.json')

FORMATS = {
    'FN': ('form_note', 'Form / Note Completion'),
    'MC': ('multiple_choice', 'Multiple Choice'),
    'MA': ('matching', 'Matching'),
    'PM': ('plan_map', 'Plan / Map / Diagram Labelling'),
    'SC': ('sentence', 'Sentence Completion'),
    'TC': ('table', 'Table Completion'),
    'SM': ('summary', 'Summary Completion'),
    'SA': ('short_answer', 'Short-Answer Questions'),
}

# ─────────────────────────────────────────────────────────────────────────────
# PDF -> lines of cells (words carry a bold flag and x position)
# ─────────────────────────────────────────────────────────────────────────────


class Line:
    def __init__(self, page, top, size, words):
        self.page = page
        self.top = top
        self.size = size
        self.words = words  # [(x0, x1, text, bold)]
        cells = []
        for w in words:
            if cells and w[0] - cells[-1]['x1'] < 9:
                cells[-1]['w'].append(w)
                cells[-1]['x1'] = w[1]
            else:
                cells.append({'x': w[0], 'x1': w[1], 'w': [w]})
        self.cells = cells

    @property
    def x(self):
        return self.words[0][0]

    @property
    def text(self):
        return ' '.join(w[2] for w in self.words)

    def cell_texts(self):
        return [' '.join(w[2] for w in c['w']) for c in self.cells]

    @property
    def first_bold(self):
        return self.words[0][3]

    @property
    def all_bold(self):
        return all(w[3] for w in self.words)

    def bold_prefix(self):
        out = []
        for w in self.words:
            if not w[3]:
                break
            out.append(w[2])
        return ' '.join(out)

    def near(self, size):
        return abs(self.size - size) < 0.3

    def __repr__(self):
        return f'<{self.page}:{self.size} {self.text[:60]}>'


def read_lines(path):
    import pdfplumber

    lines = []
    with pdfplumber.open(path) as pdf:
        for pi, page in enumerate(pdf.pages):
            words = page.extract_words(extra_attrs=['fontname', 'size'], x_tolerance=1.5)
            words = [w for w in words if w['top'] < 800]  # page footer
            words.sort(key=lambda w: (round(w['top']), w['x0']))
            rows = []
            for w in words:
                if rows and abs(rows[-1][0] - w['top']) < 2.5:
                    rows[-1][1].append(w)
                else:
                    rows.append([w['top'], [w]])
            for top, ws in rows:
                ws.sort(key=lambda w: w['x0'])
                lines.append(Line(
                    pi + 1, top, round(ws[0]['size'], 1),
                    [(w['x0'], w['x1'], w['text'], 'Bold' in w['fontname']) for w in ws],
                ))
    return lines


def clean(s):
    s = s.replace(' ', ' ')
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def join_wrapped(parts):
    """Joins wrapped lines (keeps hyphenated words like 'one-' + 'line')."""
    out = ''
    for p in parts:
        p = p.strip()
        if not p:
            continue
        out = p if not out else out + ' ' + p
    return clean(out)


# ─────────────────────────────────────────────────────────────────────────────
# Front matter
# ─────────────────────────────────────────────────────────────────────────────


def parse_meta(lines):
    meta = {'title': '', 'edition': '', 'summary': '', 'model': '', 'sections': [],
            'productionGuide': [], 'setIndex': [], 'accentMix': '', 'parts': []}
    i = 0
    head = []
    while i < len(lines) and not lines[i].near(12.5):
        head.append(lines[i])
        i += 1
    meta['title'] = head[0].text if head else ''
    rest = [l.text for l in head[1:]]
    if rest:
        meta['edition'] = rest[0]
    if len(rest) > 1:
        meta['summary'] = rest[1]
    if len(rest) > 2:
        meta['model'] = rest[2]

    while i < len(lines):
        l = lines[i]
        if l.near(12.5):
            heading = l.text
            i += 1
            if heading.startswith('Eleven v4 production guide') or heading.startswith('Set index'):
                rows = []
                header = lines[i].cell_texts()
                col_x = [c['x'] for c in lines[i].cells]
                i += 1
                while i < len(lines) and not lines[i].near(12.5) and not lines[i].near(17.0) \
                        and not lines[i].text.startswith('Accent mix'):
                    ln = lines[i]
                    if ln.text in (' '.join(header),) or ln.cell_texts() == header:
                        i += 1
                        continue
                    starts_row = abs(ln.cells[0]['x'] - col_x[0]) < 4
                    # A wrapped first-column label ("Numbers &" / "spelling")
                    # continues a row whose text has not finished its sentence.
                    if starts_row and rows and heading.startswith('Eleven') \
                            and not re.search(r'[.)]$', rows[-1][-1]):
                        starts_row = False
                    if starts_row:
                        rows.append([''] * len(header))
                    for c in ln.cells:
                        ci = max(k for k in range(len(col_x)) if c['x'] >= col_x[k] - 4)
                        txt = ' '.join(w[2] for w in c['w'])
                        if rows:
                            rows[-1][ci] = join_wrapped([rows[-1][ci], txt])
                    i += 1
                if heading.startswith('Eleven'):
                    meta['productionGuide'] = [{'topic': r[0], 'guidance': r[1]} for r in rows]
                else:
                    meta['setIndex'] = [
                        {'code': r[0], 'format': r[1], 'title': r[2], 'band': r[3], 'accent': r[4]}
                        for r in rows
                    ]
                continue
            bullets = []
            while i < len(lines) and not lines[i].near(12.5) and not lines[i].near(17.0):
                ln = lines[i]
                t = ln.text
                if t.startswith('•'):
                    lead = []
                    for w in ln.words[1:]:
                        if not w[3]:
                            break
                        lead.append(w[2])
                    lead_s = ' '.join(lead)
                    body = clean(t[1:].strip()[len(lead_s):]) if lead_s else clean(t[1:])
                    bullets.append({'lead': lead_s, 'text': body})
                elif bullets:
                    bullets[-1]['text'] = join_wrapped([bullets[-1]['text'], t])
                i += 1
            meta['sections'].append({'heading': heading, 'bullets': bullets})
            continue
        if l.text.startswith('Accent mix'):
            meta['accentMix'] = clean(l.text)
        if l.near(17.0):
            break
        i += 1
    return meta


# ─────────────────────────────────────────────────────────────────────────────
# Sets
# ─────────────────────────────────────────────────────────────────────────────

SET_HEAD = re.compile(r'^(P([1-4])-([A-Z]{2})) · (.+)$')


def split_sets(lines):
    parts = []
    sets = []
    cur = None
    i = 0
    while i < len(lines):
        l = lines[i]
        if l.near(17.0) and re.fullmatch(r'Part [1-4]', l.text):
            desc = lines[i + 1].text if i + 1 < len(lines) else ''
            parts.append({'part': int(l.text[-1]), 'description': desc})
            if cur:
                sets.append(cur)
                cur = None
            i += 2
            continue
        m = SET_HEAD.match(l.text)
        if m and l.near(10.0) and l.first_bold:
            if cur:
                sets.append(cur)
            cur = {'m': m, 'lines': []}
            i += 1
            continue
        if cur is not None:
            cur['lines'].append(l)
        i += 1
    if cur:
        sets.append(cur)
    return parts, sets


def take_table(lines, i, stop):
    """Two-column key/value table (production setup, fields summary)."""
    header_x = [c['x'] for c in lines[i].cells]
    i += 1
    rows = []
    while i < len(lines) and not stop(lines[i]):
        ln = lines[i]
        if abs(ln.cells[0]['x'] - header_x[0]) < 4 and len(ln.cells) >= 2:
            rows.append([ln.cell_texts()[0], ' '.join(ln.cell_texts()[1:])])
        elif rows:
            rows[-1][1] = join_wrapped([rows[-1][1], ln.text])
        i += 1
    return rows, i


def parse_answer_key(lines):
    """[Q ‖ Answer ‖ Q ‖ Answer] rows -> {n: text}."""
    out = {}
    last = [None, None]
    header_x = [c['x'] for c in lines[0].cells] if lines else []
    for ln in lines[1:]:
        cells = ln.cell_texts()
        xs = [c['x'] for c in ln.cells]
        k = 0
        side = 0
        consumed = False
        while k < len(cells):
            if re.fullmatch(r'\d+', cells[k]) and k + 1 < len(cells):
                n = int(cells[k])
                out[n] = cells[k + 1]
                side = 0 if (len(header_x) < 3 or xs[k] < header_x[2] - 4) else 1
                last[side] = n
                k += 2
                consumed = True
            else:
                # wrapped answer text
                side = 0 if (len(header_x) < 3 or xs[k] < header_x[2] - 4) else 1
                if last[side] is not None:
                    out[last[side]] = join_wrapped([out[last[side]], cells[k]])
                k += 1
        del consumed
    return out


LETTER = re.compile(r'^[A-J]$')


def option_rows(ol_lines):
    """Lines of bold-letter options (one or many per line, may wrap) -> [{key, text}]."""
    opts = []
    left = None
    row = []
    for ln in ol_lines:
        starts_opt = ln.words[0][3] and LETTER.match(ln.words[0][2])
        if starts_opt:
            if left is None:
                left = ln.x
            row = []
            for w in ln.words:
                if w[3] and LETTER.match(w[2]):
                    opts.append({'key': w[2], 'text': '', 'x': w[0]})
                    row.append(opts[-1])
                elif opts:
                    opts[-1]['text'] = join_wrapped([opts[-1]['text'], w[2]])
        else:
            # continuation: wrapped long option (starts at the left margin) or
            # a cell continuation in a multi-column option box.
            if left is not None and abs(ln.x - left) < 6:
                opts[-1]['text'] = join_wrapped([opts[-1]['text'], ln.text])
            else:
                for w in ln.words:
                    same_line = [o for o in (row or opts) if o['x'] <= w[0] + 6]
                    target = max(same_line, key=lambda o: o['x']) if same_line else opts[-1]
                    target['text'] = join_wrapped([target['text'], w[2]])
    return [{'key': o['key'], 'text': o['text']} for o in opts]


def q_number(ln):
    w = ln.words[0]
    m = re.fullmatch(r'(\d+)\.', w[2])
    return int(m.group(1)) if (m and w[3]) else None


def heading_text(ln):
    t = ln.text
    m = re.match(r'^Questions (\d+)[-–](\d+)\s*[—-]\s*(.*)$', t)
    if m:
        return {'from': int(m.group(1)), 'to': int(m.group(2)), 'title': m.group(3).strip()}
    return {'from': None, 'to': None, 'title': t.strip()}


def is_heading(ln):
    return ln.near(9.5) and ln.all_bold and q_number(ln) is None


def blocks_of(qlines):
    """Splits the question area into [heading, [lines]] groups."""
    groups = []
    for ln in qlines:
        if is_heading(ln):
            if groups and groups[-1]['lines'] == [] and groups[-1]['head'] is not None:
                # heading wrapped onto a second bold line
                groups[-1]['head']['title'] = clean(groups[-1]['head']['title'] + ' ' + ln.text)
                continue
            groups.append({'head': heading_text(ln), 'lines': []})
        else:
            if not groups:
                groups.append({'head': None, 'lines': []})
            groups[-1]['lines'].append(ln)
    return groups


def numbered(lines_):
    """[(n, text, extra_lines)] for '**N.** text' lines (+ wrapped continuation)."""
    out = []
    for ln in lines_:
        n = q_number(ln)
        if n is not None:
            out.append([n, clean(ln.text[len(ln.words[0][2]):]), []])
        elif out:
            out[-1][2].append(ln)
    return out


def blank_text(s):
    return re.sub(r'_{3,}', '______', s)


def word_limit(instructions):
    m = re.search(r'(Write [^.]*?(?:for each answer|next to [^.]*)\.)', instructions)
    return m.group(1) if m else ''


def split_label(text):
    """'Child's name: Oliver ___' -> (label, before, after)."""
    label = ''
    rest = text
    m = re.match(r'^([^:_]{1,60}):\s*(.*)$', text)
    if m:
        label, rest = m.group(1).strip(), m.group(2)
    parts = re.split(r'_{3,}', rest, maxsplit=1)
    before = parts[0].strip()
    after = parts[1].strip() if len(parts) > 1 else ''
    return label, before, after


BLANK = re.compile(r'\((\d+)\)_{3,}')


def blank_context(s, n):
    """Text around blank (n) in s; other blanks shown as '(m) …'."""
    parts = s.split(f'({n})___', 1)
    if len(parts) != 2:
        return s, ''
    tidy = lambda x: BLANK.sub(lambda m: f'({m.group(1)}) …', x)
    return tidy(parts[0]).strip(), tidy(parts[1]).strip()


def gap_join(before, after):
    sep = '' if re.match(r'^[,.;:!?)]', after) else ' '
    lead = '' if (not before or before.endswith(('£', '$', '('))) else ' '
    return clean(f'{before}{lead}______{sep}{after}')


def parse_table(lines_):
    """Header + rows with wrapped cells -> (columns, rows)."""
    header = lines_[0]
    col_x = [c['x'] for c in header.cells]
    columns = header.cell_texts()
    rows = []
    for ln in lines_[1:]:
        starts_row = abs(ln.cells[0]['x'] - col_x[0]) < 4
        if starts_row:
            rows.append([''] * len(columns))
        for c in ln.cells:
            ci = max(k for k in range(len(col_x)) if c['x'] >= col_x[k] - 4)
            txt = ' '.join(w[2] for w in c['w'])
            if rows:
                rows[-1][ci] = join_wrapped([rows[-1][ci], txt])
    return columns, rows


def map_image(code, n):
    """assets/listening/maps/<CODE>_map<n>.png (drawn by tool/draw_listening_maps.py) if it exists."""
    rel = f'assets/listening/maps/{code}_map{n}.png'
    return rel if os.path.exists(os.path.join(ROOT, rel)) else ''


def build_groups(code, fmt, qlines, answers, instructions):
    limit = word_limit(instructions)
    groups = []
    gi = 0

    def new_group(gtype, title, instruction, **extra):
        nonlocal gi
        gi += 1
        g = {'id': f'g{gi}', 'type': gtype, 'title': title, 'instruction': instruction}
        g.update(extra)
        g['questions'] = []
        groups.append(g)
        return g

    def text_answer(n):
        return answers.get(n, '')

    blocks = blocks_of(qlines)

    if fmt in ('FN', 'SC', 'SA'):
        for b in blocks:
            head = b['head']
            title = head['title'] if head else ''
            if fmt == 'FN':
                is_form = 'FORM' in title.upper() and 'NOTES' not in title.upper()
                gtype = 'form' if is_form else 'notes'
                g = new_group(gtype, title.title() if title.isupper() else title or 'Complete the notes', limit)
                if is_form:
                    g['formTitle'] = title.split(':')[0].title() if ':' in title else title.title()
                    g['formSubtitle'] = title.split(':', 1)[1].strip().capitalize() if ':' in title else ''
                    g['title'] = 'Complete the form'
            elif fmt == 'SC':
                g = new_group('sentence', title or 'Complete the sentences', limit)
            else:
                g = new_group('short', title or 'Answer the questions', limit)
            for n, text, extra in numbered(b['lines']):
                text = join_wrapped([text] + [e.text for e in extra])
                q = {'number': n}
                if g['type'] == 'form':
                    label, before, after = split_label(text)
                    q.update({'label': label, 'before': before, 'after': after})
                elif g['type'] == 'short':
                    q['text'] = text
                else:
                    q['text'] = blank_text(text)
                    q['source'] = text
                q.update(answer_fields(text_answer(n)))
                g['questions'].append(q)
        return groups

    if fmt == 'MC':
        single = None
        items = numbered([l for b in blocks for l in b['lines']])
        k = 0
        while k < len(items):
            n, text, extra = items[k]
            two = re.search(r'\((first|second) answer\)\s*$', text)
            if two:
                # "Which TWO …" = one item worth two numbers
                n2, text2, extra2 = items[k + 1]
                stem = clean(re.sub(r'\((first|second) answer\)\s*$', '', text))
                opts = option_rows(extra2 or extra)
                g = new_group('multi', 'Choose TWO letters, A–E', limit_multi(instructions), pick=2)
                letters = [re.match(r'([A-J])', answers.get(x, '')).group(1) for x in (n, n2)]
                g['questions'].append({'number': n, 'text': stem, 'options': opts, 'answer': letters,
                                       'answerKey': {str(n): answers.get(n, ''), str(n2): answers.get(n2, '')}})
                k += 2
                continue
            if single is None:
                single = new_group('mcq', 'Choose the correct letter, A, B or C', '')
            qtext = text
            opt_lines = extra
            if extra and not (extra[0].first_bold and LETTER.match(extra[0].words[0][2])):
                # wrapped question stem before the options
                j = 0
                while j < len(extra) and not (extra[j].first_bold and LETTER.match(extra[j].words[0][2])):
                    qtext = join_wrapped([qtext, extra[j].text])
                    j += 1
                opt_lines = extra[j:]
            single['questions'].append({'number': n, 'text': qtext, 'options': option_rows(opt_lines),
                                        'answer': letter_of(answers.get(n, ''))})
            k += 1
        return groups

    if fmt == 'MA':
        for b in blocks:
            head = b['head']
            opt_lines = [l for l in b['lines'] if q_number(l) is None and l.first_bold and LETTER.match(l.words[0][2])]
            # include wrapped option-box lines (non-numbered, before the first question)
            box = []
            for l in b['lines']:
                if q_number(l) is not None:
                    break
                box.append(l)
            opts = option_rows(box or opt_lines)
            keys = [o['key'] for o in opts]
            instr = f"Choose the correct letter, {keys[0]}–{keys[-1]}, for each question." if keys else ''
            if 'more than once' in instructions:
                instr += ' You may use any letter more than once.'
            g = new_group('matching', head['title'] if head else 'Matching', instr, options=opts)
            for n, text, extra in numbered(b['lines']):
                g['questions'].append({'number': n, 'text': join_wrapped([text] + [e.text for e in extra]),
                                       'answer': letter_of(answers.get(n, ''))})
        return groups

    if fmt == 'PM':
        for b in blocks:
            head = b['head']
            layout_lines = []
            for l in b['lines']:
                if q_number(l) is not None:
                    break
                layout_lines.append(l.text)
            layout = join_wrapped(layout_lines)
            intro = layout
            opts = []
            m0 = re.search(r'(?:^|\s)A = ', layout)
            if m0:
                intro = layout[:m0.start()].strip()
                body = layout[m0.start():].strip()
                for m in re.finditer(r'([A-J]) = (.*?)(?=\s·\s[A-J] = |$)', body):
                    opts.append({'key': m.group(1), 'text': m.group(2).strip()})
            intro = re.sub(r'^Layout:\s*', '', intro).strip()
            keys = [o['key'] for o in opts]
            g = new_group(
                'map', head['title'] if head else 'Label the plan',
                f"Write the correct letter, {keys[0]}–{keys[-1]}, next to each question." if keys else '',
                layout=layout, layoutIntro=intro, options=opts, image=map_image(code, len(groups) + 1),
            )
            for n, text, extra in numbered(b['lines']):
                g['questions'].append({'number': n, 'text': join_wrapped([text] + [e.text for e in extra]),
                                       'answer': letter_of(answers.get(n, ''))})
        return groups

    if fmt == 'TC':
        for b in blocks:
            head = b['head']
            tl = [l for l in b['lines']]
            if not tl:
                continue
            columns, rows = parse_table(tl)
            g = new_group('table', head['title'] if head else 'Complete the table', limit,
                          columns=columns, rows=rows)
            found = []
            for ri, row in enumerate(rows):
                for ci, cell in enumerate(row):
                    for m in BLANK.finditer(cell):
                        n = int(m.group(1))
                        before, after = blank_context(cell, n)
                        label = row[0] if ci > 0 else columns[0]
                        if len(columns) > 2 and ci > 0:
                            label = f'{row[0]} · {columns[ci]}'
                        found.append((n, {'number': n, 'label': label, 'before': before, 'after': after,
                                          'row': ri, 'col': ci}))
            for n, q in sorted(found):
                q.update(answer_fields(text_answer(n)))
                g['questions'].append(q)
        return groups

    if fmt == 'SM':
        for b in blocks:
            head = b['head']
            para = join_wrapped([l.text for l in b['lines']])
            g = new_group('summary', head['title'] if head else 'Complete the summary', limit, summary=para)
            sentences = re.split(r'(?<=[.?!])\s+(?=[A-Z(£$])', para)
            found = []
            for s in sentences:
                for m in BLANK.finditer(s):
                    n = int(m.group(1))
                    before, after = blank_context(s, n)
                    found.append((n, {'number': n, 'text': gap_join(before, after),
                                      'before': before, 'after': after}))
            for n, q in sorted(found):
                q.update(answer_fields(text_answer(n)))
                g['questions'].append(q)
        return groups

    raise ValueError(f'{code}: unknown format')


def limit_multi(instructions):
    m = re.search(r'(choose TWO[^.]*\.)', instructions, re.I)
    return m.group(1)[0].upper() + m.group(1)[1:] if m else 'Choose TWO letters.'


def letter_of(a):
    m = re.match(r'\s*([A-J])\b', a)
    return m.group(1) if m else a.strip()


def expand_optional(s):
    """'(Garry) Kasparov' -> ['Garry Kasparov', 'Kasparov']."""
    m = re.search(r'\(([^)]*)\)', s)
    if not m:
        return [clean(s)]
    with_ = s[:m.start()] + m.group(1) + s[m.end():]
    without = s[:m.start()] + s[m.end():]
    return expand_optional(with_) + expand_optional(without)


def answer_fields(key):
    """Answer-key text -> {answer, answerDisplay (as printed), accepted [...]}."""
    key = clean(key)
    alts = [a.strip() for a in re.split(r'\s/\s', key) if a.strip()]
    accepted = []
    for a in alts:
        for v in expand_optional(a):
            v = clean(v)
            if v and v not in accepted:
                accepted.append(v)
            if re.fullmatch(r'[\d ]+', v) and ' ' in v:
                nv = v.replace(' ', '')
                if nv not in accepted:
                    accepted.append(nv)
    # answer = first accepted form (what the checker compares); answerDisplay =
    # the key exactly as printed ("10 / ten") for the results screen.
    return {'answer': accepted[0] if accepted else key, 'answerDisplay': key, 'accepted': accepted}


# ─────────────────────────────────────────────────────────────────────────────
# Script -> transcript
# ─────────────────────────────────────────────────────────────────────────────

TAG = re.compile(r'\[([^\]]+)\]')


def student_text(raw):
    t = TAG.sub(' ', raw)
    t = re.sub(r'\s*"/[^"]*/"', '', t)  # IPA pronunciation hints
    # Spelled words: "B... R... A... N..." / "T... U... double L..." -> B-R-A-N / T-U-double L
    unit = r'(?:double |triple )?[A-Z]'
    spelled = re.compile(rf'\b({unit})(?:\.\.\.|…)\s+((?:{unit}(?:\.\.\.|…)\s+)*{unit})(?:\.\.\.|…)?(?=[\s.,!?]|$)')

    def join(m):
        letters = re.findall(unit, m.group(0))
        return '-'.join(letters)

    t = spelled.sub(join, t)
    t = t.replace('...', '…')
    t = re.sub(r'\s+([,.!?;:])', r'\1', t)
    return clean(t)


def words_for_number(n):
    ones = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
            'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen',
            'nineteen']
    tens = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety']
    if n < 20:
        return [ones[n]]
    if n < 100:
        return [tens[n // 10] + ('' if n % 10 == 0 else '-' + ones[n % 10])]
    if n < 1000:
        h, r = divmod(n, 100)
        head = f'{ones[h]} hundred'
        out = [head, 'a hundred'] if h == 1 else [head]
        if r:
            tail = words_for_number(r)[0]
            out = [f'{x} and {tail}' for x in out]
        return out
    if n < 1000000 and n % 1000 == 0:
        return [f'{w} thousand' for w in words_for_number(n // 1000)]
    return []


def answer_needles(q):
    """Phrases that may show a completion answer in the transcript."""
    digit_words = ['oh', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']

    def one_by_one(ds):
        plain = ' '.join(digit_words[int(c)] for c in ds)
        doubled = re.sub(r'\b(\w+) \1\b', r'double \1', plain)
        return [plain, doubled, plain.replace(' ', '-'), doubled.replace(' ', '-')]

    out = []
    for a in q.get('accepted', []):
        out.append(a)
        digits = re.sub(r'[£$%,]', '', a)
        if re.fullmatch(r'\d+', digits):
            n = int(digits)
            out.extend(words_for_number(n))
            if 1100 <= n <= 2099 and n % 100:
                hi, lo = divmod(n, 100)
                out.append(f'{words_for_number(hi)[0]} {("oh-" + words_for_number(lo)[0]) if lo < 10 else words_for_number(lo)[0]}')
            if n >= 1000 and n % 500 == 0 and n % 1000:
                out.append(f'{words_for_number(n // 1000)[0]} and a half thousand')
            if n >= 1000 and n % 100 == 0 and n % 1000:
                out.append(f'{words_for_number(n // 1000)[0]} thousand {words_for_number((n % 1000) // 100)[0]} hundred')
            if len(digits) >= 3:
                out.extend(one_by_one(digits))
        mt = re.fullmatch(r'(\d{1,2})[.:](\d{2})(?:\s*[ap]\.?m\.?)?', a.strip())
        if mt:
            h, mm = int(mt.group(1)), int(mt.group(2))
            hw = words_for_number(h)[0]
            if mm == 0:
                out += [f"{hw} o'clock", hw]
            else:
                out.append(f'{hw} {words_for_number(mm)[0] if mm >= 10 else "oh-" + words_for_number(mm)[0]}')
                if mm == 30:
                    out.append(f'half past {hw}')
                if mm == 15:
                    out.append(f'quarter past {hw}')
        mp = re.fullmatch(r'0\d{3,4} ?\d{5,7}', a.strip())
        if mp:
            ds = re.sub(r'\D', '', a)
            out.append('-'.join(digit_words[int(c)] for c in ds[:5]))
        if re.fullmatch(r'\d{1,2}\s*[ap]\.?m\.?', a.strip()):
            out.append(words_for_number(int(re.match(r'\d+', a.strip()).group(0)))[0] + ' a.m.' if 'a' in a else ' p.m.')
    return [o for o in out if o]


def build_transcript(script, groups):
    lines = []
    t = 1.0
    for i, s in enumerate(script):
        text = student_text(s['text'])
        if not text:
            continue
        tags = TAG.findall(s['text'])
        words = len(text.replace('-', ' ').split())
        pauses = sum(1 for g in tags if 'pause' in g.lower())
        dur = words / 2.6 + 0.35 + pauses * 0.6
        lines.append({'id': f't{len(lines) + 1}', 'speaker': s['speaker'], 'text': text,
                      'start': round(t, 1), 'directions': tags, 'keywords': [], 'answerTags': []})
        t += dur
    end = t + 1.0

    # Answer markers for completion questions, located in question order.
    cursor = 0
    for g in groups:
        if g['type'] in ('mcq', 'multi', 'matching', 'map'):
            continue
        for q in g['questions']:
            hit = None
            for li in range(cursor, len(lines)):
                low = lines[li]['text'].lower()
                for needle in answer_needles(q):
                    nd = needle.lower()
                    letters = '-'.join(nd.replace(' ', '')) if re.fullmatch(r'[a-z]+', nd) and len(nd) > 3 else None
                    for cand in ([nd] + ([letters] if letters else [])):
                        m = re.search(r'(?<![a-z0-9])' + re.escape(cand) + r'(?![a-z0-9])', low)
                        if m:
                            hit = (li, lines[li]['text'][m.start():m.end()])
                            break
                    if hit:
                        break
                if hit:
                    break
            if hit:
                li, phrase = hit
                # A name is usually spelled out right after it is said: mark the spelling.
                spelled = '-'.join(re.sub(r'[^A-Za-z]', '', phrase).upper())
                if len(spelled) > 5:
                    for lj in range(li + 1, min(li + 4, len(lines))):
                        k = lines[lj]['text'].upper().find(spelled)
                        if k >= 0:
                            li, phrase = lj, lines[lj]['text'][k:k + len(spelled)]
                            break
                lines[li]['keywords'].append(phrase)
                lines[li]['answerTags'].append({'after': phrase, 'question': q['number']})
                cursor = li
    return lines, round(end)


# ─────────────────────────────────────────────────────────────────────────────


def parse_set(raw):
    m = raw['m']
    code, part, fcode, flabel = m.group(1), int(m.group(2)), m.group(3), m.group(4)
    L = raw['lines']
    i = 0
    title = []
    while i < len(L) and L[i].near(16.0):
        title.append(L[i].text)
        i += 1
    info = []
    while i < len(L) and L[i].near(9.0):
        info.append(L[i].text)
        i += 1
    info_s = join_wrapped(info)
    mi = re.match(r'Part (\d) · Band ([\d.]+) · ([^·(]+?) \(([^)]+)\) · ~(\d+) min · tags: (.*)$', info_s)
    labels = {}
    cur = None
    while i < len(L) and not (L[i].near(10.5) and L[i].text.startswith('Eleven v4 production setup')):
        ln = L[i]
        bp = ln.bold_prefix()
        if bp.endswith(':'):
            cur = bp[:-1]
            labels[cur] = clean(ln.text[len(bp):])
        elif cur:
            labels[cur] = join_wrapped([labels[cur], ln.text])
        i += 1
    i += 1  # production setup heading
    setup_rows, i = take_table(L, i, lambda l: l.near(10.5))
    i += 1  # script heading
    if i < len(L) and L[i].text.startswith('Copy from here'):
        copy_note = L[i].text
        i += 1
    else:
        copy_note = ''
    voices = [(r[0][len('Voice: '):], r[1]) for r in setup_rows if r[0].startswith('Voice: ')]
    names = sorted([v[0] for v in voices], key=len, reverse=True)
    script = []
    chunk = 0
    while i < len(L) and not (L[i].near(10.5) and L[i].text == 'Questions'):
        ln = L[i]
        t = ln.text
        mc = re.match(r'^—\s*Chunk (\d+) of (\d+)\s*—$', t)
        if mc:
            chunk = int(mc.group(1))
        else:
            sp = None
            for nm in names:
                if t.startswith(nm + ':') and ln.first_bold:
                    sp = nm
                    break
            if sp:
                script.append({'speaker': sp, 'text': clean(t[len(sp) + 1:]), 'chunk': chunk or None})
            elif script:
                script[-1]['text'] = join_wrapped([script[-1]['text'], t])
        i += 1
    i += 1  # Questions heading
    qlines = []
    while i < len(L) and not (L[i].near(10.5) and L[i].text == 'Answer Key'):
        qlines.append(L[i])
        i += 1
    i += 1
    ak = []
    while i < len(L) and not (L[i].near(10.5) and 'Fields Summary' in L[i].text):
        ak.append(L[i])
        i += 1
    answers = parse_answer_key(ak)
    i += 1
    fields_rows, i = take_table(L, i, lambda l: False) if i < len(L) else ([], i)
    fields = {k: v for k, v in fields_rows}

    instructions = labels.get('Instructions', '')
    groups = build_groups(code, fcode, qlines, answers, instructions)

    setup = {k: v for k, v in setup_rows}
    stab = re.search(r'Stability ≈ ([\d.]+)', setup.get('Voice settings', ''))
    sim = re.search(r'Similarity ≈ ([\d.]+)', setup.get('Voice settings', ''))
    chars = re.search(r'([\d,]+) characters', setup.get('Script length', ''))
    model_tool = setup.get('Model / tool', '')
    speakers = []
    for name, desc in voices:
        role, _, rest = desc.partition(' — ')
        gender = 'female' if re.search(r'\bfemale\b', rest) else ('male' if re.search(r'\bmale\b', rest) else '')
        speakers.append({'name': name, 'role': role.strip(), 'description': desc, 'voice': gender})

    transcript, duration = build_transcript(script, groups)
    fmt_id, fmt_label = FORMATS[fcode]
    audio_key = re.sub(r'\s*\(pending.*$', '', fields.get('audio_asset', '')).strip()
    total_q = sum((g.get('pick') or 1) * len(g['questions']) for g in groups)
    return {
        'id': f'lb_{code.lower().replace("-", "_")}',
        'code': code,
        'part': part,
        'format': fmt_id,
        'formatCode': fcode,
        'formatLabel': flabel or fmt_label,
        'title': join_wrapped(title),
        'band': float(mi.group(2)) if mi else None,
        'accent': mi.group(3).strip() if mi else '',
        'locale': mi.group(4) if mi else '',
        'minutes': int(mi.group(5)) if mi else None,
        'tags': [t.strip() for t in mi.group(6).split(',')] if mi else [],
        'listeningContext': labels.get('Listening context', ''),
        'scenario': labels.get('Scenario', ''),
        'context': labels.get('Scenario', ''),
        'instructions': instructions,
        'wordLimit': word_limit(instructions),
        'questionCount': total_q,
        'audio': f'assets/audio/listening/{code}.mp3',
        'audioKey': audio_key,
        'audioStatus': 'pending',
        'durationSeconds': duration,
        'durationEstimated': True,
        'transcriptTiming': 'estimated',  # until the recording exists
        'answerMarkers': 'auto',  # completion answers located in the script by the importer
        'speakers': speakers,
        'production': {
            'model': model_tool.split(' · ')[0].strip(),
            'tool': model_tool.split(' · ', 1)[1].strip() if ' · ' in model_tool else '',
            'stability': float(stab.group(1)) if stab else None,
            'similarity': float(sim.group(1)) if sim else None,
            'locale': setup.get('Accent / locale', ''),
            'scriptChars': int(chars.group(1).replace(',', '')) if chars else None,
            'scriptLength': setup.get('Script length', ''),
            'chunks': max([s['chunk'] or 0 for s in script] + [0]) or 1,
            'copyNote': copy_note,
            'setup': [{'setting': k, 'value': v} for k, v in setup_rows],
        },
        'script': script,
        'transcript': transcript,
        'groups': groups,
        'answerKey': {str(k): v for k, v in sorted(answers.items())},
        'fields': fields,
    }


def check(sets):
    problems = []
    for s in sets:
        nums = []
        for g in s['groups']:
            for q in g['questions']:
                span = g.get('pick') or 1
                nums.extend(range(q['number'], q['number'] + span))
                if g['type'] in ('mcq', 'matching', 'map'):
                    keys = [o['key'] for o in (g['options'] if g['type'] != 'mcq' else q['options'])]
                    if q['answer'] not in keys:
                        problems.append(f"{s['code']} Q{q['number']}: answer {q['answer']} not in options")
                if g['type'] == 'mcq' and len(q['options']) < 3:
                    problems.append(f"{s['code']} Q{q['number']}: {len(q['options'])} options")
                if g['type'] not in ('mcq', 'multi', 'matching', 'map') and not q.get('accepted'):
                    problems.append(f"{s['code']} Q{q['number']}: no answer")
        if sorted(nums) != list(range(1, 21)):
            problems.append(f"{s['code']}: questions {sorted(nums)}")
        if len(s['answerKey']) != 20:
            problems.append(f"{s['code']}: {len(s['answerKey'])} answers in key")
        if not s['script'] or len(s['speakers']) == 0:
            problems.append(f"{s['code']}: no script / speakers")
        spk = {p['name'] for p in s['speakers']}
        if any(x['speaker'] not in spk for x in s['script']):
            problems.append(f"{s['code']}: unknown speaker in script")
    return problems


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    lines = read_lines(sys.argv[1])
    first_set = next(i for i, l in enumerate(lines) if l.near(17.0) and re.fullmatch(r'Part [1-4]', l.text))
    meta = parse_meta(lines[:first_set])
    parts, raw_sets = split_sets(lines[first_set:])
    meta['parts'] = parts
    meta['source'] = re.sub(r'^[0-9a-f]{8}-', '', os.path.basename(sys.argv[1]))
    sets = [parse_set(r) for r in raw_sets]
    problems = check(sets)
    for p in problems:
        print('CHECK:', p)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump({'meta': meta, 'sets': sets}, f, ensure_ascii=False, separators=(',', ':'))
    located = sum(len(l['answerTags']) for s in sets for l in s['transcript'])
    completion = sum(len(g['questions']) for s in sets for g in s['groups']
                     if g['type'] not in ('mcq', 'multi', 'matching', 'map'))
    print(f'{len(sets)} sets, {sum(s["questionCount"] for s in sets)} questions -> {OUT} '
          f'({os.path.getsize(OUT) // 1024} KB); answers located in transcript: {located}/{completion}')
    # recorded audio: real transcripts and timings, questions fitted to the recordings
    if os.path.isdir(os.path.join(ROOT, 'seed', 'sources', 'listening_audio')):
        import subprocess
        subprocess.run([sys.executable, os.path.join(ROOT, 'tool', 'apply_listening_audio.py')], check=True)


if __name__ == '__main__':
    main()
