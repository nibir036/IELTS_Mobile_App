# Vocabulary Lessons (the book *Zero to Band 9*) → easy Bangla

First read and follow /home/claude/app/seed/staging/l10n/GUIDE_INSTRUCTIONS_bn.md (and the STYLE_bn.md it points to).
EASY, everyday Bangla for a Bangladeshi student who is weak in English. Short sentences. আপনি voice.

Input  /home/claude/app/seed/staging/vocab_guide/en/<file>.json
Output /home/claude/app/seed/staging/vocab_guide/bn/<file>.json  (same chapters, ids, block count/kinds, list
lengths, table shapes, exercise items — byte-identical prompt/answer/accepted).

What stays English (this is a vocabulary book — the English is what the student learns):
- every English word, phrase, collocation, idiom, example sentence, wrong/right sentence, model answer, essay,
  cue-card wording and Part 3 question;
- ["pair", wrong, right, why]: keep wrong and right EXACTLY; translate only "why".
- ["model", text]: keep EXACTLY (spoken model answers).
- Chapter 4 word lists (["ul"] under "Academic nouns", "Precise verbs", "Collocations…", "Formal Task 2…",
  "Speaking idioms…"): copy each item EXACTLY — they are an English term, its Bangla gloss already in brackets,
  and an English example. Only translate the h2 headings ("Academic nouns (10)" → "Academic nouns (১০টি)" style is
  fine, or "একাডেমিক noun (১০টি)").
- Chapter 3 verb tables: copy rows EXACTLY; translate the headers and caption.
- Chapter 5 idiom / collocation lists: "**expression**: meaning. Example: sentence" → keep **expression** and the
  example sentence in English; write the meaning in easy Bangla: "**once in a blue moon**: খুব কম, কালেভদ্রে।
  উদাহরণ: I eat out once in a blue moon."
- ["table"] in Chapter 2 (Band 5.5 / 7.5 / 9.0): keep the English words and English example sentences; translate
  the explaining sentences ("Use large for physical size…") into Bangla, keeping the English words inside them.

Translate: chapter titles and groups, p, h, h2, tip, note, box title + body (the "Bangla logic" / "Bangla nuance"
boxes are already partly Bangla — rewrite the whole body in easy Bangla, keeping the Bangla example sentence and
the English words), exercise title (keep "Exercise 1.1 ·" / "Essay 2 ·" prefixes) and instructions, and every
non-empty exercise "reason".

The book's own Bangla answer notes: /home/claude/app/seed/staging/vocab_guide/key_bn.json
- items[chapter id][exercise title][item number] = the author's Bangla for that item's reason → use it as the
  Bangla "reason" (smooth it into easy Bangla; keep its meaning; fix words the PDF glued together, e.g.
  "খুবসহজ" → "খুব সহজ").
- notes: v2_ex1_general = the "Why it works" note in v2_practice; ch3-exercise-3-2 = reason of Exercise 3.2;
  v4_N_completion = the "**Why:**" note after Exercise 4.N.2 (chapter v4_topic_0N / v4_topic_NN);
  ch5-exercise-5-1 = the "**Why:**" note in v5_practice; ch6-section1 = the note in v6_transformations.

Write the file with a Python script (json.dump(..., ensure_ascii=False, indent=1)). Then validate:
  python3 /home/claude/app/tool/check_writing_guide.py --guide vocab_guide <file>.json
0 errors required (warnings about English left in bn are expected here). Touch no other file.
