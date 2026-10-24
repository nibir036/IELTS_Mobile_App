-- Study-abroad profile: any published research? "Yes" | "No".
ALTER TABLE "nexted_profiles" ADD COLUMN "has_publication" TEXT NOT NULL DEFAULT '';

-- An archive R2 refused is kept here instead.
ALTER TABLE "data_archives" ADD COLUMN "data" JSONB;
