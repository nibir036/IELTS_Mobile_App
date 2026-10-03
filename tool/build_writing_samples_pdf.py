#!/usr/bin/env python3
"""Review PDFs of the writing sample answers (Band 6 / 7 / 8 for every question).

Input:  assets/content/writing_bank.json (built by tool/import_writing_bank.py)
Output: <out_dir>/Writing_Task1_Sample_Answers_Review.pdf
        <out_dir>/Writing_Task2_Sample_Answers_Review.pdf

Usage: python tool/build_writing_samples_pdf.py [out_dir]   (default: seed/reports)
Needs reportlab + Pillow; uses the DejaVu Sans fonts.
"""
import html
import io
import json
import os
import sys

from PIL import Image as PILImage
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (Flowable, Image, KeepTogether, PageBreak, Paragraph, SimpleDocTemplate,
                                Spacer, Table, TableStyle)

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
BAND_COL = {6: colors.HexColor('#C9772B'), 7: colors.HexColor('#2F6FB0'), 8: colors.HexColor('#2E7D4F')}

S = {
    'title': ParagraphStyle('title', fontName='DV-B', fontSize=24, leading=30, textColor=INK),
    'sub': ParagraphStyle('sub', fontName='DV', fontSize=12, leading=17, textColor=MUTED),
    'h1': ParagraphStyle('h1', fontName='DV-B', fontSize=15, leading=20, textColor=INK, spaceAfter=2),
    'h2': ParagraphStyle('h2', fontName='DV-B', fontSize=11.5, leading=15, textColor=INK, spaceBefore=6),
    'meta': ParagraphStyle('meta', fontName='DV', fontSize=9, leading=12, textColor=MUTED),
    'body': ParagraphStyle('body', fontName='DV', fontSize=10, leading=15, textColor=INK, alignment=TA_LEFT,
                           spaceAfter=6),
    'q': ParagraphStyle('q', fontName='DV', fontSize=10.5, leading=15, textColor=INK),
    'why': ParagraphStyle('why', fontName='DV-I', fontSize=9, leading=13, textColor=MUTED, spaceAfter=6),
    'small': ParagraphStyle('small', fontName='DV', fontSize=8.5, leading=12, textColor=MUTED),
    'bullet': ParagraphStyle('bullet', fontName='DV', fontSize=10, leading=15, textColor=INK, leftIndent=12,
                             bulletIndent=0, spaceAfter=3),
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


class BandHeader(Flowable):
    def __init__(self, band, words, width):
        super().__init__()
        self.band, self.words, self.width, self.height = band, words, width, 22

    def draw(self):
        c = self.canv
        col = BAND_COL.get(self.band, INK)
        c.setFillColor(col)
        c.roundRect(0, 3, 62, 17, 8, stroke=0, fill=1)
        c.setFillColor(colors.white)
        c.setFont('DV-B', 9.5)
        c.drawCentredString(31, 8, f'Band {self.band}')
        c.setFillColor(MUTED)
        c.setFont('DV', 9)
        c.drawString(72, 8, f'{self.words} words')
        c.setStrokeColor(LINE)
        c.line(140, 11, self.width, 11)


def footer(title):
    def draw(canvas, doc):
        canvas.saveState()
        canvas.setFont('DV', 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(18 * mm, 10 * mm, f'IELTS AI by nextED · {title} · for review')
        canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f'Page {doc.page}')
        canvas.restoreState()
    return draw


def image_flowable(path, max_w, max_h):
    im = PILImage.open(path).convert('RGB')
    if im.width > 1300:
        im = im.resize((1300, round(im.height * 1300 / im.width)), PILImage.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=85, optimize=True)
    buf.seek(0)
    w, h = im.size
    scale = min(max_w / w, max_h / h)
    return Image(buf, width=w * scale, height=h * scale)


def review_box(width):
    t = Table([[Paragraph('☐ Approved &nbsp;&nbsp; ☐ Needs changes &nbsp;&nbsp; Notes:', S['small']), '']],
              colWidths=[width * 0.55, width * 0.45], rowHeights=[20])
    t.setStyle(TableStyle([('BOX', (0, 0), (-1, -1), 0.5, LINE), ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
                           ('LEFTPADDING', (0, 0), (-1, -1), 6)]))
    return t


def intro(task, bank, n):
    width = A4[0] - 36 * mm
    out = [Spacer(1, 30 * mm),
           Paragraph(f'Writing Task {task} — Sample Answers', S['title']), Spacer(1, 4),
           Paragraph(f'{n} questions × Band 6, Band 7 and Band 8 = {n * 3} answers · for review before seeding',
                     S['sub']),
           Spacer(1, 10 * mm)]
    meta = bank['meta'][f'task{task}']
    out.append(Paragraph('Source', S['h2']))
    out.append(Paragraph(esc(f"{meta.get('title', '')} ({meta.get('source', '')})"), S['body']))
    out.append(Paragraph('How each band was written', S['h2']))
    if task == 1:
        pts = [
            ('Band 6', 'Overview present but basic or placed late; key features covered, some detail mechanical; '
                       'figures accurate (may approximate); repetitive linking; 4–7 small learner errors that '
                       'never block meaning. 160–190 words.'),
            ('Band 7', 'Clear overview; key features clearly highlighted; logical progression; range of cohesive '
                       'devices; some less common vocabulary; 1–3 minor slips. 170–205 words.'),
            ('Band 8', 'Key features skilfully selected; clear, well-placed overview; figures used selectively '
                       'for comparison; wide, precise vocabulary and structures; rare slips at most. 175–215 words.'),
        ]
    else:
        pts = [
            ('Band 6', 'All parts addressed but some ideas underdeveloped; relevant position that may be slightly '
                       'unclear; paragraphing present; mechanical linking; 4–7 small learner errors. 255–295 words.'),
            ('Band 7', 'Clear position throughout; main ideas extended and supported; clear central topic in each '
                       'paragraph; good range of vocabulary; 1–3 minor slips. 265–315 words.'),
            ('Band 8', 'All parts well developed with relevant, extended support; logical sequencing; wide, '
                       'flexible vocabulary and structures; rare minor errors. 275–335 words.'),
        ]
    for b, t in pts:
        out.append(Paragraph(f'<b>{b}</b> — {esc(t)}', S['bullet'], bulletText='•'))
    out.append(Paragraph('Checks already done', S['h2']))
    checks = ['every question has all three bands; word counts inside the ranges above',
              'the three answers were written separately (not one essay with words swapped)',
              'British spelling; no headings or lists; no invented statistics, studies or real people']
    if task == 1:
        checks.insert(1, 'every figure checked against the question data; figures that are not in the data are '
                         'derived values (differences, totals, multiples) and were re-checked')
    for c in checks:
        out.append(Paragraph(esc(c), S['bullet'], bulletText='•'))
    out.append(Paragraph('What to look for', S['h2']))
    for c in ['Does each answer feel like its band (not too strong for 6, not too weak for 8)?',
              'Band 6 / 7 errors are deliberate — they should be realistic learner errors.',
              'Task 1: are the key features and the overview right for the visual?',
              'Task 2: does each essay answer every part of the question?',
              'Mark ☐ Approved or ☐ Needs changes under each question and add notes.']:
        out.append(Paragraph(esc(c), S['bullet'], bulletText='•'))
    out.append(PageBreak())
    return out


def build(task, items, bank, path):
    width = A4[0] - 36 * mm
    doc = SimpleDocTemplate(path, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm,
                            bottomMargin=18 * mm, title=f'Writing Task {task} — Sample Answers (review)',
                            author='IELTS AI by nextED')
    story = intro(task, bank, len(items))
    section = None
    for it in items:
        if it['typeLabel'] != section:
            section = it['typeLabel']
            story.append(Bookmark(f'sec_{task}_{it["type"]}', section, 0))
        head = f"Task {task} · {it['typeLabel']} · Question {it['number']:02d}"
        story.append(Bookmark(it['id'], f"Q{it['number']:02d} · {it.get('title', '')}", 1))
        story.append(Paragraph(esc(head), S['meta']))
        story.append(Paragraph(esc(it.get('title', '')), S['h1']))
        if task == 2:
            story.append(Paragraph(esc(f"Topic: {it['topic']} · Difficulty: {it['difficulty']} · id {it['id']}"),
                                   S['meta']))
            q = it['question']
        else:
            story.append(Paragraph(esc(f"id {it['id']}"), S['meta']))
            q = it['statement']
        box = Table([[Paragraph(esc(q), S['q'])]], colWidths=[width])
        box.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), SOFT), ('LEFTPADDING', (0, 0), (-1, -1), 10),
                                 ('RIGHTPADDING', (0, 0), (-1, -1), 10), ('TOPPADDING', (0, 0), (-1, -1), 8),
                                 ('BOTTOMPADDING', (0, 0), (-1, -1), 8)]))
        story += [Spacer(1, 6), box, Spacer(1, 6)]
        if task == 1:
            story.append(image_flowable(os.path.join(ROOT, it['image']), width, 115 * mm))
            story.append(Spacer(1, 4))
        for s in it.get('samples', []):
            paras = [p.strip() for p in s['text'].split('\n\n') if p.strip()]
            block = [Spacer(1, 4), BandHeader(s['band'], s['words'], width), Paragraph(esc(s['why']), S['why'])]
            story.append(KeepTogether(block + [Paragraph(esc(paras[0]), S['body'])]))
            story += [Paragraph(esc(p), S['body']) for p in paras[1:]]
        story += [Spacer(1, 6), review_box(width), PageBreak()]
    doc.build(story, onFirstPage=footer(f'Writing Task {task} sample answers'),
              onLaterPages=footer(f'Writing Task {task} sample answers'))


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'seed', 'reports')
    os.makedirs(out_dir, exist_ok=True)
    bank = json.load(open(os.path.join(ROOT, 'assets', 'content', 'writing_bank.json'), encoding='utf-8'))
    for task in (1, 2):
        path = os.path.join(out_dir, f'Writing_Task{task}_Sample_Answers_Review.pdf')
        build(task, bank[f'task{task}'], bank, path)
        print(path, os.path.getsize(path) // 1024, 'KB')


if __name__ == '__main__':
    main()
