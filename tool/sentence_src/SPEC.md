# Sentence Builder bank - authoring spec

Each category file `tool/sentence_src/<category>.json` is:

```json
{"category": "relative", "drills": [ {...}, {...} ]}
```

One drill = two short source sentences the student joins into ONE sentence by
tapping word chunks in order. The app checks the answer by exact chunk order,
so every drill must have exactly ONE natural correct order.

```json
{
  "id": "relative_001",
  "connector": "which",
  "function": "Relative clause",
  "sentences": ["Many cities have introduced bike lanes.", "This has reduced traffic in the centre."],
  "answer": ["Many cities", "have introduced", "bike lanes,", "which", "has reduced", "traffic in the centre."],
  "prefilled": 1,
  "distractors": ["because", "so"],
  "hint": "Use \"which\" after a comma to refer back to the whole first idea.",
  "level": 1
}
```

## Fields

- `id`: `<category>_<3-digit number>`, unique, sequential.
- `connector`: the linking word being practised, written exactly as it appears in
  the answer chunk but in lower case without punctuation (e.g. `as a result`,
  `which`, `not only ... but also`). It must appear in the joined answer.
- `function`: 1-3 words naming the job (e.g. "Relative clause", "Contrast",
  "Result", "Concession", "Condition", "Purpose", "Adding a point").
- `sentences`: exactly 2 short, simple, complete sentences (each ends with "."),
  4-12 words each. They give the meaning; the answer may adjust words slightly
  (e.g. drop "This", change a pronoun), but must keep the same meaning.
- `answer`: 4-7 chunks. `" ".join(answer)` must be the complete, correct
  combined sentence:
  - First chunk starts with a capital letter. Last chunk ends with ".".
  - Punctuation stays attached to the chunk before it ("bike lanes," "sharply;").
  - The connector is its own chunk, with its punctuation ("which", "However,",
    "as a result,", "Although"). For two-part connectors ("not only ... but also",
    "both ... and") each part is its own chunk.
  - Each chunk is at most 30 characters.
  - Every chunk has ONE possible position. Never make two chunks that could swap
    and still be correct English (e.g. two time/place phrases, two adjectives,
    two items of a list). Keep phrases like "in 2010" inside a bigger chunk.
  - No two chunks in the same answer may be identical.
- `prefilled`: 0-2 leading chunks shown already placed. At least 3 chunks must
  remain for the student to place.
- `distractors`: 1-2 chunks that look plausible but are clearly WRONG in this
  sentence: an opposite or unrelated linker (e.g. "because" when the answer needs
  "although"), or a wrong form ("who" for a thing). NEVER a synonym or anything
  that would also produce a correct sentence. Must not equal any answer chunk.
- `hint`: one short sentence (max 120 characters) about the rule or word order.
  No answers given away word for word.
- `level`: 1 (easy), 2 (medium), 3 (harder). Aim for roughly 40% / 40% / 20%.

## Content rules

- IELTS topics: education, environment, technology, health, work, cities,
  transport, crime, tourism, media, family, culture, science, economy, sport,
  food, housing, ageing, globalisation. Vary topics; never repeat a sentence.
- British spelling (centre, programme, organise, behaviour, labour).
- Academic but simple: B1-C1 vocabulary. No slang, no contractions.
- Facts must be safe: use general, uncontroversial statements ("Many cities have
  ...", "Some experts believe ...") or clearly hypothetical data ("In the chart,
  sales rose to 40%"). Never invent precise real-world statistics about real
  countries, companies or people.
- No political, religious, sexual or violent content beyond normal IELTS topics.
- Never use em dashes or en dashes. Use commas, semicolons or full stops.
- Use straight quotes in hints.
- Correct punctuation for each linker:
  - Sentence adverbs joining two clauses: "...; however, ..." OR start the second
    clause as a new chunk after a full stop is NOT allowed (one sentence only), so
    use a semicolon: "Prices rose sharply;" "however," "demand stayed high."
    Or put them at the start of a fronted clause where natural.
  - "which" for whole-clause reference takes a comma before it.
  - Defining relative clauses ("The students who ...") take no commas.
  - Fronted subordinate clauses take a comma ("Although ...," "...").
  - "despite / in spite of / due to / owing to / because of" + noun phrase or -ing.

Validate with: `python3 tool/build_sentence_bank.py --check tool/sentence_src/<category>.json`
