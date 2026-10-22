-- Run in pgAdmin (Query Tool on the AI_counselor database), one block at a time (select it, F5).

-- 1. pgvector installed (0.5 or newer)
SELECT extversion FROM pg_extension WHERE extname = 'vector';

-- 2. What is stored, and does every row have a vector?
SELECT kind, count(*) AS rows, count(embedding) AS with_vector,
       min(vector_dims(embedding)) AS dims
FROM kb_items GROUP BY kind;

SELECT source, count(*) AS chunks, count(embedding) AS with_vector FROM kb_docs GROUP BY source;

-- 3. Variety: if this is 1-2 subjects, every student sees the same rows
SELECT subject, country, level, count(*) FROM kb_items WHERE kind = 'course'
GROUP BY 1, 2, 3 ORDER BY 4 DESC;

-- 4. Vector search by hand: the 5 rows closest to the first nursing row
--    (similarity 1.0 = identical, under ~0.6 = not really related)
SELECT title, country, round((1 - (embedding <=> (
         SELECT embedding FROM kb_items WHERE title ILIKE '%nurs%' LIMIT 1)))::numeric, 3) AS similarity
FROM kb_items WHERE embedding IS NOT NULL
ORDER BY embedding <=> (SELECT embedding FROM kb_items WHERE title ILIKE '%nurs%' LIMIT 1)
LIMIT 5;

-- 5. Personal search is being used: profiles, searches and chat memory per student
SELECT student_id, profile->>'subject' AS subject, profile->>'preferredCountry' AS country,
       embedding IS NOT NULL AS has_vector, updated_at FROM student_profiles ORDER BY updated_at DESC;
SELECT student_id, kind, query, jsonb_array_length(result_ids) AS shown, created_at
FROM student_searches ORDER BY id DESC LIMIT 20;
SELECT student_id, role, left(content, 80) AS content, created_at FROM chat_messages ORDER BY id DESC LIMIT 20;

-- 6. The HNSW indexes exist
SELECT indexname, indexdef FROM pg_indexes WHERE indexdef ILIKE '%hnsw%';

-- 7. Rows research added recently (proves the catalogue grows)
SELECT kind, title, country, updated_at FROM kb_items ORDER BY updated_at DESC LIMIT 15;
