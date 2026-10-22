# Knowledge for the counsellor (RAG)

Put nextED's own guides here: FAQs, visa steps, country guides, document
checklists, office policies. Formats:

* `.md` / `.txt` - split into ~1200-character chunks (first `# heading` is the title)
* `.json` - a list of `{"question": "...", "answer": "..."}`

On every start the service indexes new or changed files into PostgreSQL
(pgvector) and removes deleted ones. To re-index by hand:

    python -m app.kb.ingest

The counsellor retrieves the closest chunks for each message and prefers
them over general knowledge. This README itself is not indexed.
