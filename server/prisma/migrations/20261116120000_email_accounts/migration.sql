-- Gulf (GCC) students sign up with email instead of a phone number.
-- Existing accounts are unchanged: they keep their phone and count as Bangladesh.

-- AlterTable
ALTER TABLE "users" ALTER COLUMN "phone" DROP NOT NULL;
ALTER TABLE "users" ADD COLUMN "email" TEXT;
ALTER TABLE "users" ADD COLUMN "email_verified_at" TIMESTAMPTZ(3);
ALTER TABLE "users" ADD COLUMN "country" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
