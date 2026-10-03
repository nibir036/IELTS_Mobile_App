# Sample answers — writing guide (IELTS AI by nextED)

For every question write THREE independent answers: Band 6, Band 7 and Band 8.
Save one file per question: `seed/staging/writing_samples/<id>.json`

```json
{
  "promptId": "wb2_opinion_01",
  "title": "Homework in primary schools",          // Task 2 only: 2–5 word title
  "samples": [
    {"band": 6, "text": "Paragraph one...\n\nParagraph two...", "why": "..."},
    {"band": 7, "text": "...", "why": "..."},
    {"band": 8, "text": "...", "why": "..."}
  ]
}
```

## Format
- Plain text. Paragraphs separated by a blank line (`\n\n`). No headings, bullets, bold, or quotation of the question.
- British spelling (organise, colour, programme, centre).
- Word counts (checked by `python3 tool/check_samples.py`):
  - Task 1: Band 6 160–190 · Band 7 170–205 · Band 8 175–215
  - Task 2: Band 6 255–295 · Band 7 265–315 · Band 8 275–335
- `why`: one line, 15–35 words, the examiner-style reason for the band, criteria separated by " · ".
  e.g. Band 6: "Clear position · relevant main ideas but some are underdeveloped · mechanical linking · adequate vocabulary with some awkward choices · several grammar errors that do not block meaning."
- The three answers must be written separately (different wording and structure), not one essay with words swapped.

## What each band must look like (public IELTS band descriptors)
Band 6
- Task 1: an overview is present but may be basic or placed late; key features covered but some detail is mechanical or less relevant; figures accurate (may approximate with "about/around"); linking is adequate but repetitive or mechanical (Firstly, Also, Then); vocabulary adequate with some awkward or repeated choices; a mix of simple and complex sentences with 4–7 small errors (articles, prepositions, agreement, word form, tense) that never block meaning.
- Task 2: addresses all parts but some ideas are underdeveloped or general; a relevant position that may be slightly unclear or repetitive in the conclusion; paragraphing present though not always logical; same kind of language and 4–7 errors as above.
Band 7
- Task 1: clear overview of the main trends/differences/stages; key features clearly presented and highlighted; logical progression; a range of cohesive devices (some slight over/under-use); some less common vocabulary and collocation; frequent error-free sentences with 1–3 minor slips.
- Task 2: clear position throughout; main ideas extended and supported, though some over-generalisation; clear central topic in each paragraph; same language level as above.
Band 8
- Task 1: key features skilfully selected, clear well-placed overview, accurate figures used selectively for comparison; cohesion managed well; wide, precise vocabulary (occasional minor inaccuracy at most); wide range of structures, the majority error-free (0–1 slips).
- Task 2: sufficiently addresses all parts with well-developed, relevant, extended and supported ideas; logical sequencing; paragraphing well managed; wide vocabulary used fluently and flexibly; wide range of structures, rare minor errors.

Errors in Band 6/7 must be realistic learner errors (not spelling nonsense, not deliberately silly). Band 8 should read as natural, polished writing — not over-decorated with rare idioms.

## Task 1 rules
- Use ONLY the data given. Every figure you quote must match the data exactly (or be a correct, clearly derived comparison such as "doubled", "a rise of 20 points", "roughly a third"). Never invent figures, causes or reasons.
- Start by paraphrasing the question statement (do not copy it word for word). Include an overview.
- Maps: describe the main changes (what was removed, added, moved, converted) using the feature names and positions (north, south-west ...). Do not mention the coordinate numbers.
- Processes: describe every stage in order; Band 7–8 should use passive forms and sequencing language; state the number of stages / start and end point in the overview; for cyclical processes say it repeats.
- Combination tasks: cover both/all visuals and link them where sensible.
- No personal opinion, no conclusion paragraph with advice.

## Task 2 rules
- Answer every part of the question in the way its type requires:
  Opinion → a clear extent of (dis)agreement; Discussion → both views + own opinion; Advantages & Disadvantages → both sides, and a judgement when the question asks "outweigh"; Problems & Solutions (or causes/solutions) → both parts as asked; Two-Part → answer both questions directly; Positive/Negative Development → a clear judgement.
- Introduction + 2–3 body paragraphs + conclusion.
- Examples may be general or hypothetical ("in many large cities", "a student who ..."). Do NOT invent precise statistics, named studies, or real named people.
