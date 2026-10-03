#!/usr/bin/env python3
"""Review PDFs of the speaking question bank for sir.

Input:  assets/content/speaking_bank.json (tool/import_speaking_bank.py) and sir's
        originals (seed/sources/speaking via tool/speaking_source.py) for the change marks.
Output: <out_dir>/Speaking_Sample_Answers_Review.pdf   Part 1 / 2 / 3 with every change marked
        <out_dir>/Speaking_Vocabulary_Review.pdf       the vocabulary dictionary

Usage: python tool/build_speaking_review_pdf.py [out_dir]   (default: seed/reports)
"""
import difflib
import html
import json
import os
import re
import sys

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (Flowable, KeepTogether, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table,
                                TableStyle)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import speaking_source as src  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_DIR = '/usr/share/fonts/truetype/dejavu'
for name, file in [('DV', 'DejaVuSans.ttf'), ('DV-B', 'DejaVuSans-Bold.ttf'), ('DV-I', 'DejaVuSans-Oblique.ttf'),
                   ('DV-BI', 'DejaVuSans-BoldOblique.ttf')]:
    pdfmetrics.registerFont(TTFont(name, os.path.join(FONT_DIR, file)))
pdfmetrics.registerFontFamily('DV', normal='DV', bold='DV-B', italic='DV-I', boldItalic='DV-BI')

INK = colors.HexColor('#151515')
MUTED = colors.HexColor('#6B6B6B')
LINE = colors.HexColor('#DDDDDD')
SOFT = colors.HexColor('#F5F2EC')
ADD = '#D8F0DC'
DEL = '#B3261E'

S = {
    'title': ParagraphStyle('title', fontName='DV-B', fontSize=24, leading=30, textColor=INK),
    'sub': ParagraphStyle('sub', fontName='DV', fontSize=12, leading=17, textColor=MUTED),
    'part': ParagraphStyle('part', fontName='DV-B', fontSize=20, leading=26, textColor=INK, spaceAfter=6),
    'h1': ParagraphStyle('h1', fontName='DV-B', fontSize=14, leading=19, textColor=INK, spaceAfter=2),
    'meta': ParagraphStyle('meta', fontName='DV', fontSize=8.5, leading=12, textColor=MUTED, spaceAfter=4),
    'q': ParagraphStyle('q', fontName='DV-B', fontSize=10, leading=14, textColor=INK, spaceBefore=6),
    'body': ParagraphStyle('body', fontName='DV', fontSize=9.8, leading=14.5, textColor=INK, spaceAfter=4),
    'small': ParagraphStyle('small', fontName='DV', fontSize=8.5, leading=12, textColor=MUTED),
    'bullet': ParagraphStyle('bullet', fontName='DV', fontSize=9.8, leading=14, textColor=INK, leftIndent=12),
    'cell': ParagraphStyle('cell', fontName='DV', fontSize=8, leading=10.5, textColor=INK),
    'cellb': ParagraphStyle('cellb', fontName='DV-B', fontSize=8.5, leading=11, textColor=INK),
}


def esc(s):
    return html.escape(s or '', quote=False)


class Bookmark(Flowable):
    def __init__(self, key, title, level=0):
        super().__init__()
        self.key, self.title, self.level = key, title, level
        self.width = self.height = 0

    def draw(self):
        self.canv.bookmarkPage(self.key)
        self.canv.addOutlineEntry(self.title, self.key, level=self.level, closed=self.level == 0)


def tokens(marked):
    """[(word, is_mark, glue)] from text with [[marks]]; glue = no space before this token."""
    out = []
    for part in re.split(r'(\[\[.+?\]\])', marked):
        if not part:
            continue
        is_mark = part.startswith('[[')
        body = part[2:-2] if is_mark else part
        glue_first = bool(out) and not part[0].isspace() and not is_mark and not out[-1][0].endswith(' ')
        if is_mark:
            glue_first = bool(out) and out[-1][3]
        words = body.split()
        for i, w in enumerate(words):
            out.append((w, is_mark, glue_first if i == 0 else False, False))
        # remember if this part ended without trailing space (so a following mark glues on)
        if out and words:
            w, m, g, _ = out[-1]
            out[-1] = (w, m, g, not part[-1].isspace())
    return [(w, m, g) for w, m, g, _ in out]


def fmt(tok, add=False):
    w, is_mark, _ = tok
    s = esc(w)
    if is_mark:
        s = f'<b><u>{s}</u></b>'
    if add:
        s = f'<font backColor="{ADD}">{s}</font>'
    return s


def join(pieces):
    """pieces: [(html, glue)] → text with spaces except before glued pieces."""
    out = ''
    for i, (h, g) in enumerate(pieces):
        out += h if (i == 0 or g) else ' ' + h
    return out


def plain_html(marked, add=False):
    return join([(fmt(t, add), t[2]) for t in tokens(marked)])


def diff_html(old, new):
    """New text with vocab marks; words not in sir's text get a green background, words he had that were
    removed are shown struck through in red. old=None → no change marks."""
    nt = tokens(new)
    if old is None:
        return plain_html(new)
    ot = tokens(old)
    norm = lambda ts: [re.sub(r'[^\w]', '', t[0].lower()) for t in ts]  # noqa: E731
    sm = difflib.SequenceMatcher(a=norm(ot), b=norm(nt), autojunk=False)
    parts = []
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op == 'equal':
            parts += [(fmt(t), t[2]) for t in nt[j1:j2]]
            continue
        on, nn = norm(ot[i1:i2]), norm(nt[j1:j2])
        if op in ('replace', 'delete') and any(on):
            gone = ' '.join(esc(t[0]) for t in ot[i1:i2])
            parts.append((f'<font color="{DEL}"><strike>{gone}</strike></font>', False))
        if op in ('replace', 'insert'):
            parts += [(fmt(t, add=bool(n)), t[2]) for t, n in zip(nt[j1:j2], nn)]
    return join(parts)


def page(canvas, doc):
    canvas.saveState()
    canvas.setFont('DV', 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 10 * mm, 'IELTS AI by nextED · Speaking question bank · review copy')
    canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, str(doc.page))
    canvas.restoreState()


def legend():
    return Table([[Paragraph(
        f'<b>How to read this:</b> <b><u>bold underlined</u></b> = vocabulary word (tap-to-open in the app) · '
        f'<font backColor="{ADD}">green background</font> = text added by us · '
        f'<font color="{DEL}"><strike>red struck through</strike></font> = your text we removed or replaced. '
        'Anything without a mark is your original wording.', S['small'])]],
        colWidths=[174 * mm], style=TableStyle([('BACKGROUND', (0, 0), (-1, -1), SOFT),
                                                  ('BOX', (0, 0), (-1, -1), 0.5, LINE),
                                                  ('LEFTPADDING', (0, 0), (-1, -1), 8),
                                                  ('TOPPADDING', (0, 0), (-1, -1), 6),
                                                  ('BOTTOMPADDING', (0, 0), (-1, -1), 6)]))


def answers_pdf(bank, out):
    base1 = {s['id']: s for s in json.load(open(os.path.join(ROOT, 'seed/staging/speaking/base/part1_sets.json')))}
    orig1 = {o['source']: o['answer'] for s in base1.values() for o in s['originals']}
    orig2 = {c['id']: c['answer'] for c in src.part2()}
    orig3 = {t['id']: {q['n']: q['answer'] for q in t['questions']} for t in src.part3()}
    c = bank['meta']['counts']
    story = [
        Spacer(1, 30 * mm),
        Paragraph('IELTS Speaking question bank', S['title']),
        Paragraph('Sample answers · review copy for sir', S['sub']),
        Spacer(1, 8 * mm),
        Paragraph(
            f"Part 1: {c['part1Topics']} topics × 5 questions ({c['part1Questions']}) · "
            f"Part 2: {c['part2Cards']} cue cards with a sample talk and 2 rounding-off questions · "
            f"Part 3: {c['part3Topics']} topics × 8 questions ({c['part3Questions']}) · "
            f"{c['vocab']} vocabulary entries (separate PDF).", S['body']),
        Spacer(1, 4 * mm),
        Paragraph('<b>What we changed</b>', S['body']),
    ]
    for line in [
        'Part 1: your 100 questions are grouped into 62 exam-style topics of 5 questions each (the examiner asks '
        '4–5 on one topic). Your questions and answers are unchanged; the 210 new ones are marked NEW.',
        'Part 2: your talks (about 160 words, roughly 1 minute 15 seconds) are extended to 240–290 words so they '
        'last close to 2 minutes, every bullet is covered in order, and each card has 2 rounding-off questions and '
        'its linked Part 3 topics.',
        'Part 3: answers are unchanged except for the vocabulary marks (plain words such as health, both, shift '
        'replaced by real Band 8 words or whole idioms, exactly 3 per answer) and a few softened factual claims '
        '("studies show" → "many argue").',
        'All answers follow one speaker: a young man from Sirajganj working at an education consultancy, BBA '
        'graduate; father recently retired, mother at home, younger sister studying, elder sister married in Dhaka, '
        'grandparents in the village. Contradictions between the files were fixed to match this.',
    ]:
        story.append(Paragraph(esc(line), S['bullet'], bulletText='•'))
    story += [Spacer(1, 6 * mm), legend(), PageBreak()]

    # Part 1
    story += [Bookmark('p1', 'Part 1'), Paragraph('Part 1 · Short questions', S['part'])]
    cat = None
    for t in bank['part1Topics']:
        if t['categoryLabel'] != cat:
            cat = t['categoryLabel']
            story.append(Bookmark(f"p1_{t['category']}", cat, 1))
        block = [Bookmark(t['id'], t['topic'], 2), Paragraph(esc(t['topic']), S['h1']),
                 Paragraph(f"{esc(t['categoryLabel'])} · {t['id']}" + (' · intro topic' if t['intro'] else ''),
                           S['meta'])]
        for i, x in enumerate(t['samples'], 1):
            src_no = x.get('source')
            tag = f'your no. {src_no}' if src_no else '<font color="#2E7D4F">NEW</font>'
            block.append(Paragraph(f'{i}. {esc(x["q"])}  <font size="8" color="#6B6B6B">({tag})</font>', S['q']))
            old = orig1.get(src_no) if src_no else None
            body = diff_html(old, x['answer']) if src_no else plain_html(x['answer'], add=True)
            block.append(Paragraph(body, S['body']))
        story.append(KeepTogether(block))
        story.append(Spacer(1, 3 * mm))
    story.append(PageBreak())

    # Part 2
    story += [Bookmark('p2', 'Part 2'), Paragraph('Part 2 · Cue cards', S['part'])]
    cat = None
    p3names = {t['id']: t['topic'] for t in bank['part3Topics']}
    for card in bank['cueCards']:
        if card['categoryLabel'] != cat:
            cat = card['categoryLabel']
            story.append(Bookmark(f"p2_{card['category']}", cat, 1))
        story += [Bookmark(card['id'], f"{card['number']}. {card['title']}", 2),
                  Paragraph(f"{card['number']}. {esc(card['title'])}", S['h1']),
                  Paragraph(f"{esc(card['categoryLabel'])} · your card {card['cardNumber']} · {card['id']} · "
                            f"{card['sample']['words']} words (yours: {len(tokens(orig2[card['id']]))})", S['meta'])]
        for b in card['bullets']:
            story.append(Paragraph(esc(b), S['bullet'], bulletText='•'))
        story.append(Spacer(1, 2 * mm))
        story.append(Paragraph(diff_html(orig2[card['id']], card['sample']['answer']), S['body']))
        story.append(Paragraph('Rounding-off questions (new)', S['q']))
        for x in card['followUps']:
            story.append(Paragraph(f'<b>{esc(x["q"])}</b> ' + plain_html(x['answer'], add=True),
                                   S['body']))
        story.append(Paragraph('Part 3 link: ' + ' · '.join(esc(p3names[i]) for i in card['part3Topics']), S['meta']))
        story.append(Spacer(1, 4 * mm))
    story.append(PageBreak())

    # Part 3
    story += [Bookmark('p3', 'Part 3'), Paragraph('Part 3 · Discussion', S['part'])]
    cat = None
    for t in bank['part3Topics']:
        if t['categoryLabel'] != cat:
            cat = t['categoryLabel']
            story.append(Bookmark(f"p3_{t['category']}", cat, 1))
        edited = sum(1 for q in t['questions'] if q['edited'])
        story += [Bookmark(t['id'], t['topic'], 2), Paragraph(esc(t['topic']), S['h1']),
                  Paragraph(f"{esc(t['categoryLabel'])} · {t['id']} · {edited} of 8 answers edited", S['meta'])]
        for i, q in enumerate(t['questions'], 1):
            story.append(Paragraph(f'{i}. {esc(q["q"])}  <font size="8" color="#6B6B6B">({esc(q["tagLabel"])})</font>',
                                   S['q']))
            old = orig3[t['id']][i]
            story.append(Paragraph(diff_html(old if q['edited'] else None, q['answer']), S['body']))
        story.append(Spacer(1, 4 * mm))

    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm,
                            bottomMargin=16 * mm, title='IELTS Speaking sample answers · review',
                            author='IELTS AI by nextED')
    doc.build(story, onFirstPage=page, onLaterPages=page)


def vocab_pdf(bank, out):
    v = bank['vocab']
    rows = sorted(v.items(), key=lambda kv: (kv[1]['headword'].lower(), kv[0]))
    story = [Spacer(1, 30 * mm), Paragraph('IELTS Speaking vocabulary', S['title']),
             Paragraph(f'{len(rows)} entries · meaning, British IPA, stress, example, synonyms and level',
                       S['sub']), Spacer(1, 6 * mm),
             Paragraph('Every underlined word in the sample answers opens one of these entries in the app. '
                       'The meaning is the sense used in the answer (the "as used" column). Please check '
                       'meanings, IPA and levels; anything you change here we update in the app.', S['body']),
             PageBreak()]
    head = [Paragraph(h, S['cellb']) for h in ('Word', 'Meaning & example', 'Synonyms', 'Level')]
    data = [head]
    letter = None
    for key, e in rows:
        first = e['headword'][:1].upper()
        stress = '·'.join(s['text'].upper() if s['stress'] else s['text'] for s in e['syllables'])
        word = f"<b>{esc(e['headword'])}</b><br/>{esc(e['ipa'])}<br/><i>{esc(e['pos'])}</i>"
        if stress:
            word += f'<br/>{esc(stress)}'
        if key != e['headword'].lower():
            word += f'<br/><font color="#6B6B6B">as used: {esc(key)}</font>'
        data.append([Paragraph(word, S['cell']),
                     Paragraph(f"{esc(e['meaning'])}<br/><i>{esc(e['example'])}</i>", S['cell']),
                     Paragraph(esc(', '.join(e['synonyms'])), S['cell']),
                     Paragraph(esc(e['level']), S['cell'])])
        if first != letter:
            letter = first
    t = Table(data, colWidths=[44 * mm, 86 * mm, 31 * mm, 13 * mm], repeatRows=1)
    t.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('LINEBELOW', (0, 0), (-1, -1), 0.3, LINE),
                           ('BACKGROUND', (0, 0), (-1, 0), SOFT), ('TOPPADDING', (0, 0), (-1, -1), 4),
                           ('BOTTOMPADDING', (0, 0), (-1, -1), 4)]))
    story.append(t)
    doc = SimpleDocTemplate(out, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm,
                            bottomMargin=16 * mm, title='IELTS Speaking vocabulary · review',
                            author='IELTS AI by nextED')
    doc.build(story, onFirstPage=page, onLaterPages=page)


if __name__ == '__main__':
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'seed', 'reports')
    os.makedirs(out_dir, exist_ok=True)
    bank = json.load(open(os.path.join(ROOT, 'assets/content/speaking_bank.json'), encoding='utf-8'))
    a = os.path.join(out_dir, 'Speaking_Sample_Answers_Review.pdf')
    b = os.path.join(out_dir, 'Speaking_Vocabulary_Review.pdf')
    answers_pdf(bank, a)
    vocab_pdf(bank, b)
    for p in (a, b):
        print(p, os.path.getsize(p) // 1024, 'KB')
