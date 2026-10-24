-- Which exam a transcript or certificate is for: ssc | hsc | bachelors | masters.
ALTER TABLE "nexted_documents" ADD COLUMN "level" TEXT NOT NULL DEFAULT '';
