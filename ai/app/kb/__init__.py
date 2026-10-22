"""The knowledge base: PostgreSQL + pgvector.

Everything the service knows lives here so it is shared by every process
and survives restarts:

  * the catalogue (every course and scholarship ever read, with a vector),
  * knowledge documents (guides, FAQs, policies you add to `knowledge/`),
  * each student's profile vector, search history and counsellor chat.

It is optional. With no DATABASE_URL the service runs exactly as before,
on the JSON files in `data/`.
"""
