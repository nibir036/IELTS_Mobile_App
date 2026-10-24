-- Copies of a student's data written to R2 (profile completion, account deletion).
CREATE TABLE "data_archives" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "r2_key" TEXT NOT NULL,
    "bytes" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "data_archives_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "data_archives_user_id_reason_idx" ON "data_archives"("user_id", "reason");

-- Practice answers kept for model training after an account is deleted (not linked to anyone).
CREATE TABLE "training_samples" (
    "id" TEXT NOT NULL,
    "skill" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "title" TEXT,
    "ref_id" TEXT,
    "band" DOUBLE PRECISION,
    "score" INTEGER,
    "total" INTEGER,
    "duration_sec" INTEGER,
    "data" JSONB,
    "audio" JSONB,
    "attempted_in" DATE,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "training_samples_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "training_samples_skill_kind_idx" ON "training_samples"("skill", "kind");
