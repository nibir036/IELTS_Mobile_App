-- The level the student wants to enrol in (Bachelors, Masters, PhD ...).
ALTER TABLE "nexted_profiles" ADD COLUMN IF NOT EXISTS "study_level" TEXT NOT NULL DEFAULT '';
