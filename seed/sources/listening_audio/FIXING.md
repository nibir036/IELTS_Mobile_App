# Fitting the Listening bank questions to the recorded audio

The 32 recordings (assets/audio/listening/<CODE>.mp3) are FINAL — they were produced from slightly different
scripts than the question bank, so where they disagree, the QUESTIONS change, never the audio.

Files
- seed/sources/listening_audio/<CODE>.txt — the recording's timestamped transcript (our copy; you may correct
  machine-transcription errors in the TEXT: spellings of names the speaker spells out, "way bridge" →
  "weighbridge", obvious mishearings, punctuation/capitals. Keep every "[m:ss] Speaker:" prefix and the line order.)
- /tmp/claude-0/la/audit/<CODE>.json — the set's current groups + answer key + transcript;
  seed/sources/listening_audio/audit/result_<CODE>.json — the first audit of every question against the audio (ok/differs/missing).
- assets/content/listening_bank.json — the bank (do NOT edit it directly; never run the tool without --check).

How to fix a set: write seed/sources/listening_audio/fixes/<CODE>.json
  {"note": "what changed and why (one or two lines)", "groups": {"g2": <the FULL replacement group object>}}
Only include groups you change; copy the group from the audit packet and edit it. Keep the group's type, its
question numbers, and the exam style (IELTS wording, the instruction line, ONE WORD AND/OR A NUMBER limits —
every answer must fit the word limit). For completion questions set "answer", "answerDisplay" ("8 / eight"
style when a number can be written both ways) and "accepted" (every spelling a marker would accept, incl. the
number in words). For tables keep "rows" in sync with the questions ("(9)___" markers, "row"/"col"). For MCQ /
matching / map keep "options" and give the letter as "answer".
- "differs": change the answer (and the stem/options if needed so exactly one option is right).
- "missing": replace the question with a new one about something the recording DOES say, in the same place in
  the order of the recording (IELTS questions follow the order of the audio), same format and word limit.
- Remove distractor-free giveaways: the answer must be heard, not printed in the stem.
Check: python3 tool/apply_listening_audio.py --check   (reads everything, writes nothing) — every completion
answer of your sets should be found in the recording; any still "not found" must be explained in your note.
