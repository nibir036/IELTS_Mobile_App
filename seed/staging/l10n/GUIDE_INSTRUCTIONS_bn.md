# Translating a study guide into Bangla (IELTS AI by nextED)

Read first: /home/claude/app/seed/staging/l10n/STYLE_bn.md — follow it (Bangla explanation, English examples,
আপনি voice, IELTS/English terms kept in English with hyphenated Bangla endings: keyword-এর, option-গুলো,
answer-টা; । as full stop; Bangla digits only in your own counts).

**Use EASY Bangla.** The reader is a Bangladeshi student, often weak in English. Prefer everyday spoken-standard
words (সহজ, ছোট বাক্য) over bookish/Sanskrit-heavy ones: "শুরুতেই", not "প্রারম্ভে"; "ভুল", not "ত্রুটি"
when both fit; "দরকার", not "প্রয়োজনীয়তা". Re-say the idea naturally; never word-for-word.

Input:  /home/claude/app/seed/staging/<guide>/en/<file>.json   (list of chapters {id, title, group, blocks})
Output: /home/claude/app/seed/staging/<guide>/bn/<file>.json   SAME chapters, SAME ids, SAME block list (same
count, same kinds, same list lengths, same table columns/rows, same exercise item count). Write with a Python
script (json.dump, ensure_ascii=False, indent=1).

Per block:
- chapter "title", "group": translate; keep the leading number ("3.", "(1/2)"); keep "Practice ·" as "Practice ·".
- ["p", t], ["h", t], ["h2", t], ["tip", t], ["note", t]: translate t. Keep **bold** markers around the matching
  words. Quoted English (examples, transcript lines, question wording, answers like "Hall D") stays English.
- ["ul"/"ol", items]: translate each item (same count).
- ["table", headers, rows, caption?]: translate explanatory words; keep English examples/answers as they are.
- ["exercise", {...}]: keep "kind" and every item's "prompt", "answer", "accepted" EXACTLY (byte-identical — the
  drills and their answers stay English). Translate "title" (keep a leading "Drill 2.1 (Level 1):" style prefix
  as "Drill 2.1 (Level 1):") and "instructions". Keep "reason" as "" if empty.
- Every sentence of explanation must be translated; add nothing, drop nothing.
- If the guide folder has callouts_bn.json, it holds the author's own short Bangla for some tutor tips: use it for
  terms and tone, but translate the FULL English tip.

Validate: python3 /home/claude/app/tool/check_writing_guide.py --guide <guide> <file>.json  (0 errors needed;
warnings about Bangla in en can be ignored). Do not modify other files.
