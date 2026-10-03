# Bangla meanings for the Resources word lists (IELTS AI by nextED)

Students see the English meaning of a word, idiom, phrasal verb, linking word or topic term; under it the app shows
your **easy Bangla meaning** so a weak student instantly understands it.

Input:  /home/claude/app/seed/staging/l10n/resources/src/batch_NN.json  — list of {id, word, pos, en}
        (word = the English headword/phrase, pos = its type, en = the English meaning).
Output: /home/claude/app/seed/staging/l10n/resources/bn/batch_NN.json   — ONE JSON object {id: "Bangla meaning"}
        with every id of the batch (write with Python: json.dump(..., ensure_ascii=False, indent=0)).

How to write each meaning
- Translate the ENGLISH MEANING (en) into short, EASY, everyday Bangla (চলিত ভাষা, the words a Dhaka student uses).
  Not a dictionary register; prefer "খুব সহজ", "দাম বাড়ানো", "চিন্তা করা" over bookish/Sanskrit-heavy words.
- Make sure the Bangla matches what the WORD means in context (use word + pos to choose the right sense). For an
  idiom/phrasal verb give its real meaning, never a literal word-by-word translation.
- Length: about as short as the English (usually 2–10 Bangla words). You may add a common Bangla equivalent in
  brackets only if it truly helps, e.g. "খুব সহজ কাজ (পানির মতো সহজ)".
- Keep a common English term in English when Bangla students normally use it (e.g. internet, app, online, bank,
  e-mail, CO2); keep any example English words in quotes as they are.
- No full stop at the end. No English left untranslated except the cases above.
- Every id must appear exactly once; don't change ids; don't add keys.

Check before finishing (Python): the output is a dict, its key set equals the input ids, every value is a
non-empty string containing Bangla letters. Reply with: batch number, count, and up to 3 entries you were unsure of.
