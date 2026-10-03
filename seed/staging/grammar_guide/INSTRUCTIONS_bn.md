# Translating the Grammar course into Bangla (IELTS AI by nextED)

Read first: /home/claude/app/seed/staging/l10n/STYLE_bn.md — follow it exactly (Bangla explanation, English examples,
আপনি voice, English grammar/IELTS terms kept in English with hyphenated Bangla endings: subject-এর, verb-টা,
article-গুলো; । as full stop; Bangla digits only in your own counts).

Input:  /home/claude/app/seed/staging/grammar_guide/en/<file>.json   (list of chapters {id, title, group, blocks})
Output: /home/claude/app/seed/staging/grammar_guide/bn/<file>.json   SAME chapters, SAME ids, SAME block list
(same count, same kinds, same list lengths, same table columns/rows, same box kind and item count, same exercise
item count). Write with a Python script (json.dump, ensure_ascii=False, indent=1).

Reference: the original source /home/claude/app/seed/sources/grammar/all-chapters.json has, for some blocks, a short
Bangla summary in a "bn" field, and for exercise items a "bn_note". Use them as guidance for terms and tone, but
your Bangla must translate the FULL English text (the "bn" fields are only summaries).

Per block:
- "title" (chapter), "group": translate. Keep the leading chapter number ("1.", "(1/2)") and keep "Module 1 ·"
  as "মডিউল ১ ·". Keep "Practice ·" as "Practice ·".
- ["p", t], ["h", t], ["h2", t], ["tip", t], ["note", t]: translate t. Keep section numbers ("1.2", "Case 3 ·").
- ["ul"/"ol", items]: translate each item.
- ["table", headers, rows, caption?]: translate explanatory words; keep English example words/sentences and
  grammatical forms (e.g. "verb + s / es", "The student works hard.") exactly as they are.
- ["box", kind, title, body, items]: keep kind; translate title and body; in items keep the ✗ / ✓ English example
  lines exactly and translate only the label line / the "Task 1:" style labels' explanation. Keep "Skills:" line
  translated as "Skills:" → "যে skill-এ কাজে লাগে:" followed by the same skill names.
- ["pair", incorrect, correct, why]: keep incorrect and correct EXACTLY; translate why (quoted English words stay).
- ["exercise", {...}]: keep "kind", every item's "prompt", "answer", "accepted" EXACTLY (byte-identical). Translate
  "title" after the "Exercise N.N ·" prefix (keep that prefix), "instructions", and each item's "reason" (into
  Bangla; you may fold in the source bn_note's idea). If a reason is empty keep "".
- Anything quoted or given as an English example stays English inside the Bangla sentence.
- Every sentence of English explanation must be translated; add nothing, drop nothing.

Validate: python3 /home/claude/app/tool/check_writing_guide.py --guide grammar_guide <file>.json  (0 errors needed;
warnings about Bangla in en can be ignored — the English course itself quotes Bangla examples). Then reply with a
short summary and any doubtful spots. Do not modify any other files.
