-- Personal study plans: the plan itself, and plan fields on study tasks
-- (deep-link args, catalog item, completion ref, reason).

-- CreateTable
CREATE TABLE "study_plans" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "inputs" JSONB NOT NULL,
    "estimate" JSONB NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,
    "filled_until" DATE,
    "paused_until" DATE,
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "study_plans_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "study_tasks" ADD COLUMN     "args" JSONB,
ADD COLUMN     "plan_id" TEXT,
ADD COLUMN     "item_id" TEXT,
ADD COLUMN     "ref" TEXT,
ADD COLUMN     "reason" TEXT,
ADD COLUMN     "removed_at" TIMESTAMPTZ(3);

-- CreateIndex
CREATE INDEX "study_plans_user_id_status_idx" ON "study_plans"("user_id", "status");

-- CreateIndex
CREATE INDEX "study_tasks_plan_id_date_idx" ON "study_tasks"("plan_id", "date");

-- AddForeignKey
ALTER TABLE "study_plans" ADD CONSTRAINT "study_plans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "study_tasks" ADD CONSTRAINT "study_tasks_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "study_plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;
