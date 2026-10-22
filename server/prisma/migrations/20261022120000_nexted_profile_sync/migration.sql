-- Whether the study-abroad IELTS band was typed by the student ("you") or is
-- taken from the IELTS side (latest mock test, else target band).
ALTER TABLE "nexted_profiles" ADD COLUMN IF NOT EXISTS "ielts_band_source" TEXT NOT NULL DEFAULT '';

-- Bands already typed before this change were entered by the student.
UPDATE "nexted_profiles" SET "ielts_band_source" = 'you' WHERE "ielts_band" <> '' AND "ielts_band_source" = '';
