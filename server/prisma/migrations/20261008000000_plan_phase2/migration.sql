-- Study plan phase 2: weekly adapting and the week's note.

-- AlterTable
ALTER TABLE "study_plans" ADD COLUMN     "adapted_week" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "week_note" JSONB;
