# Seed data — IELTS AI by nextED

- `formats/NN_<type>.json` — one file per data type: `_format` (table, primary key,
  fields + types, required fields, relations, notes) and `items` (1-2 real example
  records). Use these as the template when your team writes new content.
- `data/NN_<type>.json` — the current content bank and config exported in the same
  format (`{"table", "items"}`), ready to load as the first seed.
- `manifest.json` — every format, its group and record count.
- Regenerate after content changes: `python tool/build_seed_formats.py`.

Groups: **content** (01-29, same for every student), **config** (30-35, settings
you change without an app release), **user** (40-47, created by students — formats
only; seed them just for demo/test accounts), **bank** (50-71, the app's question
banks, full tests, resources, guides and translations).

Conventions: ids are stable lowercase strings with a type prefix (`rp_`, `ls_`, `w2_`,
`cc`, `mt_` …); timestamps ISO-8601 UTC (`2026-09-29T12:00:00Z`); dates `YYYY-MM-DD`
(Asia/Dhaka); audio/images are R2 object keys, not URLs; `**bold**` markdown is
allowed in explanations; British spelling; Academic IELTS only; original writing only.
Load order: content → config → users → everything that references users.

Reading question bank (from `IELTS_Reading_Question_Bank-1.pdf`): `27_reading_bank_passages`
(280 passages, 2,060 questions, 14 question types), `28_reading_type_lessons` (14 strategy
lessons) and `29_reading_practice_tests` (20 short tests). Rebuild with
`python tool/import_reading_bank.py --pdf <path to the PDF>`; checks and corrections are in
`reports/reading_bank_import_report.md`.

## Banks, full tests, guides (50-71)

Built by `python tool/build_seed_banks.py` straight from the app's content files
(`assets/content/*.json`), so the database holds exactly what the app shows. Rows
are already in table shape (Prisma field names); `data` keeps the app's own record,
which the content API returns unchanged.

| Files | Table | What |
|---|---|---|
| 50, 51 | listening_sets | question bank (32, `source` bank) · Listening Test parts (16, `source` test) |
| 52 | listening_tests | Listening Test 1-4 (`kind` full; the demo tests are `kind` demo) |
| 53, 54 | reading_passages, reading_tests | Academic Reading Test 1-10 (30 passages, `source` test) |
| 55, 56 | writing_prompts, writing_sample_answers | writing bank: 260 questions + Band 6/7/8 samples |
| 57, 58 | writing_prompts, writing_tests | Writing Test 1-10 |
| 59-61 | speaking_part1_topics, speaking_cue_cards, speaking_part3_sets | speaking bank (65 / 207 / 60) |
| 62-65 | the same + speaking_tests | Speaking Test 1-10 |
| 66 | mock_tests | Full Mock Test 1-4 (`kind` full; demo mocks A-C are `kind` demo) |
| 67-70 | vocabulary_words, phrases, academic_words, irregular_verbs | resources bank (ids shared with 11-15 update those rows) |
| 71 | content_documents | 6 study guides, bank notes, connector + topic lists, speaking glossary, Bangla translations |

Audio and image columns hold R2 object keys (`listening/lt_w01_p1.mp3`); the files
themselves still ship inside the app until they are uploaded to R2.

Load order and command: `tool\seed_db.bat` (migrations → client → `prisma db seed`).
Re-run `build_seed_formats.py` and then `build_seed_banks.py` after content changes.
