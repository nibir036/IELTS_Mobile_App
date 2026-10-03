# Content bank schema (Phase 2)

All practice CONTENT lives in `assets/demo/content/*.json` and is merged by
`python3 tool/merge_demo.py` into `demo_data.json` under the top-level key
`"content"`. Read in Dart with `Demo.section('content').m('reading')` etc.
User data stays in `Store` (unchanged). This bank is also the future DB seed,
so keep ids stable and shapes regular.

Everything is ORIGINAL writing (no text copied from Cambridge/IDP/BC books or
websites). Academic IELTS only (no General Training). British spelling.

Files (one file per writer, merged by key):
- `content/reading_<n>.json`  → `{"reading": {"passages": [...], "tests": [...]}}` (lists are concatenated across files)
- `content/listening.json`    → `{"listening": {"sets": [...], "tests": [...]}}`
- `content/writing.json`      → `{"writing": {"task1": [...], "task2": [...]}}`
- `content/speaking.json`     → `{"speaking": {"part1Topics": [...], "cueCards": [...]}}`
- `content/mock.json`         → `{"mock": {"tests": [...]}}`
- `content/resources.json`    → `{"resources": {"quizzes": [...], ...}}`

## Reading

```jsonc
// passage
{
  "id": "rp_01",
  "title": "The Return of the Urban Beekeeper",
  "topic": "Environment",          // Environment|Science|History|Technology|Society|Health|Education|Business|Arts
  "difficulty": "medium",          // easy|medium|hard (passage 1 easy, 2 medium, 3 hard in a test)
  "words": 820,                    // approx word count of the passage
  "paragraphs": [ { "letter": "A", "text": "…" }, … ],   // 5–8 paragraphs, 700–950 words total
  "groups": [                      // 12–14 questions total, numbered 1..n LOCALLY (the app offsets them in full tests)
    { "id": "g1", "type": "tfng", "title": "True / False / Not Given",
      "instruction": "Do the following statements agree with the information given in the passage?",
      "options": ["TRUE","FALSE","NOT GIVEN"],
      "questions": [ { "number": 1, "text": "…", "answer": "TRUE",
                       "evidenceParagraph": "A", "evidence": "exact phrase copied from the paragraph",
                       "explanation": "Short **markdown-bold** reason." } ] },
    { "id": "g2", "type": "ynng", …same as tfng with options ["YES","NO","NOT GIVEN"] (writer's views) },
    { "id": "g3", "type": "heading", "title": "Match each paragraph to a heading",
      "headings": [ {"key":"i","text":"…"}, … ],          // 2–3 more headings than questions
      "questions": [ { "number": 4, "text": "Paragraph B", "paragraph": "B", "answer": "ii", … } ] },
    { "id": "g4", "type": "matching", "title": "Which paragraph contains the following information?",
      "options": ["A","B","C","D","E","F"],
      "questions": [ { "number": 7, "text": "a reference to …", "answer": "D", … } ] },
    { "id": "g5", "type": "mcq", "title": "Choose the correct letter, A, B, C or D",
      "questions": [ { "number": 9, "text": "…", "options": [{"key":"A","text":"…"},…4], "answer": "B", … } ] },
    { "id": "g6", "type": "gap", "title": "Complete the summary",
      "instruction": "Choose NO MORE THAN TWO WORDS from the passage for each answer.",
      "questions": [ { "number": 11, "text": "Beginners may need a short ______ course.",
                       "answer": "training", "accepted": ["training"], … } ] }
  ]
}
// test (Academic full test = 3 passages, 40 questions total, 60 min)
{ "id": "rt_01", "number": 1, "title": "Academic Reading Test 1", "passages": ["rp_01","rp_02","rp_03"] }
```
Every question has `evidenceParagraph`, `evidence` (a phrase that appears
VERBATIM in that paragraph) and `explanation`. Gap answers must be words that
appear in the passage and respect the word limit. Mix 3–4 group types per
passage. Question counts per test must add to 40 (e.g. 13 + 13 + 14).

## Listening

```jsonc
// set = one part of a test (10 questions)
{
  "id": "ls_01", "part": 1,                       // 1 social dialogue · 2 social monologue · 3 academic discussion (2–4 speakers) · 4 academic lecture
  "title": "Harbour Sports Club membership", "context": "A man phones a sports club to join.",
  "audio": "assets/audio/listening/ls_01.mp3",    // generated from the transcript (TTS placeholder)
  "durationSeconds": 0,                           // filled in by the audio generator
  "speakers": [ {"name": "Receptionist", "voice": "female"}, {"name": "Jonathan", "voice": "male"} ],
  "transcript": [ { "id": "t1", "speaker": "Receptionist", "text": "…", "start": 0,
                    "keywords": ["phrase that carries an answer"], "answerTags": [ {"after": "phrase", "question": 1} ] } ],
  "groups": [
    { "id": "g1", "type": "form", "title": "Complete the form", "instruction": "Write ONE WORD AND/OR A NUMBER for each answer.",
      "formTitle": "Harbour Sports Club", "formSubtitle": "Membership form",
      "questions": [ { "number": 1, "label": "Surname", "before": "", "after": "", "answer": "Fairfax", "accepted": ["Fairfax"] } ] },
    { "id": "g2", "type": "gap", "title": "Complete the notes", "instruction": "Write NO MORE THAN TWO WORDS …",
      "questions": [ { "number": 5, "text": "Classes start at ______ on weekdays.", "answer": "6.30", "accepted": ["6.30","6:30","half past six"] } ] },
    { "id": "g3", "type": "mcq", "title": "Choose the correct letter, A, B or C",
      "questions": [ { "number": 7, "text": "…", "options": [{"key":"A","text":"…"},…3], "answer": "A" } ] },
    { "id": "g4", "type": "multi", "title": "Choose TWO letters, A–E", "pick": 2,
      "questions": [ { "number": 9, "text": "Which TWO …?", "options": [{"key":"A",…}…5], "answer": ["B","D"] } ] },   // counts as 2 questions (9–10); `number` is the first
    { "id": "g5", "type": "matching", "title": "…", "options": [{"key":"A","text":"…"},…],
      "questions": [ { "number": 1, "text": "Café", "answer": "C" } ] }
  ]
}
// full test = 4 sets (Parts 1–4), questions renumbered 1–40 by the app
{ "id": "lt_01", "number": 1, "title": "Listening Test 1", "sets": ["ls_01","ls_02","ls_03","ls_04"] }
```
Transcript: 25–45 lines per set, natural speech, answers stated clearly once
(with a distractor where IELTS would use one). Each question's answer must be
recoverable from the transcript; tag it with `answerTags`.

### Listening question bank (`assets/content/listening_bank.json`)

Built by `python tool/import_listening_bank.py <IELTS_Listening_Question_Bank_ElevenLabs_v4.pdf>`
(needs `pip install pdfplumber`). `{meta, sets}`; 32 sets = Parts 1–4 × 8 formats,
20 questions each. The practice lists (Part practice, Mini practice, search) show
these; full tests / mocks / the diagnostic keep using the demo sets above.

```jsonc
{
  "id": "lb_p1_tc", "code": "P1-TC", "part": 1,
  "format": "table", "formatCode": "TC", "formatLabel": "Table Completion",   // FN MC MA PM SC TC SM SA
  "title": "…", "band": 5.5, "accent": "British", "locale": "en-GB", "minutes": 10, "tags": ["…"],
  "listeningContext": "Everyday social/transactional situation (dialogue, 2 speakers)",
  "scenario": "…", "context": "…(= scenario)", "instructions": "…", "wordLimit": "Write ONE WORD AND/OR A NUMBER for each answer.",
  "audio": "assets/audio/listening/P1-TC.mp3",      // not there yet → the player runs a timed simulation
  "audioKey": "listening/bank/P1-TC/P1-TC_Table_Completion.mp3", "audioStatus": "pending",
  "durationSeconds": 194, "durationEstimated": true, "transcriptTiming": "estimated", "answerMarkers": "auto",
  "speakers": [ {"name": "Helen", "role": "Customer", "description": "Customer — female, …", "voice": "female"} ],
  "production": { "model": "eleven_v4", "tool": "Text to Dialogue …", "stability": 0.5, "similarity": 0.75,
                  "scriptChars": 3557, "chunks": 1, "setup": [ {"setting": "…", "value": "…"} ] },
  "script": [ {"speaker": "Helen", "text": "[tags kept] line as printed", "chunk": null} ],  // for ElevenLabs
  "transcript": [ {"id": "t1", "speaker": "…", "text": "tags stripped", "start": 1.0, "directions": ["…"],
                   "keywords": [], "answerTags": [] } ],
  "groups": [ … ],                                   // types below
  "answerKey": {"1": "450", …}, "fields": { "audio_asset": "…", … }   // the PDF's Fields Summary
}
```
Extra group types (on top of form / gap / mcq / multi / matching):
- `notes`, `sentence`: like `gap` (`text` with `______`)
- `short`: `{number, text: "question?", answer, answerDisplay, accepted}` → box under the question
- `table`: `columns`, `rows` (cells keep `(n)___`); question `{number, label: "Row · Column", before, after, row, col}`
- `summary`: `summary` paragraph (keeps `(n)___`); question `{number, text: sentence with ______, before, after}`
- `map`: `layout` (as printed), `layoutIntro`, `options: [{key: "A", text: "written position"}]`, `image` ("" until drawn)
Typed answers: `answer` = first accepted form, `answerDisplay` = key as printed ("10 / ten"), `accepted` = all forms.

## Writing
```jsonc
// task1
{ "id": "w1_01", "type": "line|bar|pie|table|process|map|mixed", "title": "short title",
  "prompt": "The graph below shows … Summarise the information by selecting and reporting the main features, and make comparisons where relevant.",
  "chart": { … see below … },
  "modelAnswer": { "band": 8, "text": "… 170–190 words, \n\n between paragraphs" } }
// chart shapes
line/bar: {"unit":"%","xLabels":["2000","2005",…],"series":[{"name":"France","values":[…]},…]}
pie:      {"unit":"%","charts":[{"label":"1990","slices":[{"name":"Coal","value":40},…]}]}   // 1–2 pies
table:    {"columns":["Country","2010","2020"],"rows":[["Japan","12","15"],…]}
process:  {"steps":["Stage 1 text","Stage 2 text",…]}                 // 6–10 steps
map:      {"before":{"label":"1995","features":["…"]},"after":{"label":"Today","features":["…"]}}
// task2
{ "id": "w2_01", "type": "opinion|discussion|advantages|problem|two-part", "topic": "Education",
  "title": "short title", "prompt": "full question …\n\nGive reasons for your answer and include any relevant examples from your own knowledge or experience.",
  "ideas": { "for": ["…"], "against": ["…"], "vocabulary": ["…"] },
  "modelAnswer": { "band": 8, "text": "… 260–300 words" } }                 // modelAnswer optional
```

### Writing question bank (`assets/content/writing_bank.json`)

Built by `python tool/import_writing_bank.py <Task1 PDF> <Task2 PDF>` (poppler + Pillow + pdfplumber).
`{meta: {task1, task2}, task1: [...140], task2: [...120]}`; the Task 1 visuals are
`assets/writing/task1/<id>.webp` (taken from the PDF). Sample answers come from
`seed/staging/writing_samples/<id>.json` (Band 6 / 7 / 8, see GUIDE.md there;
check with `python tool/check_samples.py`, review PDFs via `python tool/build_writing_samples_pdf.py`).
The writing screens show these; mock tests, the diagnostic and Ideas & topics keep the demo prompts.

```jsonc
// Task 1
{ "id": "wb1_line_01", "task": 1, "number": 1, "type": "line",            // line bar pie table map process mixed
  "typeLabel": "Line graph", "section": "Line Graph", "title": "Households with home internet access, 2000–2020",
  "statement": "The line graph below shows …", "prompt": "<statement> Summarise the information …",
  "instructions": ["You should spend about 20 minutes on this task.", "…", "Write at least 150 words."],
  "timeMinutes": 20, "minWords": 150,
  "image": "assets/writing/task1/wb1_line_01.webp", "imageSize": [1436, 785],
  "visual": { "panels": [ { "kind": "Line graph", "title": "…", "xAxis": "Year", "yAxis": "% of households (scale 0–100, interval 20)",
                            "scale": {"min": 0, "max": 100, "interval": 20}, "columns": ["Year", "Canada", …], "rows": [["2000", "42", …]] } ] },
              // maps: {frame, features: [{n, name, kind, position}]} · processes: {stages: [{n, label, detail}], cycle?}
  "dataText": "the data as clean text (AI grader)", "dataPrinted": "the data as printed",
  "chart": { … },                                    // the app's native chart shape where the data fits it
  "imagePrompt": "the PDF's image-generation prompt", "sourcePage": 3,
  "samples": [ {"band": 6, "label": "Band 6", "words": 183, "text": "…", "paragraphs": [[{"text": "…"}, {"text": "However,", "mark": "link"}]], "why": "…"}, … ],
  "modelAnswer": {"band": 8, "text": "…"} }
// Task 2
{ "id": "wb2_opinion_01", "task": 2, "number": 1, "type": "opinion",      // opinion discussion advantages problem two-part positive-negative
  "typeLabel": "Opinion", "topic": "Education", "difficulty": "Moderate",  // Moderate · Upper-moderate · Difficult
  "title": "Homework in primary schools", "question": "…", "prompt": "<question>\n\nGive reasons …",
  "instructions": ["…", "Give reasons … Write at least 250 words."], "timeMinutes": 40, "minWords": 250,
  "samples": [ … ], "modelAnswer": {"band": 8, "text": "…"} }
```

## Speaking
```jsonc
{ "part1Topics": [ { "id": "s1_work", "topic": "Work or studies", "questions": ["…", …4–5] } ],
  "cueCards": [ { "id": "cc_01", "topic": "People|Places|Objects|Events|Experiences|Media",
                  "title": "Describe a person who helped you", "prompt": "Describe a person who …",
                  "bullets": ["who this person is","how you know them","what they did","and explain how you felt about it"],
                  "part3": ["discussion question", …4–5],
                  "sampleNotes": ["note", "note", "note"] } ] }
```

### Speaking question bank (`assets/content/speaking_bank.json`)

Also 7 cue cards and 3 Part 1 topics taken from sir's Speaking guide (`source: "guide"`), the only ones the bank
did not already cover (listed in `seed/staging/speaking/guide_extras.json`, copied by `tool/import_speaking_bank.py`).
Guide cards carry sir's 1-minute `notes` and `phrases`, no follow-ups; their `part3` list starts with sir's own
questions (no sample answers) followed by two answered bank questions. Guide Part 1 topics have 3 questions.

Built by `python tool/import_speaking_bank.py` from sir's HTML files in `seed/sources/speaking/`
(parsed by `tool/speaking_source.py`) plus the edits in `seed/staging/speaking/` (see GUIDE.md there;
check with `python tool/check_speaking.py` and `python tool/check_speaking.py vocab`).
Also writes `seed/audio/speaking_audio_manifest.json` (1,390 sample-answer clips for TTS, pending).
When present, `Content.part1Topics` / `Content.cueCards` return the bank; the demo topics and cards
above stay available by id (`Content.speakingDemoPart1/Cards`) for mock tests and the diagnostic.
Sample answers mark vocabulary as `[[word]]`; the lower-cased text is a key of `vocab`.

```jsonc
{ "meta": { "counts": {…}, "part1Categories": [{"id": "personal", "label": "Personal & Background"}, …],
            "part2Categories": […], "part3Categories": […], "part3Tags": [{"id": "opinion", "label": "Opinion"}, …],
            "sampleNote": "…", "bands": {"part1": "Band 7.5–8", "part2": "Band 7.5–8", "part3": "Band 8+"} },
  "part1Topics": [ { "id": "sp1_hometown", "bank": true, "topic": "Hometown", "category": "personal",
                     "categoryLabel": "Personal & Background", "intro": true,            // work / studies / hometown / home
                     "questions": ["…" ×5],
                     "samples": [ {"q": "…", "answer": "… [[tranquillity]] …", "source": 1, "words": 38} ×5 ] } ],   // source = sir's item no. (null = new)
  "cueCards": [ { "id": "sp2_people_01", "bank": true, "number": 1, "cardNumber": 1, "category": "people",
                  "categoryLabel": "People", "topic": "People", "title": "Describe a person who has influenced you",
                  "prompt": "…", "bullets": ["…" ×4],
                  "sample": {"answer": "240–290 words with [[marks]]", "words": 262, "seconds": 112},
                  "followUps": [ {"q": "rounding-off question", "answer": "…"} ×2 ],
                  "part3Topics": ["sp3_people_01", "sp3_people_02"],
                  "part3": ["…" ×5–6], "part3Samples": [ {"q", "tag", "tagLabel", "answer", "words", "edited"} ] } ],
  "part3Topics": [ { "id": "sp3_people_01", "bank": true, "number": 1, "category": "people",
                     "categoryLabel": "People & Relationships", "topic": "Role Models",
                     "questions": [ {"q": "…", "tag": "opinion", "tagLabel": "Opinion", "answer": "…", "words": 67, "edited": true} ×8 ] } ],
  "vocab": { "internalising": { "headword": "internalise", "pos": "verb", "ipa": "/ɪnˈtɜːnəlaɪz/",
                                "syllables": [{"text": "in", "stress": false}, {"text": "ter", "stress": true}, …],   // [] for phrases
                                "meaning": "…", "example": "…", "synonyms": ["…"], "level": "C1" } } }
```

## Resources bank (`assets/content/resources_bank.json`)

Built by `python3 tool/import_resources_bank.py` from `seed/sources/resources/` (HTML lists). Loaded as
`Demo.resourcesBank`, read through `ResBank` (`lib/app/data/res_bank.dart`). Missing file → the resource screens
use the demo lists in `resources`.

| Key | Items | Fields |
|---|---|---|
| `vocab` | 1,382 | `id` (`vb_…`), `word`, `ipa`, `pos`, `definition`, `examples` [2, **bold** = the word], `synonyms` [], `register` (formal/neutral/informal), `band` (4.5–9) |
| `idioms` | 1,159 | `id` (`id_…`), `phrase`, `meaning`, `example` — A–I from the source files (588), J–Z written for the app and dictionary-checked (571, `idioms_*_added.html`) |
| `phrasalVerbs` | 1,258 | `id` (`pv_…`), `phrase`, `meaning`, `example` |
| `irregularVerbs` | 175 | `base`, `past`, `participle` (alternatives as "learnt / learned"), `meaning`, `example` |
| `connectors` | 14 groups · 106 | `{id, title, note, items: [{id (`cn_…`), word, use, example, function, register}]}` |
| `academicWords` | 686 | `id` (`aw_…`), `word`, `pos`, `definition`, `example`, `family` [], `list` (core / extended) |
| `topics` | 23 topics · 2,095 | `{id (`tv_<topic>`), title, items: [{id (`tv_<topic>_<term>`), term, meaning, example}]}` — Topic Vocabulary screen (`/resources/topic-vocabulary`, args `{'topic'}`), Vault, search |

Where it shows: Vocab Vault (all kinds, by category and letter, word sheet with examples), Phrasal Verbs / Idioms
(the curated IELTS phrases in `content.resources` are merged in by phrase: their id, topic, register and IELTS
example are kept), Academic Words (20 a day → 35 days, generated `aw_day_N` quizzes, Linking words tab), Irregular
Verbs (meaning and example sheet), word of the day (a Band 7.5+ word per day), search and saved words.
Word ids are stable slugs, so saved words and Known/Learning marks survive a re-import.

Vault quizzes: besides the starter rounds (`content.resources.quizzes`), `ResBank.quizDecks` generates
10-question choose-the-meaning rounds from the bank (ids `gq_<deck>_<n>`, read through `Content.quiz`): decks
`b6`/`b7`/`b8`/`b9` (vocab by band), `syn` (closest synonym), `idiom`, `pv` (phrasal verbs), `link` (linking words,
"how it is used") and `topic` (rounds stay inside one topic, e.g. "Education 2"). Rounds are a fixed seeded shuffle,
so a round id always means the same words and options; distractors come from the same deck and part of speech.
The round picker (Vault → Start quiz) lists the starter rounds and each deck; a deck starts its next unplayed round.

Easy Bangla meanings: `assets/content/l10n/bn/resources.json` `{meanings: {<word id>: bn}}` (vocab, idioms, phrasal
verbs, connectors, academic words, topic terms; irregular verbs as `iv_<base>`). Sources
`seed/staging/l10n/resources/{src,bn}/batch_NN.json` (`INSTRUCTIONS_bn.md`); shown under the English definition
(`TrMeaning`) when Bangla is picked with the language chips on the Vault, phrase lists, Academic Words and
Irregular Verbs.

## Mock tests
```jsonc
{ "id": "mt_a", "letter": "A", "title": "Mock Test A",
  "listeningTest": "lt_01", "readingTest": "rt_01", "task1": "w1_01", "task2": "w2_01",
  "speaking": { "part1": "s1_work", "cueCard": "cc_01" } }       // part 3 = the cue card's part3 list
```

## Full tests bank (`assets/content/tests_bank.json`)
Built by `tool/import_web_tests.py` from the website exports in `seed/sources/web_tests/`
(website tests 11–14 → Listening Tests 1–4; tests 11–20 → Reading/Writing/Speaking Tests 1–10;
text repairs in `fixes.json`; Writing Test 3's picture redrawn by `draw_test13.py`).
```jsonc
{ "listening": { "tests": [{ "id": "lt_w01", "number": 1, "title": "Listening Test 1", "sets": ["lt_w01_p1", …] }],
                 "sets":  [/* listening set shape; audio assets/audio/listening/lt_wNN_pK.mp3 (cut from the
                             website full.mp3 at its pauses), transcriptStatus "none", map groups carry "image" */] },
  "reading":   { "tests": [{ "id": "rt_w01", "title": "Academic Reading Test 1", "passages": [3 ids] }],
                 "passages": [/* reading passage shape, 40 questions per test */] },
  "writing":   { "tests": [{ "id": "wt_01", "number": 1, "title": "Writing Test 1", "task1": "wt_01_t1", "task2": "wt_01_t2" }],
                 "prompts": [/* task 1: image assets/writing/tests/wt_NN_task1.jpg; task 2: question; both "test" */] },
  "speaking":  { "tests": [{ "id": "st_01", "part1": "st_01_p1", "cueCard": "st_01_cc", "part3": ["st_01_p3_1", …] }],
                 "part1Topics": […], "cueCards": […], "part3Topics": […] },
  "mock":      { "tests": [{ "id": "mt_01", "title": "Full Mock Test 1", "listeningTest": "lt_w01",
                 "readingTest": "rt_w01", "task1": "wt_01_t1", "task2": "wt_01_t2",
                 "speaking": { "part1": "st_01_p1", "cueCard": "st_01_cc" } }] } }
```
When the bank is loaded, `Content.listeningTests / readingTests / mockTests` list only these; the demo
tests (lt_01, rt_01, mt_a …) are hidden but still resolve by id for older attempts. Writing and Speaking
full tests are listed on `/writing/tests` and `/speaking/tests` (`lib/features/tests/full_tests_screens.dart`).

## Translated study content (`assets/content/l10n/`)

Passages, questions, options, answers and model answers always stay English (like the real test). Lessons and
answer explanations can be shown in Bangla (`bn`), Nepali (`ne`), Arabic (`ar`, right-to-left) or Indonesian (`id`);
anything not translated falls back to English. The student picks the language in Profile → Explanation language
or with the chips above a lesson / explanation; it is the same setting as the AI feedback language
(Store kv `feedbackLanguage`, sent to the server, which accepts `en | bn | ne | ar | id`).

- Sources: `seed/staging/l10n/reading/src/` (English, generated from the bank) and
  `seed/staging/l10n/reading/<lang>/` (translations; Bangla style: `seed/staging/l10n/STYLE_bn.md`).
- Check: `python3 tool/check_l10n.py <lang>` — coverage, script, English quotes kept.
- Build: `python3 tool/build_l10n.py` writes `assets/content/l10n/<lang>/reading.json` and `index.json`
  (`{"reading": ["bn", …]}` — only languages that pass the check). New language folders must be added to
  `pubspec.yaml`.

`<lang>/reading.json`:

```json
{
  "typeLessons": {"rtl_tfng": {"title": "…", "sections": [{"heading": "…", "text": "…"}]}},
  "passages": {"rb_tfng_01": {"lesson": {"title": "…", "text": "…", "example": "…"},
                              "explanations": {"1": "…", "2": "…"}}}
}
```

Also in `<lang>/reading.json`: `skillLessons` (rl_… title/keyIdea/uses), `tips` (reading tip articles: title,
tips[{title, body}], tryIt), `guide` (Reading Guide chapters {title, blocks}) and the library passages (rp_…) under
`passages` (explanations only). English sources for these are exported by `python3 tool/export_l10n_src.py`.

### Study guides (`assets/content/<module>_guide.json`)

`{title, subtitle, chapters: [{id, title, blocks}]}` shown by `StudyGuideScreen` (Reading → Reading Guide).
Blocks: `["p", text]`, `["h", text]`, `["ul"|"ol", [items]]`, `["tip", text]`, `["ex", English example]`,
`["table", [columns], [[cells]]]`, plus `["h2", text]`, `["note", text]` (rule / template box), `["model", text]`
(model answer) and `["img", asset path, caption]`; `**bold**` works in any text. A translated chapter must have the
same block layout as the English one.

Writing Guide (Writing → Writing Guide) = sir's book *IELTS Academic Writing সম্পূর্ণ গাইড*
(seed/sources/guides/IELTS_Writing_Complete_Book_Bangla.pdf), lesson chapters only (the student-sample chapters
3 and 5 are covered by the app's sample answers). Sources: `seed/staging/writing_guide/{bn,en}/*.json` (checked by
`tool/check_writing_guide.py`), chart images in `assets/writing/guide/`. `python3 tool/build_l10n.py` writes
`assets/content/writing_guide.json` (English) and `assets/content/l10n/<lang>/writing.json` `{guide, tips}`.
Speaking Guide (Speaking hub → Speaking Guide) = sir's *IELTS Speaking — Band 7+ এর জন্য সম্পূর্ণ গাইড*
(seed/sources/guides/IELTS_Speaking_Guide_book_full.html), converted exactly by `python3 tool/import_speaking_guide.py`
into `seed/staging/speaking_guide/bn/` (Parts A–C + the final checklist; the Part 1 topic bank and the 40-card bank are
left out — the app has its own speaking bank). English in `en/` (translation, same layout); tips in `tips_{en,bn}.json`
(series `speaking`). Check with `python3 tool/check_writing_guide.py --guide speaking_guide`.

Grammar Course (Resources → Grammar Course, also Writing Practice in the module list) = the web version's grammar
course (seed/sources/grammar/, from NextEd-IELTS-V2 prisma/seed-data/grammar): 4 modules, 11 chapters, 20 exercises
(258 items). `python3 tool/import_grammar.py` converts it to `seed/staging/grammar_guide/en/` (long chapters split in
two; one Practice chapter per chapter with the short recap and its exercises). Additions are kept in
`added_exercises.json` (Exercise 9.2 — Chapter 9 had only one) and `fixes.json` (a paragraph the source had only in
Bangla). Bangla in `bn/` (translation, same layout; exercise prompts/answers identical). Extra blocks: `["box", kind
(regional|l1|impact), title, body, [items]]`, `["pair", incorrect, correct, why]`, `["exercise", {title, kind
(gap_fill|correction|essay_edit), instructions, items[{prompt, answer, accepted, reason}]}]`, tables may carry a 4th
caption element; chapters may have a `group` (module) shown as a heading on the contents page.

Listening Guide (Listening → Listening Guide, `/listening/guide`) = the website's Listening Module 1 (*Zero to Band
9* field guide, seed/sources/listening/), converted by `python3 tool/import_listening_guide.py` into
`seed/staging/listening_guide/en/` — 15 chapters in groups Strategy / Question types / Test day / Practice tests;
tutor tips → `tip`, principles → `note`, practice drills → `exercise` (`essay_edit`: try, then reveal the answer).
Listening Tips (4 articles `lt_…`, series `listening`) come from the module's 23 short lessons (`tips_{en,bn}.json`).
Vocabulary Lessons (Resources → Vocabulary Lessons, `/resources/vocab-lessons`) = the full nextED vocabulary book
*Zero to Band 9* (website `data/vocab/chapterN_data`, copied to seed/sources/vocab/book/), converted by
`python3 tool/import_vocab_book.py` into `seed/staging/vocab_guide/en/` — 49 chapters: the 30 L1 errors (pair +
Bangla logic + examiner view), the 35-word upgrade matrix, the 100-verb table and linking guide, 15 topic bundles
(nouns, verbs, collocations, Task 2 phrases, idioms + match / completion / speaking drills), 50 Speaking idioms and
50 Writing collocations, and the workbook (20 transformations, 5 essay rewrites, 5 Speaking simulations). The book's
answer key (Chapter 7) is attached to the exercises: gap_fill for one-word answers, essay_edit (try, then reveal)
for rewrites; its Bangla notes are in `key_bn.json` for the translators (`TRANSLATE_bn.md`). The website's short
lesson cards (`all-chapters-lessons.json`) are no longer used.
Bangla for both in `bn/` (easy Bangla: `seed/staging/l10n/GUIDE_INSTRUCTIONS_bn.md`);
`build_l10n.py` writes `listening_guide.json` / `vocab_guide.json` and `l10n/bn/{listening,vocab}.json`.

Writing Tips articles (resources → articles, series `writing`) come from `seed/staging/writing_guide/tips_en.json`
(+ `tips_bn.json`), condensed from the same book.

Type-lesson sections match the English lesson one-to-one (exhibits/tables stay English; a table-only section shows
the translated gloss under its table). Explanation keys are the stored question `number` of the bank passage.
App side: `lib/app/data/l10n.dart` (`ContentL10n`), `lib/app/widgets/lang_switch.dart`.
