# Writing course lessons (tool/lessons_src)

`python3 tool/build_lessons.py` builds `assets/content/lessons/<module>.json` from:

* `<module>_stage1.json` - Stage 1, fully hand-written (see `writing_stage1.json`, the reference).
* the module's study guide (`assets/content/<module>_guide.json`), auto-chunked into the
  other stages (see PLANS in build_lessons.py): every lesson is a row of `read` cards.
* `<module>_checks.json` - hand-written extras for those auto lessons.

## Ground rules

1. **Only what the guide says.** Every fact, rule, number and example must come from the
   module's guide text (or be a direct, safe consequence of it). Never invent band
   descriptors, statistics, exam rules or timings. If unsure, leave it out.
2. Questions test the *lesson's own* cards - a student who just read them can answer.
3. One clearly correct answer; distractors plausible but unambiguously wrong per the guide.
4. Bangla (`bn`): natural Bangladeshi Bangla in the same mixed style as
   `assets/content/l10n/bn/<module>.json` (IELTS terms stay in English: band, Task 2,
   paragraph, linking word, cue card …). IELTS sample sentences, answer options that are
   English sentences, and passages stay English only (`{"en": …}` without `bn`).
5. Keep text short: prompts ≤ 30 words, explanations 1–3 sentences (≤ 60 words).
6. Valid JSON, UTF-8. Run `python3 tool/build_lessons.py <module>` - it must finish
   without an assertion error.

## Text values

A string, or `{"en": "...", "bn": "..."}`. `**bold**` works in card bodies.

## Lesson (Stage 1 files)

```json
{"id": "s1_l1", "title": {"en","bn"}, "minutes": 8, "xp": 40,
 "intro": {"en","bn"}, "greeting": {"en","bn"},
 "learned": [{"en","bn"}, …3–5],
 "steps": [ … 6–9 steps … ]}
```
Stage file: `{"id": "s1", "title": {"en","bn"}, "subtitle": {"en","bn"}, "lessons": [4–5 lessons]}`.
Lesson ids: `<stageId>_l<n>`. Good lesson rhythm (like writing_stage1): hook `choice` →
`roadmap` (first lesson of the stage only) → `concepts` or `read` → `choice` → `contrast` →
`choice` → optional `practice` → (first lesson only) nothing else. Completion screen is automatic.

## Step types

* `choice` - `{"type":"choice","title","prompt","passage"?: "English text",
  "options":[{"en","bn"?, "sub"?: {"en","bn"}}, 2–4],"answer": index,
  "right"?: {"en","bn"} (title when correct, default "Correct!"),
  "explain": {"en","bn"}, "bars"?: [{"label","value":0–1,"text"}]}`
* `roadmap` - `{"type":"roadmap","title","items":[{"en","bn"}…],"note":{"en","bn"}}`
* `concepts` (dark screen, tap-through cards) - `{"type":"concepts","title","intro",
  "cards":[{"icon": one of target|link|book|settings|check|layers|swap|play|add|list|doc|chat|forward|clock|flag,
  "title":{"en","bn"},"body":{"en","bn"}} 3–9]}`
* `contrast` - `{"type":"contrast","title","intro","weak":{"label":{"en","bn"},"text":"English"},
  "strong":{"label":{"en","bn"},"text":"English","mark":"a word/phrase from strong.text to underline"},"tip":{"en","bn"}}`
* `read` - `{"type":"read","title":{"en","bn"},"chapter":"<guide chapter id>","from":i,"to":j}` shows guide
  blocks [i, j) (translated automatically). Use it to keep the guide's full detail (tables, word lists).
* `practice` - opens a real screen in the app:
  `{"type":"practice","title","task":{"en","bn"} (what to do),"items":[{"en","bn","minutes"?,"target":"<target key>","args"?:{…}}],"tip":{"en","bn"}}`
  Target keys (see lib/features/home/widgets.dart › homeRouteFor): readingPassage, readingSolution, readingLanding, readingLesson, listeningLanding, listeningResults, listeningLesson, writingSelector, writingGuide, writingCourse, readingGuide, speakingGuide, grammarGuide, writingTask1Editor, writingEditor, writingBandReport, writingTemplate, sentenceBuilder, masterclass, speakingHub, speakingEvaluation, pronunciation, myRecordings, mockResults, mockSystemCheck, diagnosticTest, vocabVault, vocabQuiz, articleTips, scoringCriteria, speakingRoomChat, resourcesHub, targetBand, diagnostic, micPermission, mockLibrary, schedule, analytics, notifications, listeningLibrary, listeningMiniList, readingLibrary, readingBank, readingPracticeTests, cueCardVault, speakingPart13, academicWords, irregularVerbs, phrasalVerbs, idioms, topicVocab, vocabGuide, listeningGuide, writingTests, speakingTests, writingQuestions, speakingQuestions, ideasTopics, writingSampleAnswer, certificates, plans
  Useful args: speakingPart13 `{"part": 1}` · speakingQuestions `{"part": 1|2|3}` ·
  writingQuestions `{"task": 1|2}`. Writing only: `"promptId"` + plan/write/check items (see writing_stage1).
* `sampleFeedback` - writing only.

## Checks file (`<module>_checks.json`)

```json
{"<auto lesson id>": {
   "intro": {"en","bn"},            // one-line cover text: what this lesson gives you
   "learned": [{"en","bn"}, 2–4],   // completion-screen recap
   "checks": [ {choice step…, "after": <insert before this step index; omit = at the end>} 1–3 ]
}}
```
Every auto lesson of the module should get an entry (ids are in assets/content/lessons/<module>.json,
stages after Stage 1). Read that lesson's cards (its `read` steps' chapter + block ranges in the guide)
and ask about them. Place a check right after the card it tests (`after` = index of the next step).
