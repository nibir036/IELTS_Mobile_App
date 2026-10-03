# Speaking bank — writing guide (IELTS AI by nextED)

Sir's source files are in `seed/sources/speaking/`. Their parsed form is in `seed/staging/speaking/base/`:
`part1_sets.json` (62 Part 1 topics with sir's original questions), `part2.json` (200 cue cards),
`part3.json` (60 topics × 8 questions). Vocabulary marks look like `[[word]]`.

You write small JSON files into `seed/staging/speaking/part1|part2|part3/`. Check them with
`python3 tool/check_speaking.py` (run from the project root) until it reports 0 errors for your ids.

## House style (applies to everything)
- Spoken British English, first person, natural and fluent. Contractions are fine and expected in Part 1.
- British spelling (organise, colour, favourite, programme, centre, neighbour, travelling).
- NO em dashes (—) or en dashes (–) anywhere. Use commas, full stops or "and".
- No invented statistics, named studies, brands of research or exact figures ("studies show 73%...").
- Keep the persona below. Never contradict it.
- Vocabulary marks `[[word]]` go on genuinely useful Band 7–9 words or short phrases (C1-level:
  e.g. "tranquillity", "meticulous", "a double-edged sword", "take for granted"). Never mark plain words
  (people, health, have, buy, both, good, money, team, cost, goal, tool, increase, success, match...).
  Mark the exact form used in the sentence (e.g. `[[internalising]]`). One mark = one word or phrase of max 4 words.
- Do not repeat the same marked word within one topic/card.

## Persona (the speaker in every answer)
- Young man in his mid-20s from **Sirajganj**, a modest town in the north of Bangladesh beside the Jamuna river,
  about four hours from Dhaka by road. Lives in a three-bedroom flat on the third floor in a quiet residential area.
- Works at an **education consultancy**, mainly helping students apply to study abroad. Studied
  **business administration (BBA, management focus)** at university. Would like to study abroad himself one day.
- Speaks Bengali (mother tongue) and English fairly fluently. Muslim family (Eid, mosque are natural references).
- Family: **father** ran a small business for over thirty years and has recently retired; **mother** looks after
  the home; **younger sister** (a student, very hard-working) lives with them; **elder sister** is married and lives
  in Dhaka with her husband and two children (one is a four-year-old son). **Grandparents** (grandfather in his
  eighties, still sharp; wise grandmother with little formal education) live in the family's ancestral village home
  not far from Sirajganj, which the family visits often; mother often helps look after them.
- Close-knit family, dinner together most nights. Likes tea, reading, music, cricket (watching), walking by the river.
- Real Bangladeshi references are welcome where natural (Jamuna, Dhaka, Cox's Bazar, Sundarbans, Pohela Boishakh,
  Eid, rickshaws, monsoon), but keep them accurate and modest.

---

## Task A — Part 1 topic sets → `part1/<id>.json`
Each Part 1 topic must have **exactly 5 questions** like a real examiner's frame. Keep every one of sir's
original questions and answers (from `base/part1_sets.json`) **word for word**, and write new ones to make 5.

```json
{"id": "sp1_hometown", "questions": [
  {"source": 1, "q": "Where is your hometown?", "answer": "...sir's text, unchanged..."},
  {"source": null, "q": "What do you like most about living there?", "answer": "... with one [[mark]] ..."}
]}
```
- Order the 5 questions naturally: simple/factual first, then preferences, then a slightly more reflective
  "Has it changed / Would you like to ... in the future / Do you think ..." question last. Originals may move.
- New questions: short, realistic IELTS Part 1 wording (real exam style: "Do you ...?", "How often ...?",
  "What kind of ...?", "Did you ... as a child?", "Is ... popular in your country?"). No overlap with the originals.
- New answers: **25–50 words**, 2–3 sentences: direct answer + reason/example (+ small extension).
  Band 7.5–8 natural speech, **exactly one `[[mark]]`**.
- Only allowed change to sir's text: `sp1_family` source 3 must be updated to the persona (five of us; elder sister
  married in Dhaka) keeping its style and its `[[close-knit]]` mark; `sp1_future-plans` source 15 has no mark, add one
  by marking an existing suitable phrase (do not rewrite it otherwise).

## Task B — Part 2 cue cards → `part2/<id>.json`
Sir's monologues are ~160 words, which is only about 1 minute 15 seconds of speech. Candidates must talk for up to
2 minutes, so extend each one to **240–290 words**.

```json
{"id": "sp2_people_01",
 "answer": "full extended monologue with [[marks]]",
 "followUps": [
   {"q": "Do you still ask your father for advice?", "answer": "25–40 word short answer"},
   {"q": "...", "answer": "..."}],
 "part3": ["sp3_people_01", "sp3_people_02"],
 "note": "one line: what you added or changed"}
```
- Keep sir's monologue as the backbone: keep his sentences and all his `[[marks]]` (unless a mark is a plain word
  per the house style, then move the mark to a better word/phrase or rephrase slightly). Add new sentences so the
  talk covers **every bullet** clearly and in order, with a natural opening line and a reflective closing line.
  Total marks: **4–6**.
- Fix persona contradictions (e.g. father now retired: "ran" is right; elder sister's children; grandparents in
  the village).
- `followUps`: exactly **2** rounding-off questions the examiner might ask after the talk, short and directly about
  the card (e.g. "Would you like to go there again?"), each with a 25–40 word answer and 0–1 marks.
- `part3`: 1–2 Part 3 topic ids from `base/part3.json` whose discussion questions best follow this card
  (best match first). Must be real ids like `sp3_culture_04`.

## Task C — Part 3 vocabulary fixes → `part3/<id>.json`
Sir's Part 3 answers are good; only the vocabulary marks need attention. Each answer must have **exactly 3 marks**,
all genuinely useful Band 7–9 words/phrases.

```json
{"id": "sp3_people_03", "fixes": [
  {"n": 5, "answer": "full answer text with corrected [[marks]]", "why": "'had' is not advanced; marked 'drift apart'"}
]}
```
- Write a file for **every** topic you review (use `"fixes": []` if nothing needed).
- Fix an answer when: a mark is a plain word; it has fewer or more than 3 marks; or sir's "Vocabulary:" line
  (`sourceVocabLine`) lists a word that is not marked (usually mark that word instead of the weakest one).
- Prefer moving a mark onto an existing better word/phrase in the answer. If none exists, minimally rephrase one
  clause. Keep 50–85 words. Do not otherwise change sir's wording, and do not change questions or tags.

## Task D — Vocabulary dictionary → `vocab/entries_NN.json`
Each `vocab/todo_NN.json` lists marked words/phrases: `key` (lower-case form as used), `form`, one `context`
sentence (the word in **bold**) and `where` it appears. Write `vocab/entries_NN.json` = a JSON list with one entry
per todo item, same `key`, meaning **as used in that context**:

```json
{"key": "internalising", "headword": "internalise", "pos": "verb",
 "ipa": "/ɪnˈtɜːnəlaɪz/",
 "syllables": [{"text": "in", "stress": false}, {"text": "ter", "stress": true},
               {"text": "nal", "stress": false}, {"text": "ise", "stress": false}],
 "meaning": "to accept an idea or value so deeply that it becomes part of how you think",
 "example": "Children tend to internalise their parents' attitudes towards money long before they earn any.",
 "synonyms": ["absorb", "take on board", "embrace"],
 "level": "C1"}
```
- `headword`: dictionary form (verbs → base form, plurals → singular, comparatives → base) with British spelling.
  Phrases/idioms keep their natural citation form ("take a toll", "a double-edged sword"; drop a trailing "of" only
  if unnatural). `pos`: noun, verb, adjective, adverb, phrase, idiom, phrasal verb, collocation.
- `ipa`: **British (RP) IPA** of the headword between slashes, with ˈ primary stress (ˌ secondary allowed), as in
  the Cambridge/Oxford learner's dictionaries (e.g. /ˈtʃæləndʒ/, /trænˈkwɪləti/). Phrases: IPA of the whole phrase.
- `syllables`: for **single-word** headwords only, the spelling split into syllables (joined they must spell the
  headword exactly, hyphens aside), with exactly one `stress: true` (the primary stress). Phrases: `[]`.
- `meaning`: 5–25 words, plain learner English, the sense used in the context. No circular definitions.
- `example`: a NEW natural sentence (8–30 words), different from the context, useful for IELTS speaking topics.
- `synonyms`: 2–4 near-synonyms or alternative phrases in the same sense.
- `level`: CEFR estimate B2, C1 or C2.
- No em/en dashes. Check with `python3 tool/check_speaking.py vocab NN`.
