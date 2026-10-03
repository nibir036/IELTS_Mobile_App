"""IELTS Reading Complete Guide (Bangla explanation, English examples) as a PDF.

usage: python3 tool/build_reading_guide.py [out.pdf]

Sources: seed/staging/l10n/reading/guide_bn.json (hand-written chapters), the English reading bank
(type lessons, exhibits, worked-example questions) and assets/content/l10n/bn/reading.json (Bangla type
lessons, mini-lessons and explanations). Rendered with Chromium so Bangla is shaped correctly.
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GUIDE = ROOT / 'seed' / 'staging' / 'l10n' / 'reading' / 'guide_bn.json'
BANK = ROOT / 'assets' / 'content' / 'reading_bank.json'
BN = ROOT / 'assets' / 'content' / 'l10n' / 'bn' / 'reading.json'
OUT = ROOT / 'seed' / 'reports' / 'IELTS_Reading_Complete_Guide_Bangla.pdf'
BRAND = 'IELTS AI by nextED'

BN_DIGITS = str.maketrans('0123456789', '০১২৩৪৫৬৭৮৯')
NUMBERED = re.compile(r'^(\d+)\.\s+(.*)$')
GAP = re.compile(r'\((\d+)\)\s*_+')


def bn_num(n):
    return str(n).translate(BN_DIGITS)


def esc(s):
    return html.escape(s or '')


def rich(s):
    """Escape, keep line breaks, and set "English quotes" apart."""
    out = esc(s).replace('\n', '<br>')
    return re.sub(r'&quot;([^&]{1,200}?)&quot;', r'<span class="q">“\1”</span>', out)


def gaps(s):
    return GAP.sub(lambda m: f'<b>({m.group(1)})</b> ______', esc(s))


# ── generic blocks (guide_bn.json) ─────────────────────────────────────────

def block(b):
    kind = b[0]
    if kind == 'p':
        return f'<p>{rich(b[1])}</p>'
    if kind == 'h':
        return f'<h3>{esc(b[1])}</h3>'
    if kind in ('ul', 'ol'):
        return f'<{kind}>' + ''.join(f'<li>{rich(x)}</li>' for x in b[1]) + f'</{kind}>'
    if kind == 'tip':
        return f'<div class="tip"><div class="lbl">Tip</div>{rich(b[1])}</div>'
    if kind == 'ex':
        return f'<div class="ex">{esc(b[1]).replace(chr(10), "<br>")}</div>'
    if kind == 'table':
        head = ''.join(f'<th>{esc(c)}</th>' for c in b[1])
        rows = ''.join('<tr>' + ''.join(f'<td>{rich(c)}</td>' for c in r) + '</tr>' for r in b[2])
        return f'<table><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table>'
    raise ValueError(kind)


# ── English exhibits of the type lessons ──────────────────────────────────

def exhibit(e):
    k = e['kind']
    if k == 'table':
        head = ''.join(f'<th>{esc(c)}</th>' for c in e['columns'])
        rows = ''.join('<tr>' + ''.join(f'<td>{gaps(c)}</td>' for c in r) + '</tr>' for r in e['rows'])
        return f'<table class="en"><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table>'
    if k == 'notes':
        lines = ''.join(f'<div class="nl l{l.get("level", 0)}">{gaps(l["text"])}</div>' for l in e['lines'])
        return f'<div class="paper"><div class="pt">{esc(e.get("title"))}</div>{lines}</div>'
    if k == 'flowchart':
        steps = '<div class="arrow">↓</div>'.join(f'<div class="step">{gaps(s)}</div>' for s in e['steps'])
        return f'<div class="paper"><div class="pt">{esc(e.get("title"))}</div>{steps}</div>'
    if k == 'diagram':
        side = {'left': [], 'right': []}
        for l in sorted(e['labels'], key=lambda x: x.get('order', 0)):
            side[l.get('side', 'left')].append(f'<div class="dl">{gaps(l["text"])}</div>')
        return (f'<div class="paper diagram"><div class="dcol">{"".join(side["left"])}</div>'
                f'<div class="dbox">{esc(e.get("caption"))}</div>'
                f'<div class="dcol">{"".join(side["right"])}</div></div>')
    raise ValueError(k)


def lines_of(text):
    return [l.strip() for l in (text or '').split('\n') if l.strip()]


def para_html(lines):
    out, ol = [], []
    for l in lines:
        m = NUMBERED.match(l)
        if m:
            ol.append(f'<li>{rich(m.group(2))}</li>')
            continue
        if ol:
            out.append('<ol>' + ''.join(ol) + '</ol>')
            ol = []
        out.append(f'<p>{rich(l)}</p>')
    if ol:
        out.append('<ol>' + ''.join(ol) + '</ol>')
    return out


def lesson_section(en, tr, i):
    text = tr.get('text') or ''
    heading = tr.get('heading') or en['heading']
    exhibits = en.get('exhibits', [])
    layout = en.get('layout', [])
    body = []
    if not (en.get('text') or '').strip():
        body += [exhibit(x) for x in exhibits]
        body += para_html(lines_of(text))
    elif layout and len(lines_of(text)) == len(lines_of(en['text'])):
        ls = lines_of(text)
        for l in layout:
            if 'paragraph' in l:
                body += para_html([ls[l['paragraph']]])
            elif 'exhibit' in l:
                body.append(exhibit(exhibits[l['exhibit']]))
    else:
        body += para_html(lines_of(text or en['text']))
        body += [exhibit(x) for x in exhibits]
    # merge adjacent <ol> produced line by line
    joined = ''.join(body).replace('</ol><ol>', '')
    return f'<div class="sec"><h3><span class="sn">{bn_num(i + 1)}</span>{esc(heading)}</h3>{joined}</div>'


# ── worked examples from the bank ─────────────────────────────────────────

def question_html(g, q, lists=True):
    n = q['number']
    t = g['type']
    parts = []
    if t == 'heading':
        hs = '' if not lists else ''.join(f'<div><b>{esc(h["key"])}</b>&nbsp; {esc(h["text"])}</div>' for h in g['headings'])
        if hs:
            parts.append(f'<div class="opts"><div class="pt">{esc(g.get("headingsTitle"))}</div>{hs}</div>')
        parts.append(f'<div class="qq"><b>{n}</b>&nbsp; {esc(q["text"])}</div>')
    elif t == 'summary':
        sent = next((s for s in re.split(r'(?<=[.!?])\s+', g.get('text', '')) if f'({n})' in s), '')
        parts.append(f'<div class="qq">… {gaps(sent)} …</div>')
    elif t == 'notes':
        line = next((l['text'] for l in g['lines'] if f'({n})' in l['text']), '')
        parts.append(f'<div class="qq">{gaps(line)}</div>')
    elif t == 'table':
        row = next((r for r in g['rows'] if any(f'({n})' in c for c in r)), [])
        cells = ''.join(f'<td>{gaps(c)}</td>' for c in row)
        head = ''.join(f'<th>{esc(c)}</th>' for c in g['columns'])
        parts.append(f'<table class="en"><thead><tr>{head}</tr></thead><tbody><tr>{cells}</tr></tbody></table>')
    elif t == 'flowchart':
        step = next((s for s in g['steps'] if f'({n})' in s), '')
        parts.append(f'<div class="qq">{gaps(step)}</div>')
    elif t == 'diagram':
        lab = next((l['text'] for l in g['labels'] if f'({n})' in l['text']), '')
        parts.append(f'<div class="qq">{esc(g.get("caption"))}: {gaps(lab)}</div>')
    else:
        parts.append(f'<div class="qq"><b>{n}</b>&nbsp; {gaps(q.get("text", ""))}</div>')
    opts = q.get('options') or (g.get('options') if t in ('matching_features', 'summary') else None)
    if t == 'sentence_endings':
        opts = g.get('endings')
    shared = not q.get('options')
    if opts and isinstance(opts[0], dict) and (lists or not shared):
        o = ''.join(f'<div><b>{esc(x["key"])}</b>&nbsp; {esc(x["text"])}</div>' for x in opts)
        title = g.get('optionsTitle') or g.get('endingsTitle') or ''
        parts.append(f'<div class="opts">{f"<div class=pt>{esc(title)}</div>" if title else ""}{o}</div>')
    return ''.join(parts)


def worked_example(passage, tr, count=2):
    g = passage['groups'][0]
    qs = g['questions']
    pick = [qs[0]] + ([qs[2]] if len(qs) > 2 else qs[1:2])
    ex = tr.get('explanations', {})
    out = [f'<div class="we"><div class="weh">Worked example · Set {passage["bankSet"]} ({esc(passage["difficulty"])}) · '
           f'“{esc(passage["title"])}”</div>',
           f'<div class="instr">{esc(g["instruction"]).replace(chr(10), "<br>")}</div>']
    for k, q in enumerate(pick[:count]):
        ans = q.get('answerDisplay') or q['answer']
        out.append('<div class="wq">' + question_html(g, q, lists=k == 0) +
                   f'<div class="ans">Answer: <b>{esc(ans)}</b> &nbsp;·&nbsp; Paragraph {esc(q.get("evidenceParagraph"))}</div>'
                   f'<div class="evi">Passage-এ: <span class="q">“{esc(q["evidence"])}”</span></div>'
                   f'<div class="why"><b>কেন:</b> {rich(ex.get(str(q["number"])) or q["explanation"])}</div></div>')
    lesson = tr.get('lesson') or {}
    if lesson.get('text'):
        exm = f'<div class="ex">{rich(lesson["example"])}</div>' if lesson.get('example') else ''
        out.append(f'<div class="mini"><div class="lbl">এই set-এর mini-lesson · {esc(lesson.get("title"))}</div>'
                   f'<p>{rich(lesson["text"])}</p>{exm}</div>')
    out.append('</div>')
    return ''.join(out)


# ── document ──────────────────────────────────────────────────────────────

CSS = """
* { box-sizing: border-box; }
body { font-family: 'Liberation Sans', 'FreeSans', 'DejaVu Sans', sans-serif; font-size: 10.6pt; line-height: 1.62;
  color: #151515; margin: 0; }
h1, h2, h3 { font-weight: 700; line-height: 1.3; }
.cover { height: 257mm; display: flex; flex-direction: column; justify-content: center; padding: 0 8mm;
  background: linear-gradient(135deg, #EEEFFD 0%, #F9D6E2 100%); border-radius: 8mm; page-break-after: always; }
.cover .brand { font-size: 13pt; letter-spacing: .5px; color: #625C66; }
.cover h1 { font-size: 34pt; margin: 6mm 0 3mm; }
.cover .sub { font-size: 14pt; color: #333; }
.cover .foot { margin-top: 18mm; font-size: 10.5pt; color: #625C66; }
.toc { page-break-after: always; }
.toc h2 { font-size: 20pt; }
.toc ol { padding-left: 0; list-style: none; }
.toc li { padding: 1.6mm 0; border-bottom: 1px dotted #ccc; font-size: 11pt; }
.toc .en { color: #625C66; font-size: 9.5pt; }
.part { page-break-before: always; padding: 10mm 8mm; background: #151515; color: #fff; border-radius: 6mm;
  margin-bottom: 6mm; }
.part .k { color: #F7C6D6; font-size: 11pt; }
.part h2 { font-size: 22pt; margin: 2mm 0 0; }
.chap { page-break-before: always; }
.chap-h { border-left: 3mm solid #F7C6D6; padding: 1mm 0 1mm 4mm; margin-bottom: 5mm; }
.chap-h .k { color: #625C66; font-size: 10pt; }
.chap-h h2 { font-size: 19pt; margin: 1mm 0 0; }
.chap-h .en { color: #625C66; font-size: 10.5pt; }
h3 { font-size: 12.5pt; margin: 5mm 0 2mm; }
.sec { break-inside: auto; }
.sec h3 .sn { display: inline-block; width: 7mm; height: 7mm; line-height: 7mm; text-align: center; border-radius: 2mm;
  background: #DCDDFA; margin-right: 2.5mm; font-size: 10pt; }
p { margin: 0 0 2.5mm; }
ul, ol { margin: 0 0 3mm; padding-left: 6mm; }
li { margin-bottom: 1.2mm; }
.q { font-style: italic; }
table { width: 100%; border-collapse: collapse; margin: 2mm 0 4mm; font-size: 9.8pt; break-inside: avoid; }
th { background: #DCDDFA; text-align: left; padding: 1.8mm 2.5mm; }
td { border-bottom: 1px solid #e3e3e3; padding: 1.6mm 2.5mm; vertical-align: top; }
table.en td, table.en th { font-size: 9.5pt; }
.tip { background: #FDF0F4; border-radius: 3mm; padding: 3mm 4mm; margin: 3mm 0 4mm; break-inside: avoid; }
.lbl { font-weight: 700; font-size: 9.5pt; color: #9c3a5d; margin-bottom: 1mm; }
.ex, .paper { background: #F5F5F7; border-radius: 2.5mm; padding: 2.5mm 4mm; margin: 2mm 0 4mm; font-size: 9.8pt;
  break-inside: avoid; }
.pt { font-weight: 700; margin-bottom: 1mm; }
.nl.l1 { padding-left: 5mm; }
.step { background: #fff; border: 1px solid #ddd; border-radius: 2mm; padding: 1.2mm 3mm; }
.arrow { text-align: center; color: #999; line-height: 1.2; }
.diagram { display: flex; gap: 3mm; align-items: center; }
.dcol { flex: 1; } .dl { padding: 1mm 0; }
.dbox { width: 32mm; height: 26mm; border: 1.5px dashed #aaa; border-radius: 3mm; display: flex; align-items: center;
  justify-content: center; text-align: center; font-size: 8.5pt; color: #777; padding: 2mm; }
.we { border: 1.5px solid #DCDDFA; border-radius: 4mm; padding: 4mm; margin-top: 5mm; }
.weh { font-weight: 700; font-size: 11pt; margin-bottom: 2mm; }
.instr { font-size: 9.3pt; color: #625C66; margin-bottom: 3mm; }
.wq { border-top: 1px solid #eee; padding-top: 3mm; margin-top: 3mm; break-inside: avoid; }
.qq { margin-bottom: 1.5mm; }
.opts { font-size: 9.5pt; background: #F5F5F7; border-radius: 2mm; padding: 2mm 3mm; margin-bottom: 2mm; }
.ans { margin: 1.5mm 0; }
.evi { font-size: 9.8pt; color: #333; margin-bottom: 1.5mm; }
.why { background: #EEEFFD; border-radius: 2mm; padding: 2mm 3mm; }
.mini { margin-top: 4mm; background: #FFF8E8; border-radius: 3mm; padding: 3mm 4mm; break-inside: avoid; }
.mini .lbl { color: #8a5a00; }
"""


def chapter(no, title, blocks_html, en=None):
    k = f'অধ্যায় {bn_num(no)}'
    sub = f'<div class="en">{esc(en)}</div>' if en else ''
    return (f'<section class="chap"><div class="chap-h"><div class="k">{k}</div><h2>{esc(title)}</h2>{sub}</div>'
            f'{blocks_html}</section>')


def build_html():
    guide = json.loads(GUIDE.read_text(encoding='utf-8'))
    bank = json.loads(BANK.read_text(encoding='utf-8'))
    bn = json.loads(BN.read_text(encoding='utf-8'))
    toc, body = [], []
    no = 0

    def add(title, html_, en=None):
        nonlocal no
        no += 1
        toc.append(f'<li>{bn_num(no)}. {esc(title)}{f" <span class=en>· {esc(en)}</span>" if en else ""}</li>')
        body.append(chapter(no, title, html_, en))

    body.append('<div class="part"><div class="k">প্রথম ভাগ</div><h2>Test, band আর মূল skill</h2></div>')
    intro = ''.join(block(b) for b in guide['intro'])
    body.append(f'<section><h3>এই guide কীভাবে ব্যবহার করবেন</h3>{intro}</section>')
    for c in guide['chapters']:
        add(c['title'], ''.join(block(b) for b in c['blocks']))

    body.append('<div class="part"><div class="k">দ্বিতীয় ভাগ</div><h2>১৪টি question type</h2></div>')
    body.append(''.join(block(b) for b in guide['typesIntro']))
    first = {}
    for p in bank['passages']:
        if p['difficulty'] == 'easy':
            first.setdefault(p['questionType'], p)
    for lesson in bank['lessons']:
        tr = bn['typeLessons'].get(lesson['id'], {})
        secs = tr.get('sections') or []
        html_ = ''.join(lesson_section(s, secs[i] if i < len(secs) else {}, i)
                        for i, s in enumerate(lesson['sections']))
        qtype = lesson['id'].removeprefix('rtl_')
        p = first.get(qtype)
        if p:
            html_ += worked_example(p, bn['passages'].get(p['id'], {}))
        add(tr.get('title') or lesson['title'], html_, lesson.get('name'))

    body.append('<div class="part"><div class="k">তৃতীয় ভাগ</div><h2>ভুল, practice plan আর পরীক্ষার দিন</h2></div>')
    for c in guide['closing']:
        add(c['title'], ''.join(block(b) for b in c['blocks']))

    cover = (f'<div class="cover"><div class="brand">{BRAND}</div><h1>{esc(guide["title"])}</h1>'
             f'<div class="sub">{esc(guide["subtitle"])}</div>'
             f'<div class="foot">ব্যাখ্যা বাংলায় · উদাহরণ ইংরেজিতে<br>{BRAND}</div></div>')
    toc_html = f'<div class="toc"><h2>সূচিপত্র</h2><ol>{"".join(toc)}</ol></div>'
    return (f'<!doctype html><html lang="bn"><head><meta charset="utf-8"><title>{esc(guide["title"])}</title>'
            f'<style>{CSS}</style></head><body>{cover}{toc_html}{"".join(body)}</body></html>')


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else OUT
    out.parent.mkdir(parents=True, exist_ok=True)
    doc = build_html()
    html_path = out.with_suffix('.html')
    html_path.write_text(doc, encoding='utf-8')
    from playwright.sync_api import sync_playwright
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page()
        page.goto(html_path.as_uri())
        page.pdf(path=str(out), format='A4', print_background=True, display_header_footer=True,
                 header_template='<div></div>',
                 footer_template=f'<div style="width:100%;font-size:8px;color:#888;padding:0 16mm;display:flex;'
                                 f'justify-content:space-between"><span>{BRAND} · IELTS Reading Guide</span>'
                                 f'<span class="pageNumber"></span></div>',
                 margin={'top': '16mm', 'bottom': '18mm', 'left': '16mm', 'right': '16mm'})
        browser.close()
    html_path.unlink()
    print(out, out.stat().st_size // 1024, 'KB')


if __name__ == '__main__':
    main()
