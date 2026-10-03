-- Attempts and notifications record when they last changed (used by /v1/sync).

-- AlterTable
ALTER TABLE "attempts" ADD COLUMN     "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- CreateIndex
CREATE INDEX "attempts_user_id_updated_at_idx" ON "attempts"("user_id", "updated_at");

-- CreateIndex
CREATE INDEX "notifications_user_id_updated_at_idx" ON "notifications"("user_id", "updated_at");
