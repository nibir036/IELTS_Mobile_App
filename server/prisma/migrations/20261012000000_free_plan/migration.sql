-- Free plan: per-feature allowances and the 48-hour password rule.

-- AlterTable
ALTER TABLE "users" ADD COLUMN "password_changed_at" TIMESTAMPTZ(3);
UPDATE "users" SET "password_changed_at" = "created_at" WHERE "password_changed_at" IS NULL;

-- CreateTable
CREATE TABLE "usage_events" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "feature" TEXT NOT NULL,
    "ref" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "usage_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "usage_events_user_id_feature_idx" ON "usage_events"("user_id", "feature");

-- AddForeignKey
ALTER TABLE "usage_events" ADD CONSTRAINT "usage_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
