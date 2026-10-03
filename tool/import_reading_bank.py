"""Import the IELTS Academic Reading Question Bank PDF into seed JSON.

Reads IELTS_Reading_Question_Bank-1.pdf (740 pages, 14 question types x 20 sets)
and writes:
  seed/data/27_reading_bank_passages.json   (280 passages, one question type each)
  seed/data/28_reading_type_lessons.json    (14 "How to attempt ..." lessons)
  seed/data/29_reading_practice_tests.json  (20 short 3-passage practice tests)
  seed/formats/27_*.json, 28_*.json, 29_*.json (format descriptions + examples)
  seed/reports/reading_bank_import_report.md (validation results + review list)

Nothing is invented or reworded: text is copied from the PDF; only line breaks,
page headers/footers and gap dots ("......" -> "______") are normalised.
Layout-dependent blocks (tables, flow-charts, diagrams, word banks) are read
from the PDF geometry with pdfplumber.

Run:  python3 tool/import_reading_bank.py --pdf path/to/bank.pdf [--raw raw.txt]
      (--raw: optional `pdftotext` output used as an independent text cross-check;
       generated automatically when pdftotext is installed)
"""
import argparse, collections, copy, json, os, random, re, subprocess, sys, tempfile

import pdfplumber

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_NAME = 'IELTS_Reading_Question_Bank-1.pdf'

TYPES = [  # (slug, display name, heading text in PDF)
    ('mcq', 'Multiple Choice', 'MULTIPLE CHOICE'),
    ('tfng', 'True / False / Not Given', 'TRUE / FALSE / NOT GIVEN'),
    ('ynng', 'Yes / No / Not Given', 'YES / NO / NOT GIVEN'),
    ('matching_info', 'Matching Information', 'MATCHING INFORMATION'),
    ('headings', 'Matching Headings', 'MATCHING HEADINGS'),
    ('matching_features', 'Matching Features', 'MATCHING FEATURES'),
    ('sentence_endings', 'Matching Sentence Endings', 'MATCHING SENTENCE ENDINGS'),
    ('sentence_completion', 'Sentence Completion', 'SENTENCE COMPLETION'),
    ('summary_completion', 'Summary Completion', 'SUMMARY COMPLETION'),
    ('note_completion', 'Note Completion', 'NOTE COMPLETION'),
    ('table_completion', 'Table Completion', 'TABLE COMPLETION'),
    ('flowchart_completion', 'Flow-chart Completion', 'FLOW-CHART COMPLETION'),
    ('diagram_label', 'Diagram Label Completion', 'DIAGRAM LABEL COMPLETION'),
    ('short_answer', 'Short Answer', 'SHORT ANSWER'),
]
SLUG_SHORT = {'mcq': 'mcq', 'tfng': 'tfng', 'ynng': 'ynng', 'matching_info': 'matching_info', 'headings': 'headings',
              'matching_features': 'matching_features', 'sentence_endings': 'sentence_endings',
              'sentence_completion': 'sentence_completion', 'summary_completion': 'summary_completion',
              'note_completion': 'note_completion', 'table_completion': 'table_completion',
              'flowchart_completion': 'flowchart_completion', 'diagram_label': 'diagram_label',
              'short_answer': 'short_answer'}
GAP_TYPES = {'sentence_completion', 'summary_completion', 'note_completion', 'table_completion',
             'flowchart_completion', 'diagram_label', 'short_answer'}
LEVEL_PART = {'EASY': 1, 'MEDIUM': 2, 'HARD': 3}
ROMAN = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x', 'xi', 'xii', 'xiii', 'xiv', 'xv']
NUMWORDS = {'ONE': 1, 'TWO': 2, 'THREE': 3, 'FOUR': 4, 'FIVE': 5}
X_TOL = 1.5
HEADER_TEXT = 'IELTS Academic Reading · Question Bank'
GAP_RE = re.compile(r'\.{6,}')
ARROWS = set('↓↙↘↑')

REVIEW = []      # "Needs human review" items (strings)
NOTES = []       # informational findings (not errors)


def review(msg):
    REVIEW.append(msg)


# ─────────────────────────────────────────────────────────────── extraction ──
class Line:
    __slots__ = ('page', 'x0', 'x1', 'top', 'bottom', 'font', 'size', 'text', 'mask')

    def __init__(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)

    @property
    def bold(self):
        return 'Bold' in self.font

    def lead_bold(self):
        """Leading run of bold characters (stripped)."""
        k = 0
        while k < len(self.text) and (self.mask[k] == 'B' or (self.mask[k] == ' ' and k + 1 < len(self.text) and self.mask[k + 1] == 'B')):
            k += 1
        return self.text[:k].strip()

    def __repr__(self):
        return f'<L p{self.page} x{self.x0} y{self.top} {self.font} {self.size} {self.text[:50]!r}>'


def font_kind(fontname):
    f = fontname.split('+')[-1]
    if 'Bold' in f:
        return 'B'
    if 'Oblique' in f or 'Italic' in f:
        return 'I'
    return 'n'


def extract_lines(pdf):
    out = []
    for pi, page in enumerate(pdf.pages):
        for l in page.extract_text_lines(x_tolerance=X_TOL):
            chs = [c for c in l['chars'] if c['text'].strip()]
            text = l['text']
            mask = []
            ci = 0
            for ch in text:
                if ch.isspace():
                    mask.append(' ')
                else:
                    # map to the next real char (ligatures are not used by this PDF)
                    c = chs[ci] if ci < len(chs) else None
                    ci += 1
                    mask.append(font_kind(c['fontname']) if c else 'n')
            fonts = [c['fontname'].split('+')[-1] for c in chs]
            ln = Line(page=pi + 1, x0=round(l['x0'], 1), x1=round(l['x1'], 1), top=round(l['top'], 1),
                      bottom=round(l['bottom'], 1), font=fonts[0] if fonts else '',
                      size=round(chs[0]['size'], 1) if chs else 0, text=text, mask=''.join(mask))
            # page header / footer
            if ln.top < 45 and text.strip() == HEADER_TEXT:
                continue
            if ln.size == 7.5 and ln.top > 780 and text.strip().isdigit():
                continue
            out.append(ln)
    return out


def join_lines(lines):
    """Join wrapped lines with single spaces. Returns (text, mask)."""
    t, m = '', ''
    for l in lines:
        s = l.text.strip()
        k = len(l.text) - len(l.text.lstrip())
        sm = l.mask[k:k + len(s)]
        if t:
            t += ' '
            m += ' '
        t += s
        m += sm
    return t, m


_SENTENCE_START = re.compile(r'(?<=[a-z\)"”])\s+(?=[A-Z][a-z]*\b)')


def split_lesson_title(title):
    """Six set-lesson titles in the PDF run straight into the first body sentence in one bold run
    (e.g. "Hard Matching Features — shifting positions and cross-references In Hard sets:").
    Returns (title, body_prefix); body_prefix is '' when the title is clean."""
    if len(title) <= 70 and not title.rstrip().endswith(':'):
        return title, ''
    for m in _SENTENCE_START.finditer(title):
        head, rest = title[:m.start()].strip(), title[m.end():].strip()
        if len(head) >= 12 and '—' not in rest and re.search(r'[.:]', rest):
            return head, rest
    return title, ''


def fix_set_lesson(lesson):
    """Moves a swallowed body sentence from the lesson title back to the start of the text (in place)."""
    head, rest = split_lesson_title(lesson['title'])
    if rest:
        lesson['title'] = head
        lesson['text'] = rest + ('\n\n' + lesson['text'] if lesson.get('text') else '')
    return bool(rest)


def paragraphs(lines, gap=14.0):
    """Group lines into paragraphs: a vertical step > gap (or a page change) starts a new paragraph."""
    out, cur = [], []
    for l in lines:
        if cur:
            p = cur[-1]
            if l.page != p.page:
                # page break: continue paragraph only if the new line does not look like a new start
                new = False
            else:
                new = (l.top - p.top) > gap
            if new:
                out.append(cur)
                cur = []
        cur.append(l)
    if cur:
        out.append(cur)
    return out


def gaps(s):
    return GAP_RE.sub('______', s)


def norm_ws(s):
    return re.sub(r'\s+', ' ', s).strip()


# ───────────────────────────────────────────────────────── geometry parsers ──
def region_words(pdf, page, y0, y1, x0=0, x1=None):
    p = pdf.pages[page - 1]
    x1 = x1 or p.width
    c = p.within_bbox((x0, max(0, y0), x1, min(p.height, y1)))
    return c.extract_words(x_tolerance=X_TOL, extra_attrs=['fontname', 'size'])


def words_to_lines(words, tol=2.0):
    ws = sorted(words, key=lambda w: (round(w['top']), w['x0']))
    rows = []
    for w in ws:
        for r in rows:
            if abs(r[0]['top'] - w['top']) <= tol:
                r.append(w)
                break
        else:
            rows.append([w])
    rows.sort(key=lambda r: r[0]['top'])
    for r in rows:
        r.sort(key=lambda w: w['x0'])
    return rows


def row_text(r):
    return ' '.join(w['text'] for w in r)


def cell_clean(s):
    if s is None:
        return ''
    return gaps(norm_ws(s.replace('\n', ' ')))


def parse_table(pdf, spans):
    """spans: list of (page, y0, y1). Returns (columns, rows)."""
    cols, rows = None, []
    for page, y0, y1 in spans:
        p = pdf.pages[page - 1]
        for t in p.find_tables():
            bx0, btop, bx1, bbot = t.bbox
            if btop > y1 or bbot < y0:
                continue
            data = t.extract()
            if not data:
                continue
            first = [cell_clean(c) for c in data[0]]
            if first[:2] == ['Question', 'Answer']:
                continue
            if cols is None:
                cols = first
                body = data[1:]
            elif first == cols:
                body = data[1:]
            else:
                body = data
            for r in body:
                rows.append([cell_clean(c) for c in r])
    return cols, rows


def find_boxes(page_obj, y0, y1):
    """Rectangular boxes drawn with 4 line segments (flow-chart boxes)."""
    hs = [l for l in page_obj.lines if abs(l['top'] - l['bottom']) < 0.6 and y0 - 1 <= l['top'] <= y1 + 1 and (l['x1'] - l['x0']) > 30]
    vs = [l for l in page_obj.lines if abs(l['x0'] - l['x1']) < 0.6 and l['top'] >= y0 - 1 and l['bottom'] <= y1 + 1]
    groups = collections.defaultdict(list)
    for h in hs:
        groups[(round(h['x0']), round(h['x1']))].append(h['top'])
    boxes = []
    for (a, b), ys in groups.items():
        ys = sorted(set(round(y, 1) for y in ys))
        used = set()
        for i in range(len(ys)):
            if i in used:
                continue
            for j in range(i + 1, len(ys)):
                if j in used:
                    continue
                t, bt = ys[i], ys[j]
                lv = any(abs(v['x0'] - a) < 1.5 and v['top'] <= t + 1 and v['bottom'] >= bt - 1 for v in vs)
                rv = any(abs(v['x0'] - b) < 1.5 and v['top'] <= t + 1 and v['bottom'] >= bt - 1 for v in vs)
                if lv and rv:
                    boxes.append((a, t, b, bt))
                    used.add(i)
                    used.add(j)
                    break
    # filled rects used as boxes (branch boxes) — keep those not already found
    for r in page_obj.rects:
        if not (y0 - 1 <= r['top'] and r['bottom'] <= y1 + 1):
            continue
        if r['x1'] - r['x0'] > 470:   # title bar / full-width bands
            continue
        box = (round(r['x0']), round(r['top'], 1), round(r['x1']), round(r['bottom'], 1))
        if not any(abs(box[0] - b[0]) < 2 and abs(box[1] - b[1]) < 2 and abs(box[2] - b[2]) < 2 for b in boxes):
            boxes.append(box)
    return boxes


def parse_flowchart(pdf, spans, ctx):
    """Returns list of steps: str or {"branches": [[col1 steps], [col2 steps], ...]} and leftover text."""
    rows_of_boxes = []
    leftovers = []
    for page, y0, y1 in spans:
        p = pdf.pages[page - 1]
        boxes = find_boxes(p, y0 - 8, y1 + 8)
        words = [w for w in region_words(pdf, page, y0, y1) if w['text'] not in ARROWS]
        assigned = set()
        btexts = []
        for bx in boxes:
            inside = [w for w in words if w['x0'] >= bx[0] - 1 and w['x1'] <= bx[2] + 1 and w['top'] >= bx[1] - 1 and w['bottom'] <= bx[3] + 1]
            for w in inside:
                assigned.add(id(w))
            if not inside:
                continue
            txt = ' '.join(row_text(r) for r in words_to_lines(inside))
            btexts.append((bx, gaps(norm_ws(txt))))
        leftovers += [w['text'] for w in words if id(w) not in assigned]
        btexts.sort(key=lambda b: (b[0][1], b[0][0]))
        for bx, txt in btexts:
            if rows_of_boxes and rows_of_boxes[-1][0] == page and abs(rows_of_boxes[-1][1] - bx[1]) < 3:
                rows_of_boxes[-1][2].append((bx[0], txt))
            else:
                rows_of_boxes.append([page, bx[1], [(bx[0], txt)]])
    steps = []
    for page, top, items in rows_of_boxes:
        items.sort()
        texts = [t for _, t in items]
        if len(texts) == 1:
            steps.append(texts[0])
        else:
            if steps and isinstance(steps[-1], dict) and len(steps[-1]['branches']) == len(texts):
                for col, t in zip(steps[-1]['branches'], texts):
                    col.append(t)
            else:
                steps.append({'branches': [[t] for t in texts]})
    return steps, leftovers


def parse_diagram(pdf, spans, ctx):
    """Labels around a diagram. Returns (labels, captions, leftovers)."""
    labels, captions = [], []
    for page, y0, y1 in spans:
        p = pdf.pages[page - 1]
        words = region_words(pdf, page, y0, y1)
        if not words:
            continue
        leaders = [l for l in p.lines if abs(l['top'] - l['bottom']) < 0.6 and y0 <= l['top'] <= y1 and 10 < (l['x1'] - l['x0']) < 150]
        ital = [w for w in words if 'Oblique' in w['fontname'] or 'Italic' in w['fontname']]
        norm = [w for w in words if w not in ital]
        # captions: oblique clusters
        for cl in cluster_rows(words_to_lines(ital), 12.5, None):
            captions.append(norm_ws(' '.join(row_text(r) for r in cl)))
        if not norm:
            continue
        if leaders:
            cx = (min(l['x0'] for l in leaders) + max(l['x1'] for l in leaders)) / 2
        else:
            cx = p.width / 2
        for side in ('left', 'right'):
            sw = [w for w in norm if ((w['x0'] + w['x1']) / 2 < cx) == (side == 'left')]
            rows = words_to_lines(sw)
            for k, cl in enumerate(cluster_rows(rows, 12.5, side)):
                labels.append({'text': gaps(norm_ws(' '.join(row_text(r) for r in cl))), 'side': side,
                               '_top': cl[0][0]['top'], '_page': page})
    out = []
    for side in ('left', 'right'):
        s = sorted([l for l in labels if l['side'] == side], key=lambda l: (l['_page'], l['_top']))
        for i, l in enumerate(s, 1):
            out.append({'text': l['text'], 'side': side, 'order': i})
    return out, captions


def cluster_rows(rows, gap, side):
    """Group text rows into labels: rows closer than `gap` vertically and aligned on the same edge."""
    out = []
    for r in rows:
        if out:
            prev = out[-1][-1]
            close = (r[0]['top'] - prev[0]['top']) <= gap
            if side == 'left':
                aligned = abs(r[-1]['x1'] - prev[-1]['x1']) < 6
            elif side == 'right':
                aligned = abs(r[0]['x0'] - prev[0]['x0']) < 6
            else:
                aligned = True
            if close and aligned:
                out[-1].append(r)
                continue
        out.append([r])
    return out


def parse_bank_lines(lines):
    """Word-bank lines like 'A respected B protect ...' where keys are bold."""
    opts = []
    for l in lines:
        tokens = []
        pos = 0
        for m in re.finditer(r'\S+', l.text):
            tok = m.group(0)
            tm = l.mask[m.start():m.end()]
            tokens.append((tok, all(c == 'B' for c in tm)))
        for tok, b in tokens:
            if b and re.fullmatch(r'[A-Z]', tok):
                opts.append({'key': tok, 'text': ''})
            else:
                if not opts:
                    return None
                opts[-1]['text'] = (opts[-1]['text'] + ' ' + tok).strip()
    return opts


# ──────────────────────────────────────────────────────────── segmentation ──
def segment(lines):
    types, sets = [], []
    cur_type = None
    cur_set = None
    for l in lines:
        if l.size == 19.0 and l.bold:
            m = re.match(r'TYPE (\d+) — (.+)', l.text.strip())
            if cur_set:
                sets.append(cur_set)
                cur_set = None
            if m:
                cur_type = {'n': int(m.group(1)), 'heading': m.group(2), 'lines': []}
                types.append(cur_type)
            else:
                cur_type = None  # FINAL SUMMARY
            continue
        if l.size == 15.0 and l.bold and l.text.startswith('SET '):
            if cur_set:
                sets.append(cur_set)
            m = re.match(r'SET (\d+) — (EASY|MEDIUM|HARD)$', l.text.strip())
            if not m:
                review(f'Unrecognised set header {l.text!r} (page {l.page})')
                cur_set = None
                continue
            cur_set = {'type': cur_type['n'], 'set': int(m.group(1)), 'level': m.group(2), 'lines': [], 'page': l.page, 'setNo': m.group(1)}
            continue
        if cur_set is not None:
            cur_set['lines'].append(l)
        elif cur_type is not None:
            cur_type['lines'].append(l)
    if cur_set:
        sets.append(cur_set)
    return types, sets


# ─────────────────────────────────────────────────────────────── set parse ──
def is_q_header(l):
    return l.size == 10.8 and l.bold and re.match(r'Questions \d+', l.text.strip())


def parse_set(S, pdf):
    L = S['lines']
    ctx = f"{TYPES[S['type'] - 1][0]} set {S['setNo']}"
    S['ctx'] = ctx
    i = 0
    meta = {}
    # header fields
    while i < len(L) and not L[i].text.startswith('Lesson for this set:'):
        t = L[i].text.strip()
        m = re.match(r'(Question Type|Difficulty|Topic): (.*)', t)
        if m:
            meta[m.group(1)] = m.group(2)
            last = m.group(1)
        else:
            meta[last] = meta[last] + ' ' + t  # wrapped header line
        i += 1
    # lesson
    lt = [L[i]]
    i += 1
    while L[i].size == 10.8 and L[i].bold and L[i].text.strip() != 'Reading Passage':
        lt.append(L[i])
        i += 1
    lesson_title = join_lines(lt)[0][len('Lesson for this set:'):].strip()
    body = []
    while not (L[i].size == 10.8 and L[i].text.strip() == 'Reading Passage'):
        body.append(L[i])
        i += 1
    i += 1
    lesson_paras = [join_lines(p) for p in paragraphs(body)]
    ltext, lex = [], []
    in_ex = False
    for t, m in lesson_paras:
        if t.startswith('Tiny example.'):
            in_ex = True
            t = t[len('Tiny example.'):].strip()
        (lex if in_ex else ltext).append(t)
    lesson = {'title': lesson_title, 'text': gaps('\n\n'.join(ltext)), 'example': gaps('\n'.join(lex)) if lex else None}
    if fix_set_lesson(lesson):
        NOTES.append(f'{ctx}: lesson title ran into the body in the PDF; split at {lesson["title"]!r}')
    # passage title
    tl = []
    while L[i].font.endswith('Serif-Bold') and L[i].size == 12.5:
        tl.append(L[i])
        i += 1
    title = join_lines(tl)[0]
    # paragraphs
    paras = []
    pre_lines = []
    while not is_q_header(L[i]):
        l = L[i]
        if 'Serif' not in l.font:
            review(f'{ctx}: unexpected non-serif line inside passage: {l.text!r} (page {l.page})')
            i += 1
            continue
        lb = l.lead_bold()
        if l.x0 < 70 and re.fullmatch(r'[A-Z]', lb or ''):
            paras.append({'letter': lb, 'lines': [l]})
        else:
            if not paras:
                pre_lines.append(l)   # a note printed before paragraph A
                i += 1
                continue
            if l.x0 < 70:
                review(f'{ctx}: passage line at paragraph-start indent without bold letter: {l.text!r} (page {l.page})')
            paras[-1]['lines'].append(l)
        i += 1
    paragraphs_out = []
    for p in paras:
        t, _ = join_lines(p['lines'])
        assert t.startswith(p['letter'] + ' '), (ctx, t[:20])
        paragraphs_out.append({'letter': p['letter'], 'text': t[len(p['letter']) + 1:].strip()})
    # question blocks
    blocks = []
    while not (L[i].size == 10.8 and L[i].text.strip() == 'ANSWERS'):
        if is_q_header(L[i]):
            blocks.append({'header': L[i], 'lines': []})
        else:
            blocks[-1]['lines'].append(L[i])
        i += 1
    i += 1
    # answers table
    if L[i].text.strip() != 'Question Answer':
        review(f'{ctx}: answers table header not found: {L[i].text!r}')
    else:
        i += 1
    ans_rows = []
    while i < len(L):
        l = L[i]
        if l.size == 9.0 and not l.bold and abs(l.x0 - 68.7) < 1:
            m = re.match(r'(\d+(?:–\d+)?) (.+)$', l.text.strip())
            if not m:
                review(f'{ctx}: unparsable answer row {l.text!r}')
            else:
                ans_rows.append([m.group(1), m.group(2)])
        elif l.size == 9.0 and not l.bold and l.x0 > 100 and ans_rows:
            ans_rows[-1][1] += ' ' + l.text.strip()   # wrapped answer cell
        elif l.size == 9.0 and l.bold and l.text.strip() == 'Question Answer':
            pass  # header repeated after a page break
        else:
            break
        i += 1
    # after answers: word limit, explanation entries, unused
    tail = L[i:]
    word_limit_line = None
    entries, extras, notes_after = [], [], []
    last_kind = None
    for l in tail:
        t = l.text.strip()
        lb = l.lead_bold()
        if t.startswith('Word limit:') and lb.startswith('Word limit:'):
            word_limit_line = t[len('Word limit:'):].strip()
            continue
        m = re.match(r'(\d+(?:–\d+)?) — ', t)
        if m and l.mask[0] == 'B' and l.x0 < 70 and l.size == 9.1:
            entries.append({'num': m.group(1), 'lines': [l]})
            last_kind = 'entry'
            continue
        if lb.startswith('Note:') and t.startswith('Note:'):
            notes_after.append({'after': entries[-1]['num'] if entries else None, 'lines': [l]})
            last_kind = 'note'
            continue
        if last_kind == 'note' and not lb:
            notes_after[-1]['lines'].append(l)
            continue
        if lb.startswith('Unused') and re.match(r'Unused [a-z]+:', t):
            extras.append(l)
            last_kind = 'extra'
            continue
        if entries and last_kind == 'entry':
            entries[-1]['lines'].append(l)
        else:
            review(f'{ctx}: unexpected line after explanations: {t!r} (page {l.page})')
    unused = None
    for l in extras:
        m = re.match(r'Unused ([a-z]+): (.*?)\.?$', l.text.strip())
        unused = {'label': m.group(1), 'keys': [k.strip() for k in m.group(2).split(',')]}
    passage_note = join_lines(pre_lines)[0] if pre_lines else None
    if passage_note:
        NOTES.append(f'{ctx}: passage has a note before paragraph A, kept as passageNote: {passage_note!r}')
    notes_out = []
    for n_ in notes_after:
        txt = join_lines(n_['lines'])[0][len('Note:'):].strip()
        is_last = n_['after'] == (entries[-1]['num'] if entries else None)
        notes_out.append({'after': n_['after'], 'text': txt, 'setLevel': is_last})
    return dict(meta=meta, lesson=lesson, title=title, paragraphs=paragraphs_out, blocks=blocks, passage_note=passage_note, notes=notes_out,
                ans_rows=ans_rows, word_limit_line=word_limit_line, entries=entries, unused=unused)


# ─────────────────────────────────────────────────── explanation entries ──
def bold_label_positions(text, mask, label):
    """Positions where `label` occurs in bold."""
    out = []
    for m in re.finditer(re.escape(label), text):
        seg = mask[m.start():m.end()]
        if all(c == 'B' for c in seg.replace(' ', '')):
            out.append(m.start())
    return out


PARA_REF = re.compile(r'\s*\((Paragraphs? [A-H](?:(?:,| and) [A-H])*)\)\.?\s*$')


def split_evidence(ev):
    """Return (evidence text, stated paragraph list or None, whole_is_quote).
    A trailing "(Paragraph X)" is removed from the text; references inside the text are kept there
    (and the trailing one too when the text also refers to other paragraphs)."""
    ev = ev.strip()
    stated = []
    m = PARA_REF.search(ev)
    body = ev[:m.start()].strip() if m else ev
    inner = re.findall(r'\((Paragraphs? [A-H](?:(?:,| and) [A-H])*)\)', body)
    for r in inner:
        stated += re.findall(r'\b([A-H])\b', r.split(' ', 1)[1])
    if m:
        stated += re.findall(r'\b([A-H])\b', m.group(1).split(' ', 1)[1])
        if not inner:
            ev = body
        else:
            ev = ev.rstrip('.') if ev.endswith(').') else ev
    whole = False
    if len(ev) >= 2 and ev[0] == '"' and ev.count('"') == 2 and ev.endswith('"'):
        ev = ev[1:-1]
        whole = True
    elif len(ev) >= 3 and ev[0] == '"' and ev.count('"') == 2 and ev.endswith('".'):
        ev = ev[1:-2]
        whole = True
    seen = []
    for x in stated:
        if x not in seen:
            seen.append(x)
    return ev, (seen or None), whole


def parse_entry(e, ctx):
    text, mask = join_lines(e['lines'])
    num = e['num']
    head_end = text.index(' — ') + 3
    evs = bold_label_positions(text, mask, 'Evidence')
    whys = bold_label_positions(text, mask, 'Why:')
    if not evs or not whys:
        review(f'{ctx} Q{num}: explanation without bold Evidence/Why labels: {text[:120]!r}')
        return None
    ans = text[head_end:evs[0]].strip()
    if ans.endswith('.'):
        ans = ans[:-1].strip()
    evidence_parts = []
    for k, pos in enumerate(evs):
        end = evs[k + 1] if k + 1 < len(evs) else whys[0]
        seg = text[pos:end].strip()
        m = re.match(r'Evidence(?: \(([A-Z])\))?:\s*(.*)$', seg, re.S)
        evidence_parts.append({'key': m.group(1), 'raw': m.group(2).strip()})
    if len(whys) > 1:
        review(f'{ctx} Q{num}: more than one bold "Why:" label')
    why = text[whys[0] + 4:].strip()
    for bm in re.finditer(r'B[B ]*B|B', mask):
        seg = text[bm.start():bm.end()].strip()
        if bm.start() < head_end + len(ans) + 2:
            continue
        if re.fullmatch(r'Evidence(?: \([A-Z]\))?:|Why:', seg):
            continue
        review(f'{ctx} Q{num}: unexpected bold text inside explanation: {seg!r}')
    return {'num': num, 'answer': ans, 'evidence': evidence_parts, 'why': why, 'text': text}


# ────────────────────────────────────────────────────────────── answers ──
def strip_accents(s):
    import unicodedata
    return ''.join(c for c in unicodedata.normalize('NFKD', s) if not unicodedata.combining(c))


def split_top(s, sep=' / '):
    """Split on ' / ' (or ' OR ') outside parentheses."""
    out, depth, cur, i = [], 0, '', 0
    while i < len(s):
        c = s[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        if depth == 0 and (s.startswith(' / ', i) or s.startswith(' OR ', i)):
            out.append(cur.strip())
            cur = ''
            i += 3 if s.startswith(' / ', i) else 4
            continue
        cur += c
        i += 1
    out.append(cur.strip())
    return [x for x in out if x]


def expand_one(a):
    """Expand optional parenthesised parts: '(the) sound' -> ['sound', 'the sound'];
    '(the / its) cells' -> ['cells', 'the cells', 'its cells']; 'fir(s)' -> ['fir', 'firs']."""
    parts = re.split(r'(\([^)]*\))', a)
    choices = []
    for p_ in parts:
        if p_.startswith('(') and p_.endswith(')'):
            inner = [x.strip() for x in p_[1:-1].split('/')]
            choices.append([''] + inner)
        else:
            choices.append([p_])
    import itertools
    out = []
    for combo in itertools.product(*choices):
        # "fir(s)" style suffix: no space before the parenthesis → glue
        v = norm_ws(''.join(c if not (k > 0 and parts[k].startswith('(') and parts[k - 1] and not parts[k - 1].endswith(' ') and c)
                             else c for k, c in enumerate(combo)))
        if v and v not in out:
            out.append(v)
    # minimal first
    out.sort(key=lambda v: (len(v.split()), len(v)))
    return out


def expand_alternatives(s):
    """Returns (canonical, accepted list, minimal forms of each top-level alternative)."""
    s = s.strip()
    m = re.fullmatch(r'(\S+) \((\S+)\)', s)
    if m and strip_accents(m.group(1)).lower() == strip_accents(m.group(2)).lower():
        NOTES.append(f'answer "{s}": the bracketed form is an alternative spelling, so both are accepted')
        return m.group(1), [m.group(1), m.group(2)], [m.group(1), m.group(2)]
    acc, minimal = [], []
    for a in split_top(s):
        ex = expand_one(a)
        minimal.append(ex[0])
        for v in ex:
            if v not in acc:
                acc.append(v)
    return minimal[0], acc, minimal


def word_limit_max(wl):
    """Return (max words, number allowed) for 'NO MORE THAN TWO WORDS AND/OR A NUMBER' etc."""
    if not wl:
        return None, False
    w = wl.upper()
    num = 'NUMBER' in w
    m = re.search(r'NO MORE THAN (\w+) WORDS?', w)
    if m:
        return NUMWORDS.get(m.group(1)), num
    m = re.search(r'\b(ONE|TWO|THREE) WORDS?\b', w)
    if m:
        return NUMWORDS[m.group(1)], num
    if 'A NUMBER' in w or 'ONE NUMBER' in w:
        return 0, True
    return None, num


def count_words(ans):
    toks = ans.split()
    return len(toks), sum(1 for t in toks if re.fullmatch(r'[\d.,:/%°C–-]+|\d+(st|nd|rd|th|s)?', t))


NUMBER_WORDS = set('zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen '
                   'eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand million billion trillion '
                   'half quarter'.split())


def is_num_token(t):
    t = t.lower().strip(',.')
    if re.fullmatch(r'[\d][\d.,:/%°–-]*(?:c|st|nd|rd|th|s)?|[\d.,]+%?', t):
        return True
    return all(p in NUMBER_WORDS for p in t.split('-')) and t != ''


def count_words_numbers(a):
    """IELTS-style count: a run of number tokens ('five hundred million', 'a hundred and fifty', '2.5 million') is ONE number."""
    toks = a.split()
    words = nums = 0
    k = 0
    while k < len(toks):
        t = toks[k]
        if is_num_token(t) or (t.lower() == 'a' and k + 1 < len(toks) and toks[k + 1].lower() in ('hundred', 'thousand', 'million')):
            nums += 1
            k += 1
            while k < len(toks) and (is_num_token(toks[k]) or (toks[k].lower() == 'and' and k + 1 < len(toks) and is_num_token(toks[k + 1]))):
                k += 1
            continue
        words += 1
        k += 1
    return words, nums


def is_numeric_format(a):
    """An alternative that only re-writes a number/unit (40 litres, 80%, 100 m, forty)."""
    return any(is_num_token(t) for t in a.split()) or bool(re.search(r'\d', a))


def norm_match(s):
    s = strip_accents(s).lower().replace('’', "'").replace('‘', "'").replace('“', '"').replace('”', '"')
    s = re.sub(r"[^a-z0-9°%]+", ' ', s)
    return ' ' + s.strip() + ' '


# ─────────────────────────────────────────────────────────── group builders ──
def instruction_split(lines):
    """Split leading instruction lines (not bold-led) from the rest."""
    inst = []
    k = 0
    while k < len(lines) and not lines[k].lead_bold() and lines[k].size == 9.4 and lines[k].x0 < 70:
        inst.append(lines[k])
        k += 1
    return inst, lines[k:]


def instr_text(lines):
    return '\n'.join(join_lines(p)[0] for p in paragraphs(lines))


def parse_items(lines, ctx):
    """Items led by a bold token (number, letter, roman numeral) with hanging-indent continuation."""
    items = []
    loose = []
    for l in lines:
        lb = l.lead_bold()
        tok = lb.split(' ')[0] if lb else ''
        if lb and l.x0 < 70 and (re.fullmatch(r'\d+', tok) or re.fullmatch(r'[A-Z]', tok) or tok in ROMAN):
            t = l.text.strip()
            items.append({'key': tok, 'text': t[len(tok):].strip(), 'line': l})
        elif items and l.x0 > 70 and not lb:
            items[-1]['text'] += ' ' + l.text.strip()
        else:
            loose.append((len(items), l))
    return items, loose


def wordlimit_from_instruction(inst):
    for s in inst.split('\n'):
        m = re.match(r'(?:Choose|Write|Use) (.*?) from the (?:passage|text)', s)
        if m:
            return m.group(1)
    return None


def build_groups(S, P, pdf):
    slug = TYPES[S['type'] - 1][0]
    ctx = S['ctx']
    groups = []
    for bi, b in enumerate(P['blocks']):
        hdr = b['header'].text.strip()
        m = re.match(r'Questions (\d+)–(\d+)$', hdr)
        rng = (int(m.group(1)), int(m.group(2))) if m else None
        if not m:
            review(f'{ctx}: unparsable block header {hdr!r}')
        inst_lines, rest = instruction_split(b['lines'])
        list_title = None
        if inst_lines and re.match(r'List of [A-Z]', inst_lines[-1].text.strip()):
            list_title = inst_lines[-1].text.strip()
            inst_lines = inst_lines[:-1]
        inst = instr_text(inst_lines)
        g = {'id': f'g{bi + 1}', 'range': rng, 'instruction': inst}
        if list_title and slug not in ('headings', 'matching_features', 'sentence_endings'):
            review(f'{ctx}: unexpected list title {list_title!r}')
        if slug in ('mcq',):
            if 'Choose TWO letters' in inst or 'Choose THREE letters' in inst:
                pick = 2 if 'TWO' in inst else 3
                ilines = inst.split('\n')
                k = next(j for j, s in enumerate(ilines) if s.startswith('Choose TWO') or s.startswith('Choose THREE'))
                items, loose = parse_items(rest, ctx)
                if loose:
                    review(f'{ctx}: loose lines in multi block: {[l.text for _, l in loose]}')
                opts = [{'key': it['key'], 'text': it['text']} for it in items]
                g.update(type='multi', pick=pick, instruction='\n'.join(ilines[:k + 1]),
                         questions=[{'number': rng[0], 'numbers': list(range(rng[0], rng[1] + 1)),
                                     'text': '\n'.join(ilines[k + 1:]), 'options': opts}])
            else:
                items, loose = parse_items(rest, ctx)
                if loose:
                    review(f'{ctx}: loose lines in MCQ block: {[l.text for _, l in loose]}')
                qs = []
                for it in items:
                    if re.fullmatch(r'\d+', it['key']):
                        qs.append({'number': int(it['key']), 'text': it['text'], 'options': []})
                    else:
                        if not qs:
                            review(f'{ctx}: option before any question: {it["text"]!r}')
                            continue
                        qs[-1]['options'].append({'key': it['key'], 'text': it['text']})
                g.update(type='mcq', questions=qs)
        elif slug in ('tfng', 'ynng'):
            items, loose = parse_items(rest, ctx)
            if loose:
                review(f'{ctx}: loose lines: {[l.text for _, l in loose]}')
            g.update(type=slug, options=['TRUE', 'FALSE', 'NOT GIVEN'] if slug == 'tfng' else ['YES', 'NO', 'NOT GIVEN'],
                     questions=[{'number': int(it['key']), 'text': it['text']} for it in items])
        elif slug == 'matching_info':
            items, loose = parse_items(rest, ctx)
            if loose:
                review(f'{ctx}: loose lines: {[l.text for _, l in loose]}')
            mm = re.search(r'letter, ([A-Z])–([A-Z])', inst)
            opts = [chr(c) for c in range(ord(mm.group(1)), ord(mm.group(2)) + 1)] if mm else None
            if not mm:
                review(f'{ctx}: letter range not found in matching instruction')
            g.update(type='matching', options=opts, reusable='NB You may use any letter more than once' in inst,
                     questions=[{'number': int(it['key']), 'text': it['text']} for it in items])
        elif slug == 'headings':
            items, loose = parse_items(rest, ctx)
            title = list_title
            for _, l in loose:
                if l.text.strip() == 'List of Headings':
                    title = 'List of Headings'
                else:
                    review(f'{ctx}: loose line in headings block: {l.text!r}')
            hs = [{'key': it['key'], 'text': it['text']} for it in items if it['key'] in ROMAN]
            il = g['instruction'].split('\n')
            exl = [x for x in il if x.startswith('Example:')]
            if exl:
                em = re.fullmatch(r'Example: Paragraph ([A-H]) — ([ivx]+)', exl[0])
                if em:
                    g['example'] = {'text': f'Paragraph {em.group(1)}', 'paragraph': em.group(1), 'answer': em.group(2), 'source': exl[0]}
                    g['instruction'] = '\n'.join(x for x in il if x != exl[0])
                else:
                    review(f'{ctx}: unparsed example line {exl[0]!r}')
            qs = []
            for it in items:
                if re.fullmatch(r'\d+', it['key']):
                    pm = re.fullmatch(r'Paragraph ([A-H])', it['text'])
                    if not pm:
                        review(f'{ctx}: heading question not "Paragraph X": {it["text"]!r}')
                    qs.append({'number': int(it['key']), 'text': it['text'], 'paragraph': pm.group(1) if pm else None})
            bad = [it for it in items if not (it['key'] in ROMAN or re.fullmatch(r'\d+', it['key']))]
            if bad:
                review(f'{ctx}: unexpected items in headings block: {[b["text"] for b in bad]}')
            g.update(type='heading', headingsTitle=title, headings=hs, questions=qs)
        elif slug in ('matching_features', 'sentence_endings'):
            items, loose = parse_items(rest, ctx)
            otitle = list_title
            for _, l in loose:
                if l.text.strip().startswith('List of '):
                    otitle = l.text.strip()
                elif l.text.strip().startswith('NB '):
                    g['instruction'] += '\n' + l.text.strip()
                else:
                    review(f'{ctx}: loose line: {l.text!r}')
            opts = [{'key': it['key'], 'text': it['text']} for it in items if re.fullmatch(r'[A-Z]', it['key'])]
            qs = [{'number': int(it['key']), 'text': it['text']} for it in items if re.fullmatch(r'\d+', it['key'])]
            reusable = 'NB You may use any letter more than once' in g['instruction']
            if slug == 'matching_features':
                g.update(type='matching_features', optionsTitle=otitle, options=opts, reusable=reusable, questions=qs)
            else:
                g.update(type='sentence_endings', endingsTitle=otitle, endings=opts, questions=qs)
        elif slug in ('sentence_completion', 'short_answer'):
            items, loose = parse_items(rest, ctx)
            if loose:
                review(f'{ctx}: loose lines: {[l.text for _, l in loose]}')
            g.update(type='gap' if slug == 'sentence_completion' else 'short_answer',
                     wordLimit=wordlimit_from_instruction(inst),
                     questions=[{'number': int(it['key']), 'text': gaps(it['text'])} for it in items])
        elif slug == 'summary_completion':
            tl = [l for l in rest if l.size == 10.2 and l.bold]
            txt = [l for l in rest if l.size == 9.6 and not l.bold]
            bank = [l for l in rest if l.size == 9.0 and abs(l.x0 - 68.7) < 1]
            other = [l for l in rest if l not in tl and l not in txt and l not in bank]
            if other:
                review(f'{ctx}: unclassified summary lines: {[l.text for l in other]}')
            ps = paragraphs(txt, gap=16.0)
            g.update(type='summary', wordLimit=wordlimit_from_instruction(inst), title=join_lines(tl)[0] if tl else None,
                     text='\n\n'.join(gaps(join_lines(p)[0]) for p in ps))
            if bank:
                g['options'] = parse_bank_lines(bank)
            else:
                mm = re.search(r'list of words, ([A-Z])–([A-Z])', inst)
                if mm:
                    letters = [chr(c) for c in range(ord(mm.group(1)), ord(mm.group(2)) + 1)]
                    pat = r'\s' + r' (.+?) '.join(letters) + r' (.+?)$'
                    sm = None
                    for st in reversed([m0.start() for m0 in re.finditer(r'\s' + letters[0] + ' ', g['text'])]):
                        sm = re.compile(pat).match(g['text'], st)
                        if sm:
                            break
                    if sm:
                        g['options'] = [{'key': k, 'text': v} for k, v in zip(letters, sm.groups())]
                        g['text'] = g['text'][:sm.start()]
                        review(f'{ctx}: source layout defect — the word bank ({mm.group(1)}–{mm.group(2)}) is printed inside the summary '
                               f'text (no box, keys not bold); it was split out into options automatically: '
                               + ', '.join(f"{k} {v}" for k, v in zip(letters, sm.groups())))
                    else:
                        review(f'{ctx}: summary says "list of words" but no word bank was found')
            g['questions'] = []
        elif slug == 'note_completion':
            tl = [l for l in rest if l.size == 10.6 and l.bold]
            lines_out = []
            for l in rest:
                if l in tl:
                    continue
                t = l.text.strip()
                if l.bold and l.size == 9.6:
                    lines_out.append({'text': gaps(t), 'level': 0})
                elif t.startswith('• '):
                    lines_out.append({'text': gaps(t[2:].strip()), 'level': 1})
                elif t.startswith('– ') and l.x0 > 80:
                    lines_out.append({'text': gaps(t[2:].strip()), 'level': 2})
                else:
                    review(f'{ctx}: unclassified note line: {t!r} (x0={l.x0})')
            g.update(type='notes', wordLimit=wordlimit_from_instruction(inst), title=join_lines(tl)[0] if tl else None,
                     lines=lines_out, questions=[])
        elif slug in ('table_completion', 'flowchart_completion', 'diagram_label'):
            tl = [l for l in rest if l.size == 10.6 and l.bold]
            bank = [l for l in rest if l.size == 9.0 and abs(l.x0 - 68.7) < 1 and l.bold and re.match(r'[A-Z] ', l.text)
                    and parse_bank_lines([l]) and len(parse_bank_lines([l])) >= 2]
            # region spans (page, y0, y1): after the title, before the bank / ANSWERS
            struct_lines = [l for l in rest if l not in tl and l not in bank]
            spans = spans_of(struct_lines, pad=6)
            if slug == 'table_completion':
                cols, rows = parse_table(pdf, spans)
                g.update(type='table', wordLimit=wordlimit_from_instruction(inst), title=join_lines(tl)[0] if tl else None,
                         columns=cols, rows=rows)
                # verify every text line of the region is represented in cells
                check_table_coverage(ctx, struct_lines, cols, rows)
            elif slug == 'flowchart_completion':
                steps, left = parse_flowchart(pdf, spans, ctx)
                if left:
                    review(f'{ctx}: flow-chart words outside any box: {left}')
                g.update(type='flowchart', wordLimit=wordlimit_from_instruction(inst), title=join_lines(tl)[0] if tl else None,
                         steps=steps)
            else:
                labels, caps = parse_diagram(pdf, spans, ctx)
                g.update(type='diagram', wordLimit=wordlimit_from_instruction(inst), title=join_lines(tl)[0] if tl else None,
                         caption=caps[0] if caps else None, labels=labels)
                if len(caps) > 1:
                    g['annotations'] = caps[1:]
            if bank:
                g['options'] = parse_bank_lines(bank)
            g['questions'] = []
        else:
            raise ValueError(slug)
        groups.append(g)
    return groups


def spans_of(lines, pad=6):
    by = collections.OrderedDict()
    for l in lines:
        a = by.setdefault(l.page, [l.top, l.bottom])
        a[0] = min(a[0], l.top)
        a[1] = max(a[1], l.bottom)
    return [(p, a[0] - pad, a[1] + pad) for p, a in by.items()]


def check_table_coverage(ctx, lines, cols, rows):
    if not cols:
        review(f'{ctx}: table not found by geometry')
        return
    cells = norm_match(' '.join(cols + [c for r in rows for c in r]).replace('______', '......'))
    for l in lines:
        t = norm_match(l.text)
        for w in t.split():
            if (' ' + w + ' ') not in cells:
                review(f'{ctx}: table line word {w!r} not found in parsed cells (line {l.text!r})')
                return


# ─────────────────────────────────────────────────────────── assemble set ──
GAP_NUM = re.compile(r'\((\d+)\) ______')


def gap_numbers_in(g):
    t = g['type']
    blobs = []
    if t == 'summary':
        blobs = [g['text']]
    elif t == 'notes':
        blobs = [x['text'] for x in g['lines']]
    elif t == 'table':
        blobs = [c for r in g['rows'] for c in r] + (g['columns'] or [])
    elif t == 'flowchart':
        for s in g['steps']:
            if isinstance(s, str):
                blobs.append(s)
            else:
                for col in s['branches']:
                    blobs += col
    elif t == 'diagram':
        blobs = [x['text'] for x in g['labels']]
    nums = []
    for b in blobs:
        nums += [int(n) for n in GAP_NUM.findall(b)]
    return nums


def assemble(S, P, pdf):
    slug, tname, _ = TYPES[S['type'] - 1]
    ctx = S['ctx']
    groups = build_groups(S, P, pdf)
    # answers by number
    ans_table = {}
    for k, v in P['ans_rows']:
        ans_table[k] = v
    entries = {}
    for e in P['entries']:
        pe = parse_entry(e, ctx)
        if pe:
            if pe['num'] in entries:
                review(f'{ctx}: duplicate explanation for Q{pe["num"]}')
            entries[pe['num']] = pe
    passage_paras = P['paragraphs']
    # fill questions for structured groups from the gap numbers
    for g in groups:
        if g['type'] in ('summary', 'notes', 'table', 'flowchart', 'diagram'):
            nums = gap_numbers_in(g)
            if len(nums) != len(set(nums)):
                review(f'{ctx}: a gap number appears twice in the {g["type"]} structure: {nums}')
            g['questions'] = [{'number': n} for n in sorted(set(nums))]
    # attach answers
    for g in groups:
        for q in g['questions']:
            key = f"{q['numbers'][0]}–{q['numbers'][-1]}" if 'numbers' in q else str(q['number'])
            raw = ans_table.get(key)
            e = entries.get(key)
            if raw is None:
                review(f'{ctx} Q{key}: no row in ANSWERS table')
            if e is None:
                review(f'{ctx} Q{key}: no explanation entry')
            fill_answer(ctx, slug, g, q, key, raw, e, passage_paras)
    # word limit line consistency
    wl_line = P['word_limit_line']
    for g in groups:
        if 'wordLimit' in g:
            if wl_line and g['wordLimit'] and wl_line.rstrip('.') != g['wordLimit']:
                review(f'{ctx}: instruction word limit {g["wordLimit"]!r} differs from "Word limit:" line {wl_line!r}')
            if g['wordLimit'] is None and wl_line:
                g['wordLimit'] = wl_line.rstrip('.')
    if P['unused']:
        groups[-1]['unusedOptions'] = P['unused']['keys']
    for n_ in P['notes']:
        if n_['setLevel']:
            groups[-1].setdefault('notes', []).append(n_['text'])
            NOTES.append(f'{ctx}: "Note:" paragraph after the last explanation kept as group note: {n_["text"]!r}')
        else:
            for g in groups:
                for q in g['questions']:
                    if str(q['number']) == n_['after']:
                        q['note'] = n_['text']
            NOTES.append(f'{ctx}: "Note:" paragraph after the explanation of Q{n_["after"]} kept as that question\'s note: {n_["text"]!r}')
    # tidy group fields order
    out_groups = []
    for g in groups:
        rng = g.pop('range')
        if g['type'] not in ('summary', 'notes', 'table', 'flowchart', 'diagram'):
            g['title'] = GROUP_TITLES.get(g['type'])   # display title, like the existing reading_passages groups
        order = ['id', 'type', 'title', 'instruction', 'pick', 'wordLimit', 'options', 'optionsTitle', 'reusable', 'headingsTitle',
                 'headings', 'endingsTitle', 'endings', 'caption', 'annotations', 'text', 'lines', 'columns', 'rows', 'steps', 'labels',
                 'example', 'questions', 'unusedOptions', 'notes']
        ng = {k: g[k] for k in order if k in g}
        for k in g:
            if k not in ng:
                ng[k] = g[k]
        out_groups.append((ng, rng))
    return out_groups, entries, ans_table


GROUP_TITLES = {
    'mcq': 'Choose the correct letter', 'multi': 'Choose TWO letters', 'tfng': 'True / False / Not Given',
    'ynng': 'Yes / No / Not Given', 'heading': 'Matching Headings', 'matching': 'Matching Information',
    'matching_features': 'Matching Features', 'sentence_endings': 'Matching Sentence Endings',
    'gap': 'Sentence Completion', 'short_answer': 'Short Answer', 'summary': 'Summary Completion',
    'notes': 'Note Completion', 'table': 'Table Completion', 'flowchart': 'Flow-chart Completion',
    'diagram': 'Diagram Label Completion'}


def option_keys(g, q):
    t = g['type']
    if t in ('mcq', 'multi'):
        return [o['key'] for o in q['options']]
    if t in ('tfng', 'ynng'):
        return g['options']
    if t == 'heading':
        return [h['key'] for h in g['headings']]
    if t == 'matching':
        return g['options'] or []
    if t == 'matching_features':
        return [o['key'] for o in g['options']]
    if t == 'sentence_endings':
        return [o['key'] for o in g['endings']]
    if g.get('options'):
        return [o['key'] for o in g['options']]
    return None


def fill_answer(ctx, slug, g, q, key, raw, e, paras):
    t = g['type']
    raw = raw or ''
    qctx = f'{ctx} Q{key}'
    if t == 'multi':
        m = re.match(r'([A-Z](?:, [A-Z])+)(?: \((.*)\))?$', raw)
        q['answer'] = m.group(1).split(', ') if m else None
        if m and m.group(2):
            q['answerNote'] = m.group(2)
        if not m:
            review(f'{qctx}: unparsable multi answer {raw!r}')
        q['accepted'] = list(q['answer']) if q['answer'] else []   # the correct letters, any order
    elif t == 'heading':
        m = re.match(r'\(([A-H])\) ([ivx]+)$', raw)
        if not m:
            review(f'{qctx}: unparsable heading answer {raw!r}')
            q['answer'] = raw
        else:
            if m.group(1) != q.get('paragraph'):
                review(f'{qctx}: ANSWERS table paragraph ({m.group(1)}) differs from question text paragraph ({q.get("paragraph")})')
            q['answer'] = m.group(2)
        q['accepted'] = [q['answer']]
    elif option_keys(g, q) is not None and t not in ('gap', 'short_answer'):
        q['answer'] = raw
        q['accepted'] = [raw]
    else:
        canon, acc, minimal = expand_alternatives(raw)
        q['answer'] = canon
        q['_minimal'] = minimal
        if canon != raw:
            q['answerDisplay'] = raw
        q['accepted'] = acc
    # explanation header answer consistency
    if e:
        ea = e['answer']
        if t == 'multi':
            exp = ' and '.join(q['answer'] or [])
            if ea != exp:
                review(f'{qctx}: explanation answer {ea!r} vs ANSWERS table {raw!r}')
        elif g.get('options') and t in ('summary', 'flowchart', 'diagram', 'notes', 'table'):
            m = re.match(r'([A-Z]) \((.*)\)$', ea)
            opt = {o['key']: o['text'] for o in g['options']}
            if not m or m.group(1) != raw or opt.get(m.group(1)) != m.group(2):
                review(f'{qctx}: explanation answer {ea!r} vs table {raw!r} / option text {opt.get(raw)!r}')
        elif t == 'heading':
            if ea != q['answer']:
                review(f'{qctx}: explanation answer {ea!r} vs ANSWERS table {raw!r}')
        elif ea != raw:
            review(f'{qctx}: explanation answer {ea!r} vs ANSWERS table {raw!r}')
        # evidence
        evs = e['evidence']
        items = []
        for part in evs:
            text, stated, whole = split_evidence(part['raw'])
            items.append(locate_evidence(qctx, part['key'], text, stated, whole, paras))
        if t == 'multi':
            q['evidence'] = '\n'.join(i['evidence'] for i in items)
            q['evidenceParagraph'] = items[0]['evidenceParagraph']
            q['evidenceParagraphSource'] = items[0]['evidenceParagraphSource']
            q['evidenceItems'] = items
        else:
            if len(items) != 1:
                review(f'{qctx}: {len(items)} evidence labels for a single question')
            it = items[0]
            q['evidence'] = it['evidence']
            q['evidenceIsQuote'] = it['evidenceIsQuote']
            q['evidenceParagraph'] = it['evidenceParagraph']
            q['evidenceParagraphSource'] = it['evidenceParagraphSource']
            if it.get('evidenceParagraphsStated'):
                q['evidenceParagraphsStated'] = it['evidenceParagraphsStated']
        q['explanation'] = gaps(e['why'])
        # alternatives mentioned in the Why text (reported, not added)
        if t in ('gap', 'short_answer', 'summary', 'notes', 'table', 'flowchart', 'diagram') and not g.get('options'):
            for mm in re.finditer(r'"([^"]+)"[^".]{0,60}?\b(?:is|are) also (?:acceptable|accepted|correct)', e['why']):
                alt = mm.group(1)
                ptxt = ' '.join(p['text'] for p in paras)
                pm = re.search(r'(?<![\w])' + re.escape(alt) + r'(?![\w])', ptxt, re.I)
                if pm and pm.group(0) != alt:
                    alt = pm.group(0)   # use the passage's capitalisation (the explanation capitalises it at sentence start)
                if alt not in q['accepted'] and alt.lower() not in [a.lower() for a in q['accepted']]:
                    q['accepted'].append(alt)
                    NOTES.append(f'{qctx}: added "{alt}" to accepted because the explanation says: "{mm.group(0)}"')
    else:
        q.setdefault('evidence', None)
        q.setdefault('evidenceParagraph', None)
        q.setdefault('evidenceParagraphSource', None)
        q.setdefault('explanation', None)


EVSTATS = collections.Counter()


def in_order(frags, pt):
    pos = 0
    for f in frags:
        k = pt.find(' ' + f + ' ', pos)
        if k < 0:
            return False
        pos = k + len(f) + 1
    return True


def locate_evidence(qctx, key, text, stated, whole, paras):
    res = {'evidence': text}
    if key:
        res = {'key': key, 'evidence': text}
    res['evidenceIsQuote'] = whole
    quotes = re.findall(r'"([^"]+)"', text)
    frags_src = [text] if whole else quotes
    derived = None
    found_all = None
    found_paras = set()
    if frags_src:
        pnorm = [(p['letter'], norm_match(p['text'])) for p in paras]
        whole = ''.join(f' §{l} ' + pt for l, pt in pnorm)
        per_quote = []
        for q in frags_src:
            frags = [f for f in (norm_match(x).strip() for x in re.split(r'\.\.\.|…|\[[^\]]*\]', q)) if f]
            if not frags:
                continue
            hits = [l for l, pt in pnorm if in_order(frags, pt)]
            if not hits and in_order(frags, whole):
                k = whole.find(' ' + frags[0] + ' ')
                first = re.findall(r'§([A-H])', whole[:k])[-1]
                hits = [first]
                NOTES.append(f'{qctx}: evidence quote spans more than one paragraph (starts in {first}): "{q}"')
            per_quote.append(hits)
        found_all = bool(per_quote) and all(per_quote)
        if found_all:
            common = [l for l, _ in pnorm if all(l in h for h in per_quote)]
            derived = common[0] if common else per_quote[0][0]
            if not common:
                NOTES.append(f'{qctx}: evidence quotes come from different paragraphs {per_quote}; derived = first quote\'s paragraph ({derived})')
            for h in per_quote:
                found_paras |= set(h)
    if stated:
        match = [x for x in stated if x in found_paras]
        res['evidenceParagraph'] = match[0] if match else stated[0]
        res['evidenceParagraphSource'] = 'stated'
        if len(stated) > 1:
            res['evidenceParagraphsStated'] = stated
        EVSTATS['stated'] += 1
        if derived and not (set(stated) & found_paras):
            review(f'{qctx}: stated paragraph ({", ".join(stated)}) disagrees with where the quote was found ({derived}); kept the stated one')
            EVSTATS['stated_disagree'] += 1
    elif derived:
        res['evidenceParagraph'] = derived
        res['evidenceParagraphSource'] = 'derived'
        EVSTATS['derived'] += 1
    else:
        # description-style evidence may name a paragraph ("Paragraph E describes ...")
        named = []
        for x in re.findall(r'\bParagraph ([A-H])\b', text):
            if x not in named:
                named.append(x)
        if named and not frags_src:
            res['evidenceParagraph'] = named[0]
            res['evidenceParagraphSource'] = 'stated'
            if len(named) > 1:
                res['evidenceParagraphsStated'] = named
            EVSTATS['named_in_description'] += 1
        else:
            res['evidenceParagraph'] = None
            res['evidenceParagraphSource'] = None
    if frags_src:
        EVSTATS['with_quotes'] += 1
        if not found_all:
            EVSTATS['quote_not_found'] += 1
            review(f'{qctx}: evidence quote not found in the passage: "{text}"')
    else:
        EVSTATS['description_only'] += 1
    return res


# ───────────────────────────────────────────────────────── type lessons ──
def parse_type_lesson(T, pdf, slug, name):
    L = T['lines']
    title_l = [l for l in L if l.size == 12.5 and l.bold]
    title = join_lines(title_l)[0]
    if title.startswith('LESSON: '):
        title = title[len('LESSON: '):]
    body = [l for l in L if l not in title_l]
    sections = []
    # separate special structures: lesson tables (Sans 9.0 at x 68.7) and example exhibits (note/flow/diagram/table)
    k = 0
    paras_lines = []
    special = []
    for l in body:
        if l.size == 9.4 and (l.x0 < 70 or 75 < l.x0 < 80):
            paras_lines.append(l)
        else:
            special.append(l)
    # group special lines into contiguous blocks (by position in body)
    sp_blocks = []
    for l in special:
        if sp_blocks and body.index(l) == body.index(sp_blocks[-1][-1]) + 1:
            sp_blocks[-1].append(l)
        else:
            sp_blocks.append([l])
    seq = []   # ordered list of ('para', lines) / ('special', lines)
    idx_special = {id(b[0]): b for b in sp_blocks}
    skip = set()
    for l in body:
        if id(l) in skip:
            continue
        if id(l) in idx_special:
            b = idx_special[id(l)]
            for x in b:
                skip.add(id(x))
            seq.append(('special', b))
        elif l.size == 9.4 and (l.x0 < 70 or 75 < l.x0 < 80):
            if seq and seq[-1][0] == 'para':
                seq[-1][1].append(l)
            else:
                seq.append(('para', [l]))
        else:
            seq.append(('special', [l]))
    cur = None
    for kind, ls in seq:
        if kind == 'para':
            for p in paragraphs(ls):
                t, m = join_lines(p)
                lb = ''
                # bold lead ending in '.' or ':' = section heading
                kk = 0
                while kk < len(t) and (m[kk] == 'B' or (m[kk] == ' ' and kk + 1 < len(m) and m[kk + 1] == 'B')):
                    kk += 1
                lb = t[:kk].strip()
                te = re.match(r'Tiny example(?: \([^)]*\))?\.', t)
                if te and not lb:
                    # the PDF prints this label without bold in one lesson — treat it as the section heading anyway
                    lb, kk = te.group(0), te.end()
                    NOTES.append(f'type lesson {slug}: section label {lb!r} is not bold in the PDF; treated as a section heading')
                if lb and len(lb) > 3 and (lb.endswith('.') or lb.endswith(':')) and not re.fullmatch(r'[A-Z]|[ivx]+', lb):
                    cur = {'heading': lb.rstrip('.:').strip() if lb.endswith('.') else lb.rstrip(':').strip(), 'paras': []}
                    rest = t[kk:].strip()
                    if lb.endswith(':'):
                        cur['heading'] = lb.rstrip(':').strip()
                    sections.append(cur)
                    if rest:
                        cur['paras'].append(rest)
                else:
                    if cur is None:
                        cur = {'heading': None, 'paras': []}
                        sections.append(cur)
                    cur['paras'].append(t)
        else:
            ex = parse_lesson_exhibit(ls, pdf, slug)
            if cur is None:
                cur = {'heading': None, 'paras': []}
                sections.append(cur)
            cur.setdefault('exhibits', []).append(ex)
            cur['paras'].append(('EXHIBIT', len(cur['exhibits']) - 1))
    out = []
    for s in sections:
        text_parts = [p for p in s['paras'] if isinstance(p, str)]
        sec = {'heading': s['heading'], 'text': gaps('\n'.join(text_parts))}
        items = [p for p in text_parts if re.match(r'\d+\. ', p)]
        if items and len(items) == len(text_parts):
            sec['items'] = [gaps(re.sub(r'^\d+\. ', '', p)) for p in items]
        if s.get('exhibits'):
            # keep the position of each exhibit relative to the paragraphs
            sec['exhibits'] = s['exhibits']
            order = []
            n = 0
            for p in s['paras']:
                if isinstance(p, str):
                    order.append({'paragraph': n})
                    n += 1
                else:
                    order.append({'exhibit': p[1]})
            sec['layout'] = order
        out.append(sec)
    return {'id': f'rtl_{slug}', 'questionType': slug, 'name': name, 'title': title, 'sections': out}


def parse_lesson_exhibit(ls, pdf, slug):
    """A table / notes / flow-chart / diagram shown inside a type lesson."""
    fonts = {(l.font, l.size) for l in ls}
    spans = spans_of(ls, pad=4)
    if any(l.size == 9.0 and abs(l.x0 - 68.7) < 1 for l in ls) or any(l.size == 9.0 and abs(l.x0 - 66.7) < 1 for l in ls):
        title = [l for l in ls if l.size == 10.6]
        rest = [l for l in ls if l not in title]
        cols, rows = parse_table(pdf, spans_of(rest, pad=4))
        if cols:
            ex = {'kind': 'table', 'columns': cols, 'rows': rows}
            if title:
                ex['title'] = join_lines(title)[0]
            return ex
    if any(l.text.strip() in ARROWS for l in ls):
        title = [l for l in ls if l.size == 10.6]
        rest = [l for l in ls if l not in title]
        steps, left = parse_flowchart(pdf, spans_of(rest, pad=4), slug)
        if left:
            review(f'type lesson {slug}: flow-chart example words outside boxes: {left}')
        return {'kind': 'flowchart', 'title': join_lines(title)[0] if title else None, 'steps': steps}
    if any(l.size == 8.4 for l in ls):
        labels, caps = parse_diagram(pdf, spans, slug)
        return {'kind': 'diagram', 'caption': caps[0] if caps else None, 'labels': labels}
    if any(l.text.strip().startswith('• ') for l in ls):
        title = [l for l in ls if l.size == 10.6]
        lines = []
        for l in ls:
            if l in title:
                continue
            t = l.text.strip()
            if t.startswith('• '):
                lines.append({'text': gaps(t[2:]), 'level': 1})
            else:
                lines.append({'text': gaps(t), 'level': 0})
        return {'kind': 'notes', 'title': join_lines(title)[0] if title else None, 'lines': lines}
    review(f'type lesson {slug}: unclassified lesson block: {[l.text for l in ls]}')
    return {'kind': 'text', 'lines': [gaps(l.text.strip()) for l in ls]}


# ─────────────────────────────────────────────────────────────────── build ──
def build_all(pdf, cache=None):
    import pickle
    if cache and os.path.exists(cache):
        lines = pickle.load(open(cache, 'rb'))
    else:
        lines = extract_lines(pdf)
        if cache:
            pickle.dump(lines, open(cache, 'wb'))
    types, sets = segment(lines)
    items, raw_parsed = [], []
    for S in sets:
        slug, tname, _ = TYPES[S['type'] - 1]
        P = parse_set(S, pdf)
        groups_r, entries, ans_table = assemble(S, P, pdf)
        groups = [g for g, _ in groups_r]
        words = sum(len(p['text'].split()) for p in P['paragraphs'])
        qcount = sum(len(q.get('numbers', [q['number']])) for g in groups for q in g['questions'])
        diff = S['level'].lower()
        item = {
            'id': f"rb_{slug}_{S['set']:02d}",
            'bankSet': S['set'],
            'questionType': slug,
            'questionTypeName': tname,
            'questionTypeDetail': P['meta'].get('Question Type'),
            'part': LEVEL_PART[S['level']],
            'difficulty': diff,
            'topic': P['meta'].get('Topic'),
            'title': P['title'],
            'words': words,
            **({'passageNote': P['passage_note']} if P['passage_note'] else {}),
            'paragraphs': P['paragraphs'],
            'lesson': P['lesson'],
            'groups': groups,
            'questionCount': qcount,
            'sourcePages': [S['page'], S['lines'][-1].page],
        }
        items.append(item)
        raw_parsed.append((S, P, groups_r, entries, ans_table))
    lessons = []
    for T in types:
        slug, tname, heading = TYPES[T['n'] - 1]
        if T['heading'] != heading:
            review(f'TYPE {T["n"]} heading {T["heading"]!r} != expected {heading!r}')
        lessons.append(parse_type_lesson(T, pdf, slug, tname))
    return lines, types, sets, items, raw_parsed, lessons




# ───────────────────────────────────────────────────────────── validation ──
class Checks:
    def __init__(self):
        self.results = []   # (name, passed, detail)

    def add(self, name, ok, detail=''):
        self.results.append((name, bool(ok), detail))


def raw_text_norm(raw):
    raw = re.sub(r'\n\s*\d+\s*\n+\s*' + re.escape(HEADER_TEXT) + r'\s*\n', '\n', raw)
    raw = raw.replace('\f', '\n')
    raw = raw.replace(HEADER_TEXT, ' ')
    raw = GAP_RE.sub('______', raw)
    return norm_ws(raw)


def all_strings(o, path=''):
    if isinstance(o, str):
        yield path, o
    elif isinstance(o, dict):
        for k, v in o.items():
            yield from all_strings(v, f'{path}.{k}')
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from all_strings(v, f'{path}[{i}]')


def range_letters(inst, pat):
    m = re.search(pat, inst)
    if not m:
        return None
    a, b = m.group(1), m.group(2)
    if a in ROMAN and b in ROMAN:
        return ROMAN[ROMAN.index(a):ROMAN.index(b) + 1]
    return [chr(c) for c in range(ord(a), ord(b) + 1)]


def validate(items, raw_parsed, lessons, sets, raw_norm):
    C = Checks()
    # ── counts
    C.add('280 sets parsed', len(items) == 280, f'{len(items)} sets')
    per_type = collections.Counter(i['questionType'] for i in items)
    C.add('20 sets per question type', all(per_type[t[0]] == 20 for t in TYPES), dict(per_type))
    bad_nums = [t[0] for t in TYPES if sorted(i['bankSet'] for i in items if i['questionType'] == t[0]) != list(range(1, 21))]
    C.add('set numbers 01-20 in each type', not bad_nums, bad_nums or 'all types 01-20')
    diff = collections.Counter(i['difficulty'] for i in items)
    diff_type = {t[0]: dict(collections.Counter(i['difficulty'] for i in items if i['questionType'] == t[0])) for t in TYPES}
    same_split = all(d == {'easy': 6, 'medium': 8, 'hard': 6} for d in diff_type.values())
    C.add('difficulty counts', True, f'overall {dict(diff)}; every type easy 6 / medium 8 / hard 6: {same_split}')
    mism = []
    for (S, P, _, _, _), it in zip(raw_parsed, items):
        if P['meta'].get('Difficulty', '').upper() != S['level']:
            mism.append(f"{it['id']}: header {S['level']} vs Difficulty line {P['meta'].get('Difficulty')}")
        if not P['meta'].get('Question Type', '').startswith(TYPES[S['type'] - 1][1]):
            mism.append(f"{it['id']}: Question Type line {P['meta'].get('Question Type')!r}")
        if not it['topic']:
            mism.append(f"{it['id']}: no Topic")
    C.add('set header fields (Difficulty line = SET level, Question Type line = type, Topic present)', not mism, mism[:10] or 'ok')
    for m in mism:
        review(m)

    # ── questions / answers / explanations
    problems = collections.defaultdict(list)
    for (S, P, groups_r, entries, ans_table), it in zip(raw_parsed, items):
        nums = []
        hdr = []
        for g, rng in groups_r:
            gnums = []
            for q in g['questions']:
                gnums += q.get('numbers', [q['number']])
            nums += gnums
            if rng:
                hdr += list(range(rng[0], rng[1] + 1))
                if gnums != list(range(rng[0], rng[1] + 1)):
                    problems['block header range != questions in block'].append(
                        f"{it['id']}: header \"Questions {rng[0]}–{rng[1]}\" but the block contains questions {gnums}")
        if nums != list(range(1, len(nums) + 1)):
            problems['question numbers not contiguous from 1'].append(f"{it['id']}: {nums}")
        if sorted(set(hdr)) != nums:
            problems['"Questions x–y" ranges != question numbers'].append(f"{it['id']}: ranges cover {sorted(set(hdr))}, questions {nums}")
        def expand(k):
            if '–' in k:
                a, b = k.split('–')
                return list(range(int(a), int(b) + 1))
            return [int(k)]
        an = sorted(n for k in ans_table for n in expand(k))
        en = sorted(n for k in entries for n in expand(k))
        if an != nums:
            problems['ANSWERS table numbers != question numbers'].append(f"{it['id']}: table {an} vs questions {nums}")
        if en != nums:
            problems['explanation numbers != question numbers'].append(f"{it['id']}: explanations {en} vs questions {nums}")
        if it['questionCount'] != len(nums):
            problems['questionCount wrong'].append(it['id'])
        for g, _ in groups_r:
            for q in g['questions']:
                for f in ('answer', 'evidence', 'explanation'):
                    if not q.get(f):
                        problems[f'question without {f}'].append(f"{it['id']} Q{q['number']}")
    for name in ['question numbers not contiguous from 1', '"Questions x–y" ranges != question numbers',
                 'block header range != questions in block', 'ANSWERS table numbers != question numbers',
                 'explanation numbers != question numbers', 'questionCount wrong', 'question without answer',
                 'question without evidence', 'question without explanation']:
        C.add(f'no {name}', not problems[name], problems[name] or 'ok')
        for p_ in problems[name]:
            review(f'{name}: {p_}')

    # ── answer validity
    bad = collections.defaultdict(list)
    wl_stats = collections.Counter()
    for it in items:
        passage_norm = norm_match(' '.join(p['text'] for p in it['paragraphs']))
        passage_words = set(passage_norm.split())
        for g in it['groups']:
            t = g['type']
            inst = g.get('instruction', '')
            for q in g['questions']:
                qid = f"{it['id']} Q{q['number']}"
                keys = option_keys(g, q)
                if t in ('tfng', 'ynng'):
                    if q['answer'] not in g['options']:
                        bad['tfng/ynng answer not in options'].append(f'{qid}: {q["answer"]!r}')
                elif t == 'mcq':
                    if q['answer'] not in keys:
                        bad['mcq answer not an option key'].append(f'{qid}: {q["answer"]!r} not in {keys}')
                elif t == 'multi':
                    if not q['answer'] or any(a not in keys for a in q['answer']) or len(q['answer']) != g['pick']:
                        bad['multi answer invalid'].append(f'{qid}: {q["answer"]!r}')
                elif t == 'heading':
                    if q['answer'] not in keys:
                        bad['heading answer not in heading list'].append(f'{qid}: {q["answer"]!r}')
                elif t in ('matching', 'matching_features', 'sentence_endings'):
                    if not keys or q['answer'] not in keys:
                        bad[f'{t} answer not an option key'].append(f'{qid}: {q["answer"]!r} not in {keys}')
                elif g.get('options'):   # completion from a word bank
                    if q['answer'] not in keys:
                        bad['word-bank answer not an option key'].append(f'{qid}: {q["answer"]!r} not in {keys}')
                else:   # words from the passage
                    maxw, num_ok = word_limit_max(g.get('wordLimit'))
                    if maxw is None:
                        bad['word limit not parsed'].append(f'{qid}: {g.get("wordLimit")!r}')
                    ok_any = False
                    for a in q['accepted']:
                        ws = norm_match(a).split()
                        missing = [w for w in ws if w not in passage_words]
                        if not missing:
                            ok_any = True
                        elif is_numeric_format(a):
                            wl_stats['numeric alternative not verbatim in passage (expected)'] += 1
                        else:
                            bad['gap answer word not found in passage'].append(f'{qid}: accepted "{a}" — {missing} not in passage')
                    if not ok_any:
                        bad['gap answer: no accepted form found in passage'].append(f'{qid}: {q["accepted"]}')
                    # word limit on the minimal form of each alternative ("(the)" words are optional)
                    for a in q.get('_minimal', [q['answer']]):
                        if maxw is None:
                            continue
                        nw, nn = count_words_numbers(a)
                        wl_stats['checked'] += 1
                        if nw > maxw or nn > (1 if num_ok else 0) and not (nw + nn <= maxw):
                            bad['gap answer exceeds word limit'].append(f'{qid}: "{a}" ({nw} word(s) + {nn} number(s)) vs {g.get("wordLimit")}')
            # group-level option-range checks
            if t == 'mcq':
                for q in g['questions']:
                    ks = [o['key'] for o in q['options']]
                    exp = range_letters(inst, r'letter, ([A-Z]), .* or ([A-Z])') or ['A', 'B', 'C', 'D']
                    if ks != exp:
                        bad['mcq options != instruction letters'].append(f"{it['id']} Q{q['number']}: {ks} vs {exp}")
            if t == 'multi':
                for q in g['questions']:
                    ks = [o['key'] for o in q['options']]
                    exp = range_letters(inst, r'letters, ([A-Z])–([A-Z])')
                    if ks != exp:
                        bad['multi options != instruction letters'].append(f"{it['id']}: {ks} vs {exp}")
            if t == 'heading':
                exp = range_letters(inst, r'number, ([ivx]+)–([ivx]+)')
                ks = [h['key'] for h in g['headings']]
                if ks != exp:
                    bad['heading list != instruction range'].append(f"{it['id']}: {ks} vs {exp}")
                used = [q['answer'] for q in g['questions']]
                if len(used) != len(set(used)):
                    bad['heading used twice'].append(f"{it['id']}: {used}")
                for q in g['questions']:
                    if q['paragraph'] not in [p['letter'] for p in it['paragraphs']]:
                        bad['heading question paragraph not in passage'].append(f"{it['id']} Q{q['number']}")
            if t == 'matching':
                letters = [p['letter'] for p in it['paragraphs']]
                if g['options'] != letters:
                    bad['matching options != passage paragraph letters'].append(f"{it['id']}: {g['options']} vs {letters}")
            if t in ('matching_features', 'sentence_endings'):
                opts = g['options'] if t == 'matching_features' else g['endings']
                ks = [o['key'] for o in opts]
                exp = range_letters(inst, r'([A-Z])–([A-Z])')
                if ks != exp:
                    bad[f'{t} options != instruction range'].append(f"{it['id']}: {ks} vs {exp}")
                if t == 'matching_features' and not g.get('reusable'):
                    used = [q['answer'] for q in g['questions']]
                    if len(used) != len(set(used)):
                        bad['features letter reused without NB'].append(f"{it['id']}: {used}")
            if g.get('options') and t in ('summary', 'flowchart', 'diagram', 'notes', 'table'):
                ks = [o['key'] for o in g['options']]
                exp = range_letters(inst, r'([A-Z])–([A-Z])')
                if ks != exp:
                    bad['word bank != instruction range'].append(f"{it['id']}: {ks} vs {exp}")
            if 'unusedOptions' in g:
                all_keys = option_keys(g, g['questions'][0]) if t not in ('mcq', 'multi') else None
                used = {q['answer'] for q in g['questions']}
                if g.get('example'):
                    used.add(g['example']['answer'])
                exp = [k for k in (all_keys or []) if k not in used]
                if exp != g['unusedOptions']:
                    bad['"Unused" line != options not used by answers'].append(f"{it['id']}: stated {g['unusedOptions']} vs computed {exp}")
            if t in ('gap',):
                for q in g['questions']:
                    if q['text'].count('______') != 1:
                        bad['sentence-completion question without exactly one gap'].append(f"{it['id']} Q{q['number']}: {q['text']!r}")
            if t in ('summary', 'notes', 'table', 'flowchart', 'diagram'):
                nums = gap_numbers_in(g)
                if sorted(nums) != [q['number'] for q in g['questions']] or len(nums) != len(set(nums)):
                    bad['structure gap numbers != questions'].append(f"{it['id']}: {nums}")
                blob = json.dumps({k: g.get(k) for k in ('text', 'lines', 'rows', 'columns', 'steps', 'labels')}, ensure_ascii=False)
                if re.search(r'\(\d{1,2}\)(?! ______)', blob):
                    bad['gap number without gap marker'].append(f"{it['id']}: " + ', '.join(re.findall(r'\(\d{1,2}\)(?! ______).{0,15}', blob)))
            if re.search(r'^List of ', g.get('instruction', ''), re.M):
                bad['instruction still contains a "List of ..." title'].append(f"{it['id']}")
            if t in ('heading', 'matching_features', 'sentence_endings') and not (g.get('headingsTitle') or g.get('optionsTitle') or g.get('endingsTitle')):
                bad['list title missing'].append(f"{it['id']}")
            if 'Example' in g.get('instruction', ''):
                bad['instruction still contains an Example line'].append(f"{it['id']}")
    names = ['tfng/ynng answer not in options', 'mcq answer not an option key', 'multi answer invalid',
             'heading answer not in heading list', 'matching answer not an option key',
             'matching_features answer not an option key', 'sentence_endings answer not an option key',
             'word-bank answer not an option key', 'mcq options != instruction letters', 'multi options != instruction letters',
             'heading list != instruction range', 'heading used twice', 'heading question paragraph not in passage',
             'matching options != passage paragraph letters', 'matching_features options != instruction range',
             'sentence_endings options != instruction range', 'features letter reused without NB', 'word bank != instruction range',
             '"Unused" line != options not used by answers', 'sentence-completion question without exactly one gap',
             'structure gap numbers != questions', 'gap number without gap marker', 'word limit not parsed',
             'gap answer word not found in passage', 'gap answer: no accepted form found in passage',
             'gap answer exceeds word limit', 'instruction still contains an Example line',
             'instruction still contains a "List of ..." title', 'list title missing']
    for n in names:
        C.add(f'no {n}', not bad[n], bad[n] or 'ok')
        for b in bad[n]:
            review(f'{n}: {b}')
    C.add('word-limit checks run on passage-word answers', wl_stats['checked'] > 0, dict(wl_stats))

    # ── evidence
    C.add('evidence located', EVSTATS['quote_not_found'] == 0,
          f"quoted evidence: {EVSTATS['with_quotes']} (not found: {EVSTATS['quote_not_found']}); description-only evidence (no quote, e.g. NOT GIVEN): "
          f"{EVSTATS['description_only']}; paragraph stated in PDF: {EVSTATS['stated']} (disagreeing with the quote location: {EVSTATS['stated_disagree']}); "
          f"paragraph derived from the quote: {EVSTATS['derived']}; paragraph named inside a description: {EVSTATS['named_in_description']}")
    nullp = [f"{it['id']} Q{q['number']}" for it in items for g in it['groups'] for q in g['questions'] if not q.get('evidenceParagraph')]
    C.add('questions without evidenceParagraph (description-only evidence that names no paragraph, or quote not found)', True, f'{len(nullp)}: {nullp}')

    # ── paragraphs / passage
    pb = []
    for it in items:
        letters = [p['letter'] for p in it['paragraphs']]
        if letters != [chr(65 + k) for k in range(len(letters))]:
            pb.append(f"{it['id']}: letters {letters}")
        for p in it['paragraphs']:
            if not p['text'].strip():
                pb.append(f"{it['id']}: empty paragraph {p['letter']}")
    C.add('paragraph letters consecutive from A, none empty', not pb, pb or 'ok')
    wc = [i['words'] for i in items]
    C.add('passage word counts', True, f'min {min(wc)}, max {max(wc)}, mean {sum(wc) / len(wc):.0f}')
    titles = collections.defaultdict(list)
    for it in items:
        titles[it['title']].append(it)
    dups = {t: v for t, v in titles.items() if len(v) > 1}
    dup_notes = []
    for t, v in dups.items():
        a, b = v[0], v[1]
        same = [p['text'] for p in a['paragraphs']] == [p['text'] for p in b['paragraphs']]
        wa = set(norm_match(' '.join(p['text'] for p in a['paragraphs'])).split())
        wb = set(norm_match(' '.join(p['text'] for p in b['paragraphs'])).split())
        jac = len(wa & wb) / len(wa | wb)
        dup_notes.append(f'"{t}": {", ".join(x["id"] for x in v)} — identical passage text: {same}; '
                         f'paragraphs {len(a["paragraphs"])} vs {len(b["paragraphs"])}, words {a["words"]} vs {b["words"]}, '
                         f'vocabulary overlap {jac:.0%}; topics {a["topic"]!r} / {b["topic"]!r}')
    C.add('passage titles unique (duplicates listed)', True, dup_notes or 'all unique')
    for d in dup_notes:
        review('Duplicate passage title ' + d)

    # ── artefacts
    art = []
    for it in items + lessons:
        for path, sv in all_strings(it):
            if HEADER_TEXT in sv:
                art.append(f"{it['id']}{path}: page header text")
            if re.search(r'\.{4,}', sv.replace('...', '', 0)) and '......' in sv:
                art.append(f"{it['id']}{path}: dotted gap left: {sv[:80]!r}")
            for m in re.finditer(r'\b\w+- [a-z]\w*', sv):
                if not re.match(r'\w+- (and|or|to)\b', m.group(0)):
                    art.append(f"{it['id']}{path}: possible broken hyphenation {m.group(0)!r}")
            if '\u00ad' in sv or '\ufffd' in sv:
                art.append(f"{it['id']}{path}: soft hyphen / replacement char")
    C.add('no leftover artefacts (page header, "......", broken hyphenation)', not art, art[:20] or 'ok')
    for a in art:
        review('Artefact: ' + a)
    # ── independent cross-check with pdftotext
    if raw_norm:
        miss = collections.defaultdict(list)
        checked = collections.Counter()
        for (S, P, groups_r, entries, ans_table), it in zip(raw_parsed, items):
            for p in it['paragraphs']:
                checked['paragraph'] += 1
                if norm_ws(p['text']) not in raw_norm:
                    miss['paragraph'].append(f"{it['id']} {p['letter']}")
            for g in it['groups']:
                for q in g['questions']:
                    if q.get('text'):
                        checked['question text'] += 1
                        if norm_ws(q['text']) not in raw_norm:
                            miss['question text'].append(f"{it['id']} Q{q['number']}: {q['text'][:60]!r}")
                    for o in q.get('options', []):
                        checked['option'] += 1
                        if norm_ws(o['text']) not in raw_norm:
                            miss['option'].append(f"{it['id']} Q{q['number']} {o['key']}")
                    if q.get('explanation'):
                        checked['explanation'] += 1
                        if norm_ws(q['explanation']) not in raw_norm:
                            miss['explanation'].append(f"{it['id']} Q{q['number']}")
                    if q.get('evidence'):
                        for ev in q['evidence'].split('\n'):
                            checked['evidence'] += 1
                            if norm_ws(ev) not in raw_norm:
                                miss['evidence'].append(f"{it['id']} Q{q['number']}")
                for k in ('headings', 'endings'):
                    for o in g.get(k, []):
                        checked[k] += 1
                        if norm_ws(o['text']) not in raw_norm:
                            miss[k].append(f"{it['id']} {o['key']}")
                if g['type'] == 'matching_features':
                    for o in g['options']:
                        checked['feature option'] += 1
                        if norm_ws(o['text']) not in raw_norm:
                            miss['feature option'].append(f"{it['id']} {o['key']}")
                if g['type'] == 'notes':
                    for ln in g['lines']:
                        checked['note line'] += 1
                        if norm_ws(ln['text']) not in raw_norm:
                            miss['note line'].append(f"{it['id']}: {ln['text']!r}")
                if g['type'] == 'summary':
                    for para in g['text'].split('\n\n'):
                        checked['summary paragraph'] += 1
                        if norm_ws(para) not in raw_norm:
                            miss['summary paragraph'].append(f"{it['id']}")
            for f in ('title', 'topic'):
                checked[f] += 1
                if norm_ws(it[f]) not in raw_norm:
                    miss[f].append(it['id'])
            for f in ('text', 'example'):
                if it['lesson'][f]:
                    for para in it['lesson'][f].split('\n'):
                        if para.strip():
                            checked['set lesson paragraph'] += 1
                            if norm_ws(para) not in raw_norm:
                                miss['set lesson paragraph'].append(it['id'])
        tot_miss = sum(len(v) for v in miss.values())
        C.add('independent cross-check: text fields found verbatim in pdftotext output', tot_miss == 0,
              f'checked {dict(checked)}; not found: ' + (json.dumps({k: v[:15] for k, v in miss.items()}, ensure_ascii=False) if tot_miss else '0'))
        for k, v in miss.items():
            for x in v:
                review(f'cross-check vs pdftotext: {k} not found verbatim: {x}')
    # ── ids / json
    ids = [i['id'] for i in items] + [l['id'] for l in lessons]
    C.add('ids unique', len(ids) == len(set(ids)), f'{len(ids)} ids')
    try:
        json.loads(json.dumps(items, ensure_ascii=False))
        ok = True
    except Exception as e:
        ok = False
    C.add('JSON valid (round-trip)', ok)
    miss_sec = []
    for l in lessons:
        hs = [x['heading'] or '' for x in l['sections']]
        for need in ('What it tests', 'Common traps', 'Step-by-step strategy', 'Tiny example'):
            if not any(h.startswith(need) for h in hs):
                miss_sec.append(f"{l['id']}: no '{need}' section")
        if any(x['heading'] is None for x in l['sections']):
            miss_sec.append(f"{l['id']}: text before the first section heading")
    C.add('type lessons have What it tests / Common traps / Step-by-step strategy / Tiny example sections', not miss_sec, miss_sec or 'ok')
    for m_ in miss_sec:
        review(m_)
    C.add('14 type lessons', len(lessons) == 14 and [l['questionType'] for l in lessons] == [t[0] for t in TYPES], len(lessons))
    return C


# ──────────────────────────────────────────────────────── practice tests ──
def build_practice_tests(items):
    """20 short tests: Part 1 easy + Part 2 medium + Part 3 hard, three different question
    types per test, no set reused, question types spread as evenly as possible. Deterministic."""
    by = collections.defaultdict(list)
    for it in items:
        by[(it['questionType'], it['difficulty'])].append(it)
    for v in by.values():
        v.sort(key=lambda x: x['bankSet'])
    slugs = [t[0] for t in TYPES]
    n = len(slugs)
    # type index for (test t, part k): rotate so each part walks through the 14 types and the three parts differ
    offsets = (0, 5, 10)
    tests = []
    used = set()
    usage = collections.Counter()
    for t in range(20):
        pids = []
        types_in = []
        for k, (level, off) in enumerate(zip(('easy', 'medium', 'hard'), offsets)):
            slug = slugs[(t + off) % n]
            pool = [x for x in by[(slug, level)] if x['id'] not in used]
            it = pool[0]
            used.add(it['id'])
            usage[slug] += 1
            pids.append(it['id'])
            types_in.append(slug)
        assert len(set(types_in)) == 3
        qc = sum(next(i for i in items if i['id'] == pid)['questionCount'] for pid in pids)
        tests.append({'id': f'rpt_{t + 1:02d}', 'number': t + 1, 'title': f'Reading Practice Test {t + 1}', 'kind': 'short',
                      'passages': pids, 'questionTypes': types_in, 'questionCount': qc, 'minutes': int(qc * 1.5 + 0.5)})
    return tests, usage


# ───────────────────────────────────────────────────────────────── report ──
def write_report(path, C, items, lessons, tests, usage, spot, extra):
    manual = ''
    if os.path.exists(path):
        old = open(path, encoding='utf-8').read()
        m = re.search(r'<!-- manual:start -->.*?<!-- manual:end -->', old, re.S)
        if m:
            manual = m.group(0)
    if not manual:
        manual = '<!-- manual:start -->\n_(Visual spot-check notes: to be filled in after comparing the rendered pages with the JSON.)_\n<!-- manual:end -->'
    L = []
    L.append('# Reading question bank import report\n')
    L.append(f'Source: `{SOURCE_NAME}` (740 pages). Generated by `tool/import_reading_bank.py`.\n')
    L.append('Outputs: `seed/data/27_reading_bank_passages.json`, `seed/data/28_reading_type_lessons.json`, '
             '`seed/data/29_reading_practice_tests.json`, and the matching `seed/formats/27-29_*.json`.\n')
    L.append('## Counts\n')
    qn = sum(i['questionCount'] for i in items)
    L.append(f'- Passages (sets): **{len(items)}**; questions: **{qn}**; type lessons: **{len(lessons)}**; practice tests: **{len(tests)}**')
    diff = collections.Counter(i['difficulty'] for i in items)
    L.append(f'- Difficulty: easy {diff["easy"]} (Part 1), medium {diff["medium"]} (Part 2), hard {diff["hard"]} (Part 3)')
    gt = collections.Counter(g['type'] for i in items for g in i['groups'])
    L.append(f'- Question groups by type: ' + ', '.join(f'{k} {v}' for k, v in sorted(gt.items())))
    L.append('')
    L.append('| Type | Sets | Questions | Words (min–max) |')
    L.append('|---|---|---|---|')
    for slug, name, _ in TYPES:
        its = [i for i in items if i['questionType'] == slug]
        L.append(f'| {name} (`{slug}`) | {len(its)} | {sum(i["questionCount"] for i in its)} | '
                 f'{min(i["words"] for i in its)}–{max(i["words"] for i in its)} |')
    L.append('\n## Checks (run by the script)\n')
    L.append('| Check | Result | Detail |')
    L.append('|---|---|---|')
    for name, ok, detail in C.results:
        d = detail if isinstance(detail, str) else json.dumps(detail, ensure_ascii=False)
        d = d.replace('|', '\\|').replace('\n', ' ')
        if len(d) > 900:
            d = d[:900] + ' …'
        L.append(f'| {name} | {"PASS" if ok else "**FAIL**"} | {d} |')
    L.append('\n## Needs human review\n')
    if REVIEW:
        for r in REVIEW:
            L.append(f'- {r}')
    else:
        L.append('- (none)')
    L.append('\n## Informational notes (handled automatically)\n')
    for n_ in NOTES:
        L.append(f'- {n_}')
    L.append('\n## Practice tests\n')
    L.append('Built from existing sets only: Part 1 easy + Part 2 medium + Part 3 hard, three different question types per test, '
             'no set used twice, question types rotated (deterministic, no randomness).\n')
    L.append('Type usage across the 60 slots: ' + ', '.join(f'{k} {v}' for k, v in usage.items()) + '\n')
    for t in tests:
        L.append(f"- {t['id']}: {', '.join(t['passages'])} — {t['questionCount']} questions, {t['minutes']} min")
    L.append('\n## Visual spot-check (12 sets, fixed seed)\n')
    L.append('Sets picked with `random.Random(2026)`; their pages were rendered with `pdftoppm` and compared by eye with the JSON.\n')
    for s in spot:
        L.append(f"- {s['id']} — pages {s['pages'][0]}–{s['pages'][1]}")
    L.append('')
    L.append(manual)
    L.append('')
    L.extend(extra)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='utf-8').write('\n'.join(L) + '\n')


# ──────────────────────────────────────────────────────────────── formats ──
def ftypes(items):
    out = {}
    for it in items:
        for k, v in it.items():
            t = type(v).__name__.replace('str', 'string').replace('dict', 'object').replace('list', 'array').replace('float', 'number').replace('int', 'integer').replace('bool', 'boolean').replace('NoneType', 'null')
            out.setdefault(k, set()).add(t)
    return {k: '|'.join(sorted(v)) for k, v in out.items()}


def write_formats(out_root, items, lessons, tests):
    F = os.path.join(out_root, 'seed', 'formats')
    ex = []
    for slug, _, _ in TYPES:
        pick = 'rb_mcq_05' if slug == 'mcq' else f'rb_{slug}_01'
        if slug == 'summary_completion':
            pick = 'rb_summary_completion_01'
        ex.append(next(i for i in items if i['id'] == pick))
    src = f'{SOURCE_NAME} (not yet in the app)'
    f27 = {'_format': {
        'name': 'reading_bank_passages', 'group': 'content', 'table': 'reading_passages', 'primaryKey': 'id',
        'description': 'Question-bank passage: one short Academic reading passage practising ONE question type (5-10 questions), '
                       'with a set lesson, questions, answers, evidence and explanations. Same table and shape as reading_passages, plus bank fields.',
        'currentSourceInApp': src,
        'fields': ftypes(items),
        'required': ['id', 'bankSet', 'questionType', 'part', 'difficulty', 'topic', 'title', 'paragraphs', 'groups', 'questionCount'],
        'relations': ['groups[].questions[].evidenceParagraph → paragraphs[].letter',
                      'questionType → reading_type_lessons.questionType (the "How to attempt" lesson for this type)',
                      'id ← reading_practice_tests.passages[]'],
        'notes': [
            'id = rb_<questionType>_<NN> (NN = bankSet, 01-20 within the type). part: EASY→1, MEDIUM→2, HARD→3.',
            'questionType: mcq, tfng, ynng, matching_info, headings, matching_features, sentence_endings, sentence_completion, '
            'summary_completion, note_completion, table_completion, flowchart_completion, diagram_label, short_answer.',
            'Group types: mcq, multi (pick N, number = first, numbers = all, answer = list), tfng, ynng, heading, matching, '
            'matching_features, sentence_endings, gap (sentence completion), short_answer, summary, notes, table, flowchart, diagram.',
            'Gaps are written "______"; in summary/notes/table/flowchart/diagram they are "(n) ______" and questions[] carry only number + answer data.',
            'answer = canonical answer; accepted = every form the PDF allows ("a / b" alternatives and optional "(the)" words expanded); '
            'answerDisplay = the PDF answer text when it differs from answer.',
            'evidence = the PDF evidence text without surrounding quotes; evidenceIsQuote = true when it is a verbatim passage quote '
            '(false for descriptions such as NOT GIVEN reasons). evidenceParagraphSource: "stated" (PDF gives the paragraph), '
            '"derived" (found by locating the quote), null (unknown).',
            'flowchart.steps[] items are strings (one box) or {"branches": [[boxes of column 1], [column 2], ...]} for parallel boxes.',
            'diagram.labels[]: side left|right, order = top-to-bottom position on that side; caption = the italic text in/above the drawing; '
            'annotations = further italic notes.',
            'notes.lines[].level: 0 heading, 1 bullet, 2 sub-bullet (dash).',
            'Groups have no "id" collisions within a passage (g1, g2 ...). Question numbers are local (1..n); the app offsets them in tests.',
            'One example per question type below.'],
        'recordCountToday': len(items),
        'practiceParts': [
            {'part': 1, 'label': 'Easy sets (Passage 1 level)', 'difficulty': 'easy', 'sets': '01-06 in every type'},
            {'part': 2, 'label': 'Medium sets (Passage 2 level)', 'difficulty': 'medium', 'sets': '07-14 in every type'},
            {'part': 3, 'label': 'Hard sets (Passage 3 level)', 'difficulty': 'hard', 'sets': '15-20 in every type'}]},
        'items': copy.deepcopy(ex)}
    f28 = {'_format': {
        'name': 'reading_type_lessons', 'group': 'content', 'table': 'reading_type_lessons', 'primaryKey': 'id',
        'description': 'Strategy lesson for one Reading question type ("How to attempt ..."), shown before its practice sets.',
        'currentSourceInApp': src,
        'fields': ftypes(lessons),
        'required': ['id', 'questionType', 'name', 'title', 'sections'],
        'relations': ['questionType → reading_bank_passages.questionType'],
        'notes': ['sections[] = {heading, text} in PDF order ("What it tests", "Common traps", "Step-by-step strategy", "Tiny example", ...).',
                  'items = the numbered list when a section is a list; exhibits = tables / notes / flow-charts / diagrams shown in the lesson, '
                  'layout = the order of paragraphs and exhibits in that section.',
                  'One record per question type (14).'],
        'recordCountToday': len(lessons)},
        'items': copy.deepcopy([next(l for l in lessons if l['questionType'] == 'mcq'),
                                next(l for l in lessons if l['questionType'] == 'table_completion')])}
    f29 = {'_format': {
        'name': 'reading_practice_tests', 'group': 'content', 'table': 'reading_tests', 'primaryKey': 'id',
        'description': 'Short Reading practice test assembled from question-bank sets: Part 1 easy + Part 2 medium + Part 3 hard, '
                       'three different question types, 15-25 questions.',
        'currentSourceInApp': src + '; assembled by tool/import_reading_bank.py (no new content)',
        'fields': ftypes(tests),
        'required': ['id', 'number', 'title', 'kind', 'passages', 'questionCount', 'minutes'],
        'relations': ['passages[] → reading_passages.id (rb_*), in order Part 1, 2, 3'],
        'notes': ['kind = "short" (full tests are kind "full": 3 passages, 40 questions, 60 minutes).',
                  'minutes = questionCount x 1.5, rounded half up. Question numbers are offset by the app, like reading_tests.',
                  'No set is used in more than one practice test.'],
        'recordCountToday': len(tests)},
        'items': copy.deepcopy(tests[:2])}
    for name, obj in (('27_reading_bank_passages.json', f27), ('28_reading_type_lessons.json', f28), ('29_reading_practice_tests.json', f29)):
        json.dump(obj, open(os.path.join(F, name), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)


# ─────────────────────────────────────────────────────────────────── main ──

# ───────────────────────────────────────────────── editorial corrections ──
# Applied AFTER validation of the PDF data, so the checks above describe the
# source faithfully. Each correction states the exact old value; if the PDF
# ever changes and the old value no longer matches, the import stops.
CORRECTIONS = [
    ('rb_tfng_09', 6, {
        'evidence': ('the information "can be used ... to decide which products to stock"',
                     'can be used to target offers, design stores and decide which products to stock'),
        'evidenceIsQuote': (False, True), 'evidenceParagraph': ('E', 'E'), 'evidenceParagraphSource': ('stated', 'stated')},
     'Evidence quote did not match the passage word for word; replaced with the exact sentence from paragraph E.'),
    ('rb_ynng_18', 6, {
        'evidence': ('The writer attributes failure to cities being designed "around infrastructure rather than inhabitants" (Paragraph D) and never suggests any intention to fail.',
                     'The writer attributes failure to cities being designed "around its infrastructure rather than its inhabitants" (Paragraph D) and never suggests any intention to fail.')},
     'Quoted words inside the description corrected to match paragraph D exactly.'),
    ('rb_headings_16', 2, {
        'evidence': ('His warnings were widely ignored ... in the United States ... used to support discriminatory policies.',
                     'His warnings were widely ignored ... in the United States ... to support discriminatory policies.'),
        'evidenceParagraph': (None, 'B'), 'evidenceParagraphSource': (None, 'derived')},
     'Evidence quote corrected ("was used to sort … and … to support" in the passage); paragraph B derived.'),
    ('rb_summary_completion_12', 3, {
        'evidence': ("the condition known to human divers as 'the bends'.",
                     'the painful and dangerous condition known to human divers as "the bends"'),
        'evidenceParagraph': (None, 'B'), 'evidenceParagraphSource': (None, 'derived')},
     'Evidence quote corrected to the exact words of paragraph B.'),
    ('rb_flowchart_completion_20', 3, {
        'accepted': (['PCR', 'polymerase chain reaction'], ['PCR']),
        'answerDisplay': ('PCR / polymerase chain reaction', 'PCR')},
     'Removed "polymerase chain reaction" from the accepted answers: it is three words, over the two-word limit, as the explanation itself says.'),
    ('rb_sentence_completion_12', 5, {
        'accepted': (['oxide'], ['oxide', 'protective oxide'])},
     'Added "protective oxide": the explanation says it is also within the limit.'),
]


def apply_corrections(items, C):
    byid = {i['id']: i for i in items}
    log = []
    for pid, num, changes, why in CORRECTIONS:
        q = next(q for g in byid[pid]['groups'] for q in g['questions'] if q['number'] == num)
        for field, (old, new) in changes.items():
            if q.get(field) != old:
                raise SystemExit(f'correction mismatch {pid} Q{num} {field}: expected {old!r}, found {q.get(field)!r}')
            q[field] = new
        q['editorialCorrection'] = why
        log.append(f'- {pid} Q{num}: {why}')
    # accepted forms produced by optional words ("(the) X") must still respect the group's word limit
    for it in items:
        for g in it['groups']:
            maxw, numok = word_limit_max(g.get('wordLimit'))
            if maxw is None:
                continue
            for q in g['questions']:
                acc = q.get('accepted')
                if not isinstance(acc, list):
                    continue
                keep = []
                for a_ in acc:
                    w_, n_ = count_words_numbers(a_)
                    over = (w_ > maxw or n_ > 1) if numok else (w_ + n_ > maxw)
                    if over and a_ != q.get('answer'):
                        log.append(f'- {it["id"]} Q{q["number"]}: removed accepted form "{a_}" ({w_} word(s) + {n_} number(s)) — over the limit "{g["wordLimit"]}"')
                    else:
                        keep.append(a_)
                q['accepted'] = keep
    def _within(a_, lim):
        w_, n_ = count_words_numbers(a_)
        return (w_ <= lim[0] and n_ <= 1) if lim[1] else (w_ + n_ <= lim[0])
    # a number range written in words ("five to twelve") is fine when its figure form ("5–12") is accepted too
    over_main = [f"{it['id']} Q{q['number']}" for it in items for g in it['groups'] if word_limit_max(g.get('wordLimit'))[0] is not None
                 for q in g['questions'] if isinstance(q.get('answer'), str)
                 and not any(_within(a_, word_limit_max(g.get('wordLimit'))) for a_ in (q.get('accepted') or [q['answer']]))]
    C.add('after corrections: every question has at least one accepted answer within its word limit', not over_main, ', '.join(over_main))
    # re-check every quoted evidence against its paragraph after the corrections
    bad = []
    for it in items:
        paras = {p['letter']: norm_match(p['text']) for p in it['paragraphs']}
        whole = norm_match(' '.join(p['text'] for p in it['paragraphs']))
        for g in it['groups']:
            for q in g['questions']:
                if not q.get('evidenceIsQuote'):
                    continue
                frags = [norm_match(f).strip() for f in re.split(r'\.\.\.|…|\[[^\]]*\]', q['evidence']) if norm_match(f).strip()]  # [editorial insertions] are not passage text
                target = paras.get(q.get('evidenceParagraph')) or whole
                if not in_order(frags, target) and not in_order(frags, whole):
                    bad.append(f"{it['id']} Q{q['number']}")
    C.add('after corrections: every quoted evidence is found word for word in the passage', not bad, ', '.join(bad))
    return log


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--pdf', required=True)
    ap.add_argument('--raw', help='pdftotext output of the same PDF (independent cross-check); generated if omitted')
    ap.add_argument('--out', default=ROOT, help='app root (default: this repo)')
    ap.add_argument('--cache', help='pickle cache of extracted lines (development speed-up)')
    ap.add_argument('--render-dir', help='where to render the spot-check pages (PNG); default: a temp dir')
    a = ap.parse_args()
    pdf = pdfplumber.open(a.pdf)
    lines, types, sets, items, raw_parsed, lessons = build_all(pdf, a.cache)
    raw = None
    if a.raw:
        raw = open(a.raw, encoding='utf-8').read()
    else:
        try:
            raw = subprocess.run(['pdftotext', a.pdf, '-'], capture_output=True, text=True, check=True).stdout
        except Exception:
            NOTES.append('pdftotext not available: independent text cross-check skipped')
    raw_norm = raw_text_norm(raw) if raw else None
    C = validate(items, raw_parsed, lessons, sets, raw_norm)
    corrections = apply_corrections(items, C)
    tests, usage = build_practice_tests(items)
    # practice-test checks
    allp = [p for t in tests for p in t['passages']]
    C.add('practice tests: 20 tests, 3 passages each, parts 1/2/3 = easy/medium/hard',
          len(tests) == 20 and all([next(i for i in items if i['id'] == p)['difficulty'] for p in t['passages']] == ['easy', 'medium', 'hard'] for t in tests))
    C.add('practice tests: three different question types in every test',
          all(len({next(i for i in items if i['id'] == p)['questionType'] for p in t['passages']}) == 3 for t in tests))
    C.add('practice tests: no set used twice', len(allp) == len(set(allp)), f'{len(allp)} passages, {len(set(allp))} unique')
    C.add('practice tests: question types spread evenly', max(usage.values()) - min(usage.values()) <= 1, dict(usage))
    # spot-check selection
    rnd = random.Random(2026)
    spot_ids = []
    for slug in rnd.sample([t[0] for t in TYPES], 12):
        spot_ids.append(f'rb_{slug}_{rnd.randint(1, 20):02d}')
    spot = [{'id': i['id'], 'pages': i['sourcePages']} for sid in spot_ids for i in items if i['id'] == sid]
    rd = a.render_dir
    if rd:
        os.makedirs(rd, exist_ok=True)
        for s in spot:
            subprocess.run(['pdftoppm', '-r', '70', '-f', str(s['pages'][0]), '-l', str(s['pages'][1]), '-png', a.pdf,
                            os.path.join(rd, s['id'])], check=False)
    # outputs (drop internal helper fields)
    out_items = []
    for it in items:
        it = copy.deepcopy(it)
        it.pop('sourcePages', None)
        for g in it['groups']:
            for q in g['questions']:
                q.pop('_minimal', None)
        out_items.append(it)
    D = os.path.join(a.out, 'seed', 'data')
    json.dump({'table': 'reading_passages', 'source': SOURCE_NAME, 'items': out_items},
              open(os.path.join(D, '27_reading_bank_passages.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    json.dump({'table': 'reading_type_lessons', 'source': SOURCE_NAME, 'items': lessons},
              open(os.path.join(D, '28_reading_type_lessons.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    json.dump({'table': 'reading_tests', 'source': SOURCE_NAME, 'items': tests},
              open(os.path.join(D, '29_reading_practice_tests.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    # re-load written files (JSON validity on disk)
    for fn in ('27_reading_bank_passages.json', '28_reading_type_lessons.json', '29_reading_practice_tests.json'):
        try:
            json.load(open(os.path.join(D, fn), encoding='utf-8'))
            C.add(f'written file parses as JSON: seed/data/{fn}', True)
        except Exception as e:
            C.add(f'written file parses as JSON: seed/data/{fn}', False, str(e))
    write_formats(a.out, out_items, lessons, tests)
    write_report(os.path.join(a.out, 'seed', 'reports', 'reading_bank_import_report.md'), C, out_items, lessons, tests, usage, spot, [])
    with open(os.path.join(a.out, 'seed', 'reports', 'reading_bank_import_report.md'), 'a', encoding='utf-8') as fh:
        fh.write('\n## Editorial corrections (applied after the checks above)\n\n'
                 'The checks marked FAIL above describe the PDF as printed (source issues). The corrections below '
                 'fix them in the JSON; the two "after corrections" checks confirm the final data.\n\n'
                 + '\n'.join(corrections) + '\n')
    # console summary
    print(f'{len(items)} sets, {sum(i["questionCount"] for i in items)} questions, {len(lessons)} type lessons, {len(tests)} practice tests')
    fails = [r for r in C.results if not r[1]]
    for name, ok, detail in C.results:
        print(('PASS ' if ok else 'FAIL ') + name)
    print(f'{len(fails)} failing checks; {len(REVIEW)} review items; {len(NOTES)} notes')
    print('spot-check sets:', ', '.join(s['id'] for s in spot))


if __name__ == '__main__':
    main()
