-- AlterTable
ALTER TABLE "nexted_profiles" ADD COLUMN     "home_district" TEXT NOT NULL DEFAULT '';

-- CreateTable
CREATE TABLE "nexted_restrictions" (
    "id" TEXT NOT NULL,
    "university" TEXT NOT NULL,
    "campus" TEXT NOT NULL DEFAULT '',
    "open_campus" TEXT NOT NULL DEFAULT '',
    "kind" TEXT NOT NULL DEFAULT 'partial',
    "levels" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "regions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "except_regions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "subjects" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "intakes" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "note" TEXT NOT NULL DEFAULT '',
    "source" TEXT NOT NULL DEFAULT '',
    "as_of" TIMESTAMPTZ(3) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "nexted_restrictions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "nexted_restrictions_university_idx" ON "nexted_restrictions"("university");
