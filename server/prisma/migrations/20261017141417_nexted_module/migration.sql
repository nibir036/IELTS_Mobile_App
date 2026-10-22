-- CreateTable
CREATE TABLE "nexted_profiles" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "full_name" TEXT NOT NULL DEFAULT '',
    "email" TEXT NOT NULL DEFAULT '',
    "phone" TEXT NOT NULL DEFAULT '',
    "nationality" TEXT NOT NULL DEFAULT '',
    "highest_level" TEXT NOT NULL DEFAULT '',
    "result" TEXT NOT NULL DEFAULT '',
    "ielts_band" TEXT NOT NULL DEFAULT '',
    "preferred_country" TEXT NOT NULL DEFAULT '',
    "preferred_intake" TEXT NOT NULL DEFAULT '',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "nexted_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nexted_documents" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "r2_key" TEXT NOT NULL,
    "bytes" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'Pending',
    "note" TEXT NOT NULL DEFAULT '',
    "uploaded_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nexted_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nexted_applications" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "ref_id" TEXT NOT NULL DEFAULT '',
    "title" TEXT NOT NULL,
    "provider" TEXT NOT NULL DEFAULT '',
    "status" TEXT NOT NULL DEFAULT 'Submitted',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "nexted_applications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nexted_application_events" (
    "id" TEXT NOT NULL,
    "application_id" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "note" TEXT NOT NULL DEFAULT '',
    "at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nexted_application_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nexted_ai_usage" (
    "user_id" TEXT NOT NULL,
    "used_today" INTEGER NOT NULL DEFAULT 0,
    "quota_date" TEXT NOT NULL DEFAULT '',
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "nexted_ai_usage_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "nexted_courses" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "university" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "level" TEXT NOT NULL DEFAULT '',
    "subject" TEXT NOT NULL DEFAULT '',
    "duration" TEXT NOT NULL DEFAULT '',
    "intake" TEXT NOT NULL DEFAULT '',
    "tuition" TEXT NOT NULL DEFAULT '',
    "min_ielts" DOUBLE PRECISION,
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "nexted_courses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "nexted_scholarships" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "amount" TEXT NOT NULL DEFAULT '',
    "deadline" TEXT NOT NULL DEFAULT '',
    "level" TEXT NOT NULL DEFAULT '',
    "min_ielts" DOUBLE PRECISION,
    "min_gpa" DOUBLE PRECISION,
    "nationalities" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "nexted_scholarships_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "nexted_profiles_user_id_key" ON "nexted_profiles"("user_id");

-- CreateIndex
CREATE INDEX "nexted_documents_user_id_uploaded_at_idx" ON "nexted_documents"("user_id", "uploaded_at");

-- CreateIndex
CREATE UNIQUE INDEX "nexted_applications_reference_key" ON "nexted_applications"("reference");

-- CreateIndex
CREATE INDEX "nexted_applications_user_id_updated_at_idx" ON "nexted_applications"("user_id", "updated_at");

-- CreateIndex
CREATE INDEX "nexted_application_events_application_id_at_idx" ON "nexted_application_events"("application_id", "at");

-- CreateIndex
CREATE INDEX "nexted_courses_country_idx" ON "nexted_courses"("country");

-- CreateIndex
CREATE INDEX "nexted_scholarships_country_idx" ON "nexted_scholarships"("country");

-- AddForeignKey
ALTER TABLE "nexted_profiles" ADD CONSTRAINT "nexted_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nexted_documents" ADD CONSTRAINT "nexted_documents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nexted_applications" ADD CONSTRAINT "nexted_applications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nexted_application_events" ADD CONSTRAINT "nexted_application_events_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "nexted_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "nexted_ai_usage" ADD CONSTRAINT "nexted_ai_usage_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
