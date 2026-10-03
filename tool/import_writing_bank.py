#!/usr/bin/env python3
"""Import the IELTS Academic Writing question banks (Task 1 + Task 2 PDFs).

Input:  IELTS_Writing_Task1_Question_Bank.pdf  (140 questions, 7 visual types)
        IELTS_Writing_Task2_Question_Bank.pdf  (120 questions, 6 essay types)
        seed/staging/writing_samples/<id>.json  (Band 6 / 7 / 8 sample answers, optional)
Output: assets/content/writing_bank.json  {meta, task1, task2}
        assets/writing/task1/<id>.webp     (the rendered visual of each Task 1 question)

Everything in the PDFs is kept:
  Task 1 - question text + instructions, the visual (as the PDF drew it), the
           complete visual data (structured panels + the data as printed, which
           the AI grader reads), and the image-generation prompt
  Task 2 - question type, topic, difficulty, question text + instructions
  meta   - title, notes, section index, the summary tables
plus the app's prompt fields (type keys, title, chart for the native renderer
where the data fits it) and, when present, the sample answers.

Needs: pdftotext / pdfimages (poppler) and Pillow.
Usage: python tool/import_writing_bank.py <task1.pdf> <task2.pdf>
"""
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'content', 'writing_bank.json')
IMG_DIR = os.path.join(ROOT, 'assets', 'writing', 'task1')
SAMPLES = os.path.join(ROOT, 'seed', 'staging', 'writing_samples')

T1_TYPES = {
    'Line Graph': ('line', 'Line graph'),
    'Bar Chart': ('bar', 'Bar chart'),
    'Pie Chart': ('pie', 'Pie chart'),
    'Table': ('table', 'Table'),
    'Map / Plan': ('map', 'Map / plan'),
    'Process Diagram': ('process', 'Process diagram'),
    'Combination / Mixed Charts': ('mixed', 'Combination'),
}
T2_TYPES = {
    'Opinion': 'opinion',
    'Discussion': 'discussion',
    'Advantages & Disadvantages': 'advantages',
    'Problems & Solutions': 'problem',
    'Two-Part': 'two-part',
    'Positive/Negative Development': 'positive-negative',
}


def text_of(pdf):
    return subprocess.run(['pdftotext', '-layout', pdf, '-'], capture_output=True, text=True, check=True).stdout


def clean(s):
    return re.sub(r'\s+', ' ', s).strip()


def num(v):
    v = v.strip().replace(',', '').rstrip('%')
    try:
        f = float(v)
        return int(f) if f.is_integer() and '.' not in v else f
    except ValueError:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Task 1: visual data blocks
# ─────────────────────────────────────────────────────────────────────────────


def split_cols(line):
    """'  a   b   c' -> [(start, 'a'), (start, 'b'), ...] on 2+ spaces."""
    return [(m.start(), m.group(0).strip()) for m in re.finditer(r'\S(?:.*?\S)?(?=\s{2,}|$)', line)]


def parse_grid(lines):
    """Header (possibly wrapped over several lines) + data rows -> (columns, rows)."""
    lines = [l for l in lines if l.strip()]
    if not lines:
        return [], []
    # data rows: same number of cells as the widest line with a numeric cell
    counts = [len(split_cols(l)) for l in lines]
    ncol = max(counts)
    first_data = None
    for i, l in enumerate(lines):
        cells = split_cols(l)
        if len(cells) == ncol and i > 0 and any(num(c[1]) is not None for c in cells[1:]):
            first_data = i
            break
    if first_data is None:
        first_data = 1
    anchor = [c[0] for c in split_cols(lines[first_data])]
    if len(anchor) < ncol:
        anchor = [c[0] for c in split_cols(max(lines, key=lambda l: len(split_cols(l))))]

    def col_of(pos):
        best = 0
        for k, a in enumerate(anchor):
            if pos >= a - 3:
                best = k
        return best

    head = [''] * len(anchor)
    for l in lines[:first_data]:
        for pos, txt in split_cols(l):
            k = col_of(pos)
            head[k] = clean(f'{head[k]} {txt}')
    # a wrapped header line can also sit below the first data-looking line
    rows = []
    for l in lines[first_data:]:
        cells = split_cols(l)
        if len(cells) < ncol and rows and all(num(c[1]) is None for c in cells):
            # header remainder or wrapped cell text
            target = rows[-1] if cells and cells[0][0] > anchor[0] + 3 else None
            for pos, txt in cells:
                k = col_of(pos)
                if target is None:
                    head[k] = clean(f'{head[k]} {txt}')
                else:
                    target[k] = clean(f'{target[k]} {txt}')
            continue
        row = [''] * len(anchor)
        for pos, txt in cells:
            k = col_of(pos)
            row[k] = clean(f'{row[k]} {txt}')
        rows.append(row)
    return head, rows


def parse_numbered(lines, head_re):
    """'#  Feature …' / 'Stage  Label  Detail' lists with wrapped lines."""
    items = []
    for l in lines:
        if not l.strip() or re.match(head_re, l.strip()):
            continue
        m = re.match(r'^\s{1,4}(\d+|↻)\s{2,}(.*)$', l)
        if m:
            items.append([m.group(1), m.group(2).rstrip()])
        elif items:
            items[-1][1] = items[-1][1] + ' ' + l.strip()
    return items


def parse_panel(block):
    lines = block.split('\n')
    head = next((l for l in lines if l.strip().startswith('Type:')), '')
    parts = [clean(p) for p in head.strip()[len('Type:'):].split('|')]
    kind_raw = parts[0] if parts else ''
    title = ''
    extra = []
    for p in parts[1:]:
        if p.startswith('Title:'):
            title = p[len('Title:'):].strip()
        else:
            extra.append(p)
    kind = kind_raw.split('(')[0].strip().lower()
    sub = re.search(r'\(([^)]*)\)', kind_raw)
    panel = {'kind': kind_raw, 'title': title}
    if sub:
        panel['variant'] = sub.group(1)
    if extra:
        panel['notes'] = extra
    body = lines[lines.index(head) + 1:] if head in lines else lines
    meta_lines = []
    while body and re.match(r'^\s*(X-axis|Y-axis|Category axis|Value axis|Frame|Scale)', body[0].strip() + ' ') is None \
            and not body[0].strip():
        body = body[1:]
    while body and re.match(r'^\s(X-axis|Category axis|Frame)', body[0]):
        meta_lines.append(body[0].strip())
        body = body[1:]
    for ml in meta_lines:
        if ml.startswith('Frame'):
            panel['frame'] = ml[len('Frame:'):].strip()
        else:
            for seg in ml.split('|'):
                k, _, v = seg.partition(':')
                key = {'X-axis': 'xAxis', 'Y-axis': 'yAxis', 'Category axis': 'categoryAxis',
                       'Value axis': 'valueAxis'}.get(k.strip(), k.strip())
                panel[key] = v.strip()
                sc = re.search(r'\(scale ([\d.]+)–([\d.,]+), interval ([\d.,]+)\)', v)
                if sc:
                    panel.setdefault('scale', {'min': num(sc.group(1)), 'max': num(sc.group(2)),
                                               'interval': num(sc.group(3))})
    notes = [clean(l) for l in body if l.strip().startswith('Note:')]
    if notes:
        panel.setdefault('notes', []).extend(notes)
        body = [l for l in body if not l.strip().startswith('Note:')]
    if kind in ('map', 'floor plan'):
        feats = []
        for n, txt in parse_numbered(body, r'^#'):
            m = re.match(r"^(.*?)(?: \[([^\]]+)\])?: (.*)$", txt)
            if m:
                feats.append({'n': int(n), 'name': m.group(1).strip(), 'kind': m.group(2) or '',
                              'position': clean(m.group(3))})
            else:
                feats.append({'n': int(n), 'name': clean(txt), 'kind': 'label', 'position': ''})
        panel['features'] = feats
    elif kind == 'process diagram':
        stages = []
        for n, txt in parse_numbered(body, r'^Stage'):
            bits = re.split(r'\s{2,}', txt.strip(), maxsplit=1)
            label, detail = (bits + [''])[:2]
            if n == '↻':
                panel['cycle'] = clean(detail) if detail else clean(label)
                continue
            stages.append({'n': int(n), 'label': clean(label), 'detail': clean(detail)})
        panel['stages'] = stages
    else:
        columns, rows = parse_grid(body)
        panel['columns'] = columns
        panel['rows'] = rows
    return panel


_PLUMBER = {}


def plumber_pages(pdf):
    """page number -> [(top, [(x0, x1, text, bold, size)])] word lines (pdfplumber)."""
    if pdf in _PLUMBER:
        return _PLUMBER[pdf]
    import pdfplumber

    out = {}
    with pdfplumber.open(pdf) as doc:
        for i, page in enumerate(doc.pages):
            words = page.extract_words(extra_attrs=['fontname', 'size'], x_tolerance=1.5)
            words = [w for w in words if w['top'] < 795]
            words.sort(key=lambda w: (round(w['top']), w['x0']))
            rows = []
            for w in words:
                t = (w['x0'], w['x1'], w['text'], 'Bold' in w['fontname'], round(w['size'], 1))
                if rows and abs(rows[-1][0] - w['top']) < 2.5:
                    rows[-1][1].append(t)
                else:
                    rows.append([w['top'], [t]])
            out[i + 1] = [(top, sorted(ws)) for top, ws in rows]
    _PLUMBER[pdf] = out
    return out


def grid_from_pdf(pdf, first_page, last_page, title):
    """Columns + rows of the data table under 'Title: <title>' (word positions)."""
    pages = plumber_pages(pdf)
    lines = []
    for pg in range(first_page, last_page + 1):
        lines.extend(pages.get(pg, []))
    start = None
    for i, (_, ws) in enumerate(lines):
        txt = ' '.join(w[2] for w in ws)
        if txt.startswith('Type:') and f'Title: {title}' in txt:
            start = i + 1
            break
    if start is None:
        return None
    grid = []
    for top, ws in lines[start:]:
        txt = ' '.join(w[2] for w in ws)
        if txt.startswith(('Panel ', 'Type:', 'Image Generation Prompt')):
            break
        if re.match(r'^(X-axis|Category axis|Frame):', txt) or txt.startswith('Note:'):
            continue
        grid.append(ws)
    if not grid:
        return None

    def cells(ws):
        out = []
        for w in ws:
            if out and w[0] - out[-1][1] < 8:
                out[-1] = (out[-1][0], w[1], out[-1][2] + ' ' + w[2], out[-1][3] and w[3])
            else:
                out.append((w[0], w[1], w[2], w[3]))
        return out

    body = [cells(ws) for ws in grid]
    data = [c for c in body if not all(x[3] for x in c)]
    ncol = max(len(c) for c in data) if data else max(len(c) for c in body)
    anchors = []
    for c in data:
        if len(c) == ncol:
            anchors = [x[0] for x in c]
            break

    def col(x):
        k = 0
        for j, a in enumerate(anchors):
            if x >= a - 6:
                k = j
        return k

    head = [''] * ncol
    rows = []
    for c in body:
        if all(x[3] for x in c) and not rows:
            for x in c:
                head[col(x[0])] = clean(head[col(x[0])] + ' ' + x[2])
            continue
        if abs(c[0][0] - anchors[0]) > 6 and rows:
            for x in c:  # wrapped cell text
                rows[-1][col(x[0])] = clean(rows[-1][col(x[0])] + ' ' + x[2])
            continue
        row = [''] * ncol
        for x in c:
            row[col(x[0])] = clean(row[col(x[0])] + ' ' + x[2])
        rows.append(row)
    return head, rows


def app_chart(kind, panels):
    """The app's native chart shape (Task1Chart) for panels that fit it."""
    def one(p):
        k = p['kind'].split('(')[0].strip().lower()
        if k in ('line graph', 'bar chart'):
            cols, rows = p.get('columns', []), p.get('rows', [])
            unit = p.get('yAxis') or p.get('valueAxis') or ''
            unit = re.sub(r'\s*\(scale.*$', '', unit)
            return {'type': 'line' if k == 'line graph' else 'bar', 'title': p['title'], 'unit': unit,
                    'xLabels': [r[0] for r in rows],
                    'series': [{'name': cols[c], 'values': [num(r[c]) for r in rows]} for c in range(1, len(cols))],
                    **({'variant': p['variant']} if p.get('variant') else {})}
        if k == 'pie chart':
            return {'type': 'pie', 'charts': [{'label': p['title'], 'slices': [
                {'name': r[0], 'value': num(r[1])} for r in p.get('rows', []) if r[0].lower() != 'total']}]}
        if k == 'table':
            return {'type': 'table', 'title': p['title'], 'columns': p.get('columns', []), 'rows': p.get('rows', [])}
        if k == 'process diagram':
            return {'type': 'process', 'title': p['title'],
                    'steps': [f"{s['label']}: {s['detail']}" if s['detail'] else s['label'] for s in p['stages']]}
        if k in ('map', 'floor plan'):
            return {'type': 'map', 'label': p['title'], 'features': [f['name'] for f in p['features'] if f['kind'] != 'label']}
        return {}

    parts = [one(p) for p in panels]
    if kind == 'pie' and all(x.get('type') == 'pie' for x in parts):
        return {'charts': [c for x in parts for c in x['charts']]}
    if kind in ('line', 'bar', 'table', 'process') and len(parts) == 1:
        x = dict(parts[0])
        x.pop('type', None)
        return x
    if kind == 'map':
        maps = [x for x in parts if x.get('type') == 'map']
        if len(maps) == 2:
            return {'before': {'label': maps[0]['label'], 'features': maps[0]['features']},
                    'after': {'label': maps[1]['label'], 'features': maps[1]['features']}}
        if maps:
            return {'before': {'label': maps[0]['label'], 'features': maps[0]['features']}}
    out = []
    for x in parts:
        if x.get('type') == 'pie' and out and out[-1].get('type') == 'pie':
            out[-1]['charts'].extend(x['charts'])
        elif x:
            out.append(x)
    return {'parts': out}


def panels_text(panels):
    """The visual data as clean text (for the AI grader and a 'Data' view)."""
    out = []
    for i, p in enumerate(panels):
        if len(panels) > 1:
            out.append(f'Panel {i + 1}')
        out.append(f"Type: {p['kind']} | Title: {p['title']}")
        names = {'xAxis': 'X-axis', 'yAxis': 'Y-axis', 'categoryAxis': 'Category axis', 'valueAxis': 'Value axis'}
        axes = [f"{names[k]}: {p[k]}" for k in names if p.get(k)]
        if axes:
            out.append(' | '.join(axes))
        if p.get('frame'):
            out.append(f"Frame: {p['frame']}")
        for n in p.get('notes', []):
            out.append(n)
        if 'columns' in p:
            out.append(' | '.join(p['columns']))
            out.extend(' | '.join(r) for r in p['rows'])
        for f in p.get('features', []):
            out.append(f"{f['n']}. {f['name']}" + (f" [{f['kind']}]" if f['kind'] and f['kind'] != 'label' else '')
                       + (f": {f['position']}" if f['position'] else ''))
        for st in p.get('stages', []):
            out.append(f"Stage {st['n']}: {st['label']} — {st['detail']}")
        if p.get('cycle'):
            out.append(f"Cycle: {p['cycle']}")
    return '\n'.join(out)


def data_text(block):
    """The visual data as printed, tidied for the AI grader / a 'Data' view."""
    lines = [l.rstrip() for l in block.split('\n')]
    out = []
    for l in lines:
        s = l.strip()
        if not s or s == 'Visual Data':
            continue
        out.append(re.sub(r'\s{3,}', ' | ', s))
    return '\n'.join(out)


def parse_task1(pdf):
    raw = text_of(pdf)
    pages = raw.split('\f')
    t = re.sub(r'\n\s*IELTS Academic Writing Task 1 — Original Practice Question Bank\s+Page \d+\n', '\n',
               raw.replace('\f', '\n'))
    # front matter
    front = pages[0]
    meta = {
        'title': 'IELTS Academic Writing Task 1 — Original Practice Question Bank',
        'summary': clean(re.search(r'(\d+ questions ·[^\n]*)', front).group(1)),
        'contents': clean(re.search(r'questions per type\s*\n(.*?)\n\s*\n\s*\n', front, re.S).group(1)),
        'note': clean(re.search(r'Note\.(.*?)(?:\n\s*\n|$)', front, re.S).group(1)),
        'sections': [],
    }
    for m in re.finditer(r'Type (\d)\s+([^\n]+?)\s{2,}(\d\d–\d\d)', front):
        meta['sections'].append({'type': int(m.group(1)), 'name': m.group(2).strip(), 'questions': m.group(3)})

    questions = {}
    for m in re.finditer(r'\n ([\w /]+?) · Question (\d+)\n Question\n(.*?)(?=\n [\w /]+? · Question \d+ — data)', t, re.S):
        body = m.group(3)
        lines = [clean(l) for l in body.split('\n') if clean(l)]
        questions[(m.group(1), int(m.group(2)))] = lines
    blocks = re.findall(
        r'\n ([\w /]+?) · Question (\d+) — data & image\s+prompt\n(.*?)\n Image Generation Prompt\n(.*?)'
        r'(?=\n [\w /]+? · Question \d+\n|\n\s+Type \d — |\Z)', t, re.S)


    # images: one per question page, in page order
    page_of = {}
    for i, p in enumerate(pages):
        m = re.search(r'^ ([\w /]+?) · Question (\d+)\s*$', p, re.M)
        if m and '\n Question\n' in p:
            page_of[(m.group(1), int(m.group(2)))] = i + 1

    items = []
    for sec, n, block, iprompt in blocks:
        n = int(n)
        key, label = T1_TYPES[sec]
        lines = questions[(sec, n)]
        time_line = next((l for l in lines if l.startswith('You should spend')), '')
        words_line = next((l for l in lines if l.startswith('Write at least')), '')
        summ_i = next(i for i, l in enumerate(lines) if l.startswith('Summarise'))
        stmt = clean(' '.join(l for l in lines[:summ_i] if l != time_line))
        summarise = clean(' '.join(lines[summ_i:lines.index(words_line)]))
        panel_blocks = re.split(r'\n Panel \d+\n', '\n' + block) if 'Panel 1' in block else [block]
        panels = [parse_panel(b) for b in panel_blocks if 'Type:' in b]
        qpage = page_of.get((sec, n))
        nxt = min([pg for pg in page_of.values() if pg > qpage] + [len(pages)])
        for p in panels:
            if 'columns' in p:
                g = grid_from_pdf(pdf, qpage + 1, nxt - 1, p['title'])
                if g:
                    p['columns'], p['rows'] = g
        pid = f'wb1_{key}_{n:02d}'
        items.append({
            'id': pid,
            'task': 1,
            'bank': 'Task 1 question bank',
            'number': n,
            'type': key,
            'typeLabel': label,
            'section': sec,
            'title': panels[0]['title'] if panels else label,
            'statement': stmt,
            'prompt': f'{stmt} {summarise}',
            'instructions': [time_line, stmt, summarise, words_line],
            'timeMinutes': int(re.search(r'(\d+) minutes', time_line).group(1)) if time_line else 20,
            'minWords': int(re.search(r'(\d+) words', words_line).group(1)) if words_line else 150,
            'image': f'assets/writing/task1/{pid}.webp',
            'visual': {'panels': panels},
            'dataText': panels_text(panels),
            'dataPrinted': data_text(block),
            'chart': app_chart(key, panels),
            'imagePrompt': clean(iprompt),
            'sourcePage': page_of.get((sec, n)),
        })
    return meta, items


def extract_images(pdf, items):
    from PIL import Image

    os.makedirs(IMG_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for it in items:
            dst = os.path.join(ROOT, it['image'])
            if os.path.exists(dst):
                continue
            pg = str(it['sourcePage'])
            subprocess.run(['pdfimages', '-png', '-f', pg, '-l', pg, pdf, os.path.join(tmp, it['id'])], check=True)
            files = sorted(glob.glob(os.path.join(tmp, it['id'] + '-*.png')))
            imgs = [Image.open(f) for f in files]
            main = max(imgs, key=lambda im: im.size[0] * im.size[1] * (3 if im.mode != 'L' else 1))
            im = main.convert('RGB')
            if im.width > 1600:
                im = im.resize((1600, round(im.height * 1600 / im.width)), Image.LANCZOS)
            im.save(dst, 'WEBP', quality=85, method=4)
    for it in items:
        from PIL import Image as _I
        with _I.open(os.path.join(ROOT, it['image'])) as im:
            it['imageSize'] = [im.width, im.height]


# ─────────────────────────────────────────────────────────────────────────────
# Task 2
# ─────────────────────────────────────────────────────────────────────────────


def parse_task2(pdf):
    raw = text_of(pdf)
    t = re.sub(r'\n\s*IELTS Academic Writing Task 2 - Original Practice Question Bank\s+Page \d+\n', '\n',
               raw.replace('\f', '\n'))
    head = t[:t.index('Type 1')]
    meta = {
        'title': clean(re.search(r'^(.*?)\n\s*\d+ original', head, re.S).group(1)),
        'summary': clean(re.search(r'(\d+ original.*)$', head, re.S).group(1)),
        'sections': [], 'difficulty': [],
    }
    for m in re.finditer(r'\n Type (\d) - ([^\n]+)((?:\n (?!Question \d)[^\n]+)?)', t):
        meta['sections'].append({'type': int(m.group(1)), 'name': clean(m.group(2) + ' ' + m.group(3))})
    summ = t[t.rindex('Summary'):]
    for m in re.finditer(r'\n\s+(Moderate|Upper-moderate|Difficult)\s+(\d+)\s+(\d+%)', summ):
        meta['difficulty'].append({'level': m.group(1), 'questions': int(m.group(2)), 'share': m.group(3)})

    items = []
    section = None
    for part in re.split(r'\n (?=Type \d - |Question \d+\n)', t):
        m = re.match(r'Type (\d) - (.*)', part)
        if m:
            section = m.group(2).strip()
            continue
        m = re.match(r'Question (\d+)\n Question Type: (.*?) \| Topic: (.*?) \| Difficulty:\s*(\S+)\n Question:\n(.*?)\n'
                     r' (Give reasons.*?words\.)', part, re.S)
        if not m:
            continue
        n = int(m.group(1))
        qtype = m.group(2).strip()
        key = T2_TYPES[qtype]
        question = clean(m.group(5))
        instr = clean(m.group(6))
        items.append({
            'id': f'wb2_{key}_{n:02d}',
            'task': 2,
            'bank': 'Task 2 question bank',
            'number': n,
            'type': key,
            'typeLabel': qtype,
            'topic': clean(m.group(3)),
            'difficulty': m.group(4).strip(),
            'question': question,
            'prompt': f"{question}\n\n{instr.replace(' Write at least 250 words.', '')}",
            'instructions': [question, instr],
            'timeMinutes': 40,
            'minWords': int(re.search(r'(\d+) words', instr).group(1)),
        })
    return meta, items


# ─────────────────────────────────────────────────────────────────────────────
# Sample answers (seed/staging/writing_samples/<id>.json)
# ─────────────────────────────────────────────────────────────────────────────

LINKERS = sorted(set('''
Overall, In general, To summarise, In summary, In conclusion, To conclude, To sum up, Firstly, Secondly, Thirdly,
Finally, Lastly, First of all, In addition, Additionally, Moreover, Furthermore, What is more, Also, Besides,
However, Nevertheless, Nonetheless, On the other hand, By contrast, In contrast, Conversely, Meanwhile,
Similarly, Likewise, Therefore, Consequently, As a result, Thus, Hence, For example, For instance, In particular,
Specifically, Admittedly, Of course, Indeed, In fact, After that, Then, Next, Subsequently, Following this,
At the same time, In the meantime, Eventually, Initially, To begin with, At first, Although, Even though,
While, Whereas, Despite, In spite of, Because of this, For this reason, This means that, That is why,
On balance, All in all, In my opinion, In my view, I believe, I think, Personally, It is true that,
Some people argue, Others believe, Another reason, Another advantage, Another disadvantage, One reason,
One advantage, One disadvantage, The main reason
'''.replace('\n', ' ').split(', ')), key=len, reverse=True)
LINK_RE = re.compile(r'(?<![A-Za-z])(' + '|'.join(re.escape(x.strip()) for x in LINKERS if x.strip()) + r')(?=[\s,])')


def paragraphs_marked(text):
    """'para\\n\\npara' -> [[{text}, {text, mark: link}, …], …] (linking phrases marked)."""
    out = []
    for para in [p.strip() for p in re.split(r'\n\s*\n', text) if p.strip()]:
        segs = []
        pos = 0
        for m in LINK_RE.finditer(para):
            # only at a sentence / clause start
            before = para[:m.start()].rstrip()
            if before and before[-1] not in '.!?;:,':
                continue
            if m.start() > pos:
                segs.append({'text': para[pos:m.start()]})
            end = m.end()
            if end < len(para) and para[end] == ',':
                end += 1
            segs.append({'text': para[m.start():end], 'mark': 'link'})
            pos = end
        if pos < len(para):
            segs.append({'text': para[pos:]})
        out.append(segs)
    return out


def load_samples(items):
    found = 0
    for it in items:
        path = os.path.join(SAMPLES, it['id'] + '.json')
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        if data.get('title') and it['task'] == 2:
            it['title'] = clean(data['title'])
        samples = []
        for s in sorted(data.get('samples', []), key=lambda s: s['band']):
            text = s['text'].strip()
            samples.append({
                'band': s['band'],
                'label': f"Band {s['band']}",
                'words': len(re.findall(r"[A-Za-z0-9£$%'’.-]+", text)),
                'text': text,
                'paragraphs': paragraphs_marked(text),
                'why': clean(s.get('why', '')),
            })
        if samples:
            it['samples'] = samples
            top = samples[-1]
            it['modelAnswer'] = {'band': top['band'], 'text': top['text']}
            found += 1
    return found


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    pdf1, pdf2 = sys.argv[1], sys.argv[2]
    meta1, task1 = parse_task1(pdf1)
    meta2, task2 = parse_task2(pdf2)
    extract_images(pdf1, task1)
    for it in task2:
        it.setdefault('title', f"{it['topic']} · {it['typeLabel']}")
    s1 = load_samples(task1)
    s2 = load_samples(task2)
    meta1['source'] = os.path.basename(pdf1)
    meta2['source'] = os.path.basename(pdf2)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump({'meta': {'task1': meta1, 'task2': meta2}, 'task1': task1, 'task2': task2}, f,
                  ensure_ascii=False, separators=(',', ':'))
    img_mb = sum(os.path.getsize(os.path.join(ROOT, it['image'])) for it in task1) / 1e6
    print(f'Task 1: {len(task1)} questions ({s1} with samples), images {img_mb:.1f} MB')
    print(f'Task 2: {len(task2)} questions ({s2} with samples)')
    print(f'-> {OUT} ({os.path.getsize(OUT) // 1024} KB)')


if __name__ == '__main__':
    main()
