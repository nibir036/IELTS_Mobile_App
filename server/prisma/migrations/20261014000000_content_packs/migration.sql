-- App content packs (question banks, guides, courses, translations, UI text).
CREATE TABLE "content_packs" (
    "key" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "public" BOOLEAN NOT NULL DEFAULT false,
    "bytes" INTEGER NOT NULL,
    "gz_bytes" INTEGER NOT NULL,
    "gz" BYTEA NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    CONSTRAINT "content_packs_pkey" PRIMARY KEY ("key")
);
