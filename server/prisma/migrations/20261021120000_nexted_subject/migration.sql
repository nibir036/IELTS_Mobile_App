-- What the student wants to study; the AI course and scholarship search uses it.
ALTER TABLE "nexted_profiles" ADD COLUMN IF NOT EXISTS "subject" TEXT NOT NULL DEFAULT '';
