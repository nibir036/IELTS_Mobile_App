# Translating app content into Nepali (ne), Arabic (ar) or Indonesian (id)

You translate ONE source file into ONE language. First read the style guide of your language and follow it:
/home/claude/app/seed/staging/l10n/STYLE_<lang>.md . The Bangla (bn) translation of the same file already exists
and passed review: use it as the model for structure, for what stays English and for tone — but translate from
the ENGLISH, not from the Bangla.

Always write the output with a Python script (json.dump(data, f, ensure_ascii=False, indent=1)); build it up in
parts if the file is long (e.g. translate 5 passages or 2 chapters per script run, appending to the output). Never
change ids, keys, order, counts or anything marked "exactly". Touch no other file. When done, run the checker
given below; it must report 0 errors. Reply with: file, counts, checker result line, and up to 3 spots you were
unsure of.

## A. Study guides (writing_guide, listening_guide, speaking_guide, grammar_guide, vocab_guide)

Input  /home/claude/app/seed/staging/<guide>/en/<file>.json   (list of chapters {id, title, group?, blocks})
Model  /home/claude/app/seed/staging/<guide>/bn/<file>.json
Output /home/claude/app/seed/staging/<guide>/<lang>/<file>.json — SAME chapters, SAME ids, SAME block list (same
count, same kinds, same list lengths, same table columns/rows, same box kind and item count, same exercise items).

Per block:
- chapter "title", "group": translate; keep a leading number ("3.", "(1/2)"), "Module 1 ·" (translated word, same
  number), and "Practice ·" as "Practice ·".
- ["p", t], ["h", t], ["h2", t], ["tip", t], ["note", t]: translate t. Keep **bold** markers. Quoted English
  (examples, transcript lines, question wording, answers like "Hall D") stays English. If the Bangla model kept a
  block entirely in English (an English example paragraph), keep it English too.
- ["ul"/"ol", items]: translate each item (same count) — except lists the Bangla model copied unchanged (English
  word lists): copy those too, but replace a Bangla gloss in brackets by a gloss in your language.
- ["table", headers, rows, caption?]: translate headers, caption and explaining words; keep English example
  words / sentences / grammatical forms exactly. Verb tables the Bangla model copied unchanged: copy the rows.
- ["box", kind, title, body, items]: keep kind; translate title and body; in items keep the ✗ / ✓ English example
  lines exactly, translate only explanation/label text.
- ["pair", wrong, right, why]: keep wrong and right EXACTLY; translate why.
- ["model", text] and ["ex", …] and ["img", …]: copy EXACTLY.
- ["exercise", {...}]: keep "kind" and every item's "prompt", "answer", "accepted" EXACTLY (byte-identical).
  Translate "title" after its prefix ("Exercise 1.1 ·", "Drill 2.1 (Level 1):", "Essay 2 ·" stay as they are),
  "instructions", and every non-empty item "reason" (from the ENGLISH reason). Keep "" reasons as "".
- vocab_guide: this is a vocabulary book — every English word, phrase, collocation, idiom, example sentence and
  model answer stays English. Idiom / collocation lines "**expression**: meaning. Example: sentence" → keep
  **expression** and the English example sentence, write the meaning in your language, and translate the word
  "Example:". The "Bangla logic" / "Bangla nuance" boxes: translate the explanation, keep the Bengali-script
  sentences exactly.
- grammar_guide: grammar terms stay English (subject, verb, tense, article …) with your language around them.

Tips file of a guide (writing_guide, listening_guide, speaking_guide only):
Input /home/claude/app/seed/staging/<guide>/tips_en.json  [{id, chip, title, tips:[{title, body}], tryIt}]
Model /home/claude/app/seed/staging/<guide>/tips_bn.json
Output /home/claude/app/seed/staging/<guide>/tips_<lang>.json  [{id, title, tips:[{title, body}], tryIt}] — same
ids, same tip count; translate title, every tip title and body, and tryIt (keep "" if empty).

Checker: python3 /home/claude/app/tool/check_writing_guide.py --guide <guide> --lang <lang> <file>.json
(tips: run it with no file name; it then also checks tips_<lang>.json).

## B. Reading (seed/staging/l10n/reading)

Input  /home/claude/app/seed/staging/l10n/reading/src/<file>.json
Model  /home/claude/app/seed/staging/l10n/reading/bn/<file>.json   (shows the exact output keys)
Output /home/claude/app/seed/staging/l10n/reading/<lang>/<file>.json

- passages_NN.json: list of {id, lesson: {title, text, example?}, explanations: {"<n>": text}} — one entry per
  source passage, one explanation per source question (keys are the question numbers as strings). Translate the
  lesson title, text and example (inside the example keep the English Passage/Question/option text exactly; translate
  only the explaining words such as "Correct idea:" / "A tempting wrong option would be…"). Translate each
  question's ENGLISH "explanation"; the passage quotes, options and answers inside it stay English.
- library_passages.json: [{id, explanations: {"<n>": text}}] from each question's "explanation".
- type_lessons.json: [{id, title, sections: [{heading, text}]}] (same section count).
- skill_lessons.json: [{id, title, keyIdea, uses: [{label, value}]}] (same ** markers in keyIdea).
- tips.json: [{id, chip, title, tips: [{title, body}], tryIt}] — "chip" stays as the English chip.
- guide.json: [{id, title, blocks}] — blocks as in part A.

Checker: python3 /home/claude/app/tool/check_l10n.py <lang> <NN>   (for passages_NN.json; for the other files run
python3 /home/claude/app/tool/check_l10n.py <lang> extra  and/or  lessons). It must report 0 errors for your file
(errors about OTHER files not translated yet are expected — ignore those).

## C. Resources word meanings (seed/staging/l10n/resources)

Input  /home/claude/app/seed/staging/l10n/resources/src/batch_NN.json — list of {id, word, pos, en}
Model  /home/claude/app/seed/staging/l10n/resources/bn/batch_NN.json
Output /home/claude/app/seed/staging/l10n/resources/<lang>/batch_NN.json — ONE JSON object {id: "meaning"} with
every id of the batch (json.dump(..., ensure_ascii=False, indent=0)).

- Translate the ENGLISH MEANING (en) into short, EASY, everyday words of your language (usually 2–10 words), the
  sense the WORD has (use word + pos). Idioms / phrasal verbs: their real meaning, never word-by-word.
- Keep a common English term when students normally use it (internet, app, online, e-mail, CO2); keep English
  words in quotes as they are. No full stop at the end.
- Indonesian: the meaning must be Indonesian, never the English definition copied.

Check (Python) before finishing: the output is a dict, its key set equals the input ids, every value is a non-empty
string in your language (ne: Devanagari letters, ar: Arabic letters, id: not identical to the English "en").
