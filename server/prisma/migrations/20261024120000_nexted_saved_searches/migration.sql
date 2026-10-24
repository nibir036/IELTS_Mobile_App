-- The latest Course matching / Scholarship finder results per student.
CREATE TABLE "nexted_saved_searches" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "query" TEXT NOT NULL DEFAULT '',
    "result" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "nexted_saved_searches_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "nexted_saved_searches_user_id_kind_key" ON "nexted_saved_searches"("user_id", "kind");

ALTER TABLE "nexted_saved_searches" ADD CONSTRAINT "nexted_saved_searches_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
