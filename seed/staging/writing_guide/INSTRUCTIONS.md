# Converting sir's Writing guide into in-app chapters

Source: /home/claude/app/seed/sources/guides/IELTS_Writing_Complete_Book_Bangla.pdf (128 pages).
Per-page extracted text (cleaned of most glyph splits): /home/claude/app/seed/staging/writing_guide/pages/pNNN.txt
Chart images already extracted: /home/claude/app/assets/writing/guide/pNNN_K.png (K = order on that page).

The extracted text reads tables COLUMN BY COLUMN and loses box/heading formatting, so you MUST look at every
page image too (Read tool on the PDF with `pages: "N-M"`, max 20 pages per call) and rebuild the structure from
what you see. Where the text still has a broken Bangla word (a stray space inside a word, e.g. "ভু ল", "পড় তে"),
write it correctly as printed on the page.

## Output: two JSON files per assignment (UTF-8, ensure_ascii=False, indent=1)

bn/<file>.json — the Bangla chapters, sir's wording kept as faithfully as possible (do NOT rewrite, summarise,
shorten or add; only fix extraction errors). Every sentence of the pages must end up somewhere.
en/<file>.json — a faithful English translation of the same chapters with EXACTLY the same list of chapters, the
same ids and the same block list (same count, same block kinds, same list lengths, same table rows/columns).
English text that is already English in the Bangla version (examples, task prompts, model answers, English
columns) stays identical. Translate only the Bangla. Keep IELTS terms normal English.

Format of each file: a JSON array of chapters:
  [{"id": "<id>", "title": "<chapter title>", "blocks": [ ...blocks... ]}]

Split your page range into chapters at the book's major headings so each chapter is roughly 3–8 printed pages
(a phone reader scrolls one chapter). Use the ids you are given as a prefix: e.g. t1_rules, t1_line_intro ...

Blocks (JSON arrays):
  ["h", "text"]                 section heading (large coloured heading in the book)
  ["h2", "text"]                sub-heading (smaller heading, e.g. "পদ্ধতি ১: ...")
  ["p", "text"]                 paragraph (plain prose; join the wrapped lines into one paragraph)
  ["ul", ["item", ...]]         bullet list  (• or ✓ items)
  ["ol", ["item", ...]]         numbered list
  ["tip", "text"]               a "Tip:" line/box — drop the leading "Tip:" word
  ["note", "text"]              a highlighted rule/template/frame box (cream/yellow boxes, "সোনালি নিয়ম", sentence frames);
                                use \n for line breaks inside; **bold** allowed for the bold labels (e.g. **Sentence 1:**)
  ["ex", "text"]                grey box: an English task prompt / example sentence(s) / wrong→right pairs; \n line breaks allowed
  ["model", "text"]             green box: a model paragraph / model answer (English), \n\n between paragraphs
  ["table", ["col", ...], [["cell", ...], ...]]   a table: header row + rows (every row same length as header)
  ["img", "assets/writing/guide/pNNN_K.png", "caption"]   a chart image at the place it appears; caption = the
                                chart title you see on the image (English), or "" if none

Use ✗ / ✓ characters where the book uses them. Keep Bangla digits where the book uses them.
Skip page furniture only: running headers "IELTS Academic Writing সম্পূর্ণ গাইড", page numbers, "অধ্যায় N" banners
(the chapter title replaces them).

When done, validate with:  python3 /home/claude/app/tool/check_writing_guide.py <file>
(it checks JSON shape, bn/en structure match, image paths). Fix everything it reports. Then reply with a short
summary: chapter ids + titles, number of blocks, and anything you were unsure about (e.g. unreadable text).
Do not modify any files other than your two output files.
