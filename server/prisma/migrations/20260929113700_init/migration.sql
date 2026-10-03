-- CreateTable
CREATE TABLE "reading_passages" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'library',
    "part" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "topic" TEXT NOT NULL,
    "difficulty" TEXT NOT NULL,
    "words" INTEGER,
    "paragraphs" JSONB NOT NULL,
    "groups" JSONB NOT NULL,
    "question_count" INTEGER,
    "bank_set" INTEGER,
    "question_type" TEXT,
    "question_type_name" TEXT,
    "question_type_detail" TEXT,
    "lesson" JSONB,
    "passage_note" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "reading_passages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reading_tests" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'full',
    "number" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "passage_ids" TEXT[],
    "question_types" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "question_count" INTEGER,
    "minutes" INTEGER,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "reading_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reading_type_lessons" (
    "id" TEXT NOT NULL,
    "question_type" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "sections" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "reading_type_lessons_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "listening_sets" (
    "id" TEXT NOT NULL,
    "part" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "context" TEXT,
    "audio" TEXT NOT NULL,
    "duration_seconds" INTEGER NOT NULL,
    "speakers" JSONB,
    "transcript" JSONB NOT NULL,
    "groups" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "listening_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "listening_tests" (
    "id" TEXT NOT NULL,
    "number" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "set_ids" TEXT[],
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "listening_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "writing_prompts" (
    "id" TEXT NOT NULL,
    "task" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "topic" TEXT,
    "title" TEXT NOT NULL,
    "prompt" TEXT NOT NULL,
    "chart" JSONB,
    "ideas" JSONB,
    "model_answer" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "writing_prompts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "writing_sample_answers" (
    "prompt_id" TEXT NOT NULL,
    "answers" JSONB NOT NULL,
    "model_why" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "writing_sample_answers_pkey" PRIMARY KEY ("prompt_id")
);

-- CreateTable
CREATE TABLE "writing_templates" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "task" TEXT NOT NULL,
    "sections" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "writing_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sentence_drills" (
    "id" TEXT NOT NULL,
    "instruction" TEXT NOT NULL,
    "connector" TEXT,
    "purpose" TEXT,
    "sentences" JSONB NOT NULL,
    "answer" JSONB NOT NULL,
    "prefilled" INTEGER,
    "bank" JSONB NOT NULL,
    "hint" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "sentence_drills_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "speaking_part1_topics" (
    "id" TEXT NOT NULL,
    "topic" TEXT NOT NULL,
    "questions" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "speaking_part1_topics_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "speaking_cue_cards" (
    "id" TEXT NOT NULL,
    "topic" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "prompt" TEXT NOT NULL,
    "bullets" JSONB NOT NULL,
    "part3" JSONB NOT NULL,
    "sample_notes" JSONB,
    "season" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "speaking_cue_cards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "speaking_part3_sets" (
    "id" TEXT NOT NULL,
    "topic" TEXT NOT NULL,
    "theme" TEXT NOT NULL,
    "cue_card_id" TEXT,
    "questions" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "speaking_part3_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pronunciation_words" (
    "id" TEXT NOT NULL,
    "word" TEXT NOT NULL,
    "ipa" TEXT NOT NULL,
    "part_of_speech" TEXT,
    "syllables" JSONB NOT NULL,
    "tip" TEXT,
    "drill_set" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "pronunciation_words_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mock_tests" (
    "id" TEXT NOT NULL,
    "letter" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "listening_test_id" TEXT NOT NULL,
    "reading_test_id" TEXT NOT NULL,
    "task1_id" TEXT NOT NULL,
    "task2_id" TEXT NOT NULL,
    "speaking" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "mock_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "lessons" (
    "id" TEXT NOT NULL,
    "skill" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "title" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "lessons_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vocab_quizzes" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "level" TEXT NOT NULL,
    "prompt" TEXT,
    "questions" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "vocab_quizzes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "phrases" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "phrase" TEXT NOT NULL,
    "meaning" TEXT NOT NULL,
    "example" TEXT NOT NULL,
    "register" TEXT NOT NULL,
    "topic" TEXT,
    "care" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "phrases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vocabulary_words" (
    "id" TEXT NOT NULL,
    "word" TEXT NOT NULL,
    "part_of_speech" TEXT NOT NULL,
    "definition" TEXT NOT NULL,
    "band" INTEGER NOT NULL,
    "category" TEXT NOT NULL,
    "phonetic" TEXT,
    "example" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "vocabulary_words_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "word_of_the_day" (
    "date" DATE NOT NULL,
    "word_id" TEXT NOT NULL,

    CONSTRAINT "word_of_the_day_pkey" PRIMARY KEY ("date")
);

-- CreateTable
CREATE TABLE "academic_words" (
    "id" TEXT NOT NULL,
    "word" TEXT NOT NULL,
    "part_of_speech" TEXT NOT NULL,
    "meaning" TEXT NOT NULL,
    "day" INTEGER NOT NULL,
    "sublist" INTEGER,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "academic_words_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "irregular_verbs" (
    "id" TEXT NOT NULL,
    "base" TEXT NOT NULL,
    "past" TEXT NOT NULL,
    "participle" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "irregular_verbs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "articles" (
    "id" TEXT NOT NULL,
    "series" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "chip" TEXT,
    "breadcrumb" TEXT,
    "title" TEXT NOT NULL,
    "meta" TEXT,
    "default_tip" INTEGER,
    "tips" JSONB NOT NULL,
    "try_it" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "articles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "band_descriptors" (
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "intro" TEXT,
    "criteria" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "band_descriptors_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "plans" (
    "id" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "name" TEXT NOT NULL,
    "tagline" TEXT,
    "price_monthly" INTEGER NOT NULL,
    "price_yearly" INTEGER NOT NULL,
    "launch_pricing" BOOLEAN NOT NULL DEFAULT false,
    "highlights" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "plans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "plan_features" (
    "id" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "label" TEXT NOT NULL,
    "free" TEXT NOT NULL,
    "pro" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "plan_features_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "certificate_definitions" (
    "id" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "code" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "icon" TEXT,
    "rule" JSONB NOT NULL,
    "unit" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "certificate_definitions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "legal_documents" (
    "id" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "intro" TEXT,
    "sections" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "legal_documents_pkey" PRIMARY KEY ("id","version")
);

-- CreateTable
CREATE TABLE "rooms" (
    "id" TEXT NOT NULL,
    "letter" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "tone" TEXT NOT NULL,
    "topic" TEXT NOT NULL,
    "official" BOOLEAN NOT NULL DEFAULT false,
    "created_by_id" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "app_config" (
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "app_config_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "is_demo" BOOLEAN NOT NULL DEFAULT false,
    "profile" JSONB NOT NULL DEFAULT '{}',
    "phone_verified_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "user_agent" TEXT,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "revoked_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_used_at" TIMESTAMPTZ(3),

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "otp_codes" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "purpose" TEXT NOT NULL,
    "code_hash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "consumed_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attempts" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "skill" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "title" TEXT,
    "ref_id" TEXT,
    "band" DOUBLE PRECISION,
    "score" INTEGER,
    "total" INTEGER,
    "duration_sec" INTEGER,
    "data" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attempts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "skill" TEXT,
    "title" TEXT NOT NULL,
    "body" TEXT,
    "read" BOOLEAN NOT NULL DEFAULT false,
    "target" TEXT,
    "args" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "study_tasks" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "skill" TEXT,
    "kind" TEXT,
    "time" TEXT,
    "duration_min" INTEGER,
    "done" BOOLEAN NOT NULL DEFAULT false,
    "target" TEXT,
    "date" DATE NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "study_tasks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_state" (
    "user_id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "user_state_pkey" PRIMARY KEY ("user_id","key")
);

-- CreateTable
CREATE TABLE "recordings" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "attempt_id" TEXT,
    "r2_key" TEXT NOT NULL,
    "format" TEXT NOT NULL DEFAULT 'wav',
    "duration_ms" INTEGER NOT NULL,
    "bytes" INTEGER,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recordings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "room_messages" (
    "id" TEXT NOT NULL,
    "room_id" TEXT NOT NULL,
    "user_id" TEXT,
    "type" TEXT NOT NULL,
    "text" TEXT,
    "r2_key" TEXT,
    "duration_ms" INTEGER,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "room_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "plan_id" TEXT NOT NULL,
    "period" TEXT,
    "status" TEXT NOT NULL,
    "started_at" TIMESTAMPTZ(3),
    "renews_at" TIMESTAMPTZ(3),
    "provider" TEXT,
    "provider_ref" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "reading_passages_source_part_idx" ON "reading_passages"("source", "part");

-- CreateIndex
CREATE INDEX "reading_passages_question_type_bank_set_idx" ON "reading_passages"("question_type", "bank_set");

-- CreateIndex
CREATE UNIQUE INDEX "reading_tests_kind_number_key" ON "reading_tests"("kind", "number");

-- CreateIndex
CREATE UNIQUE INDEX "reading_type_lessons_question_type_key" ON "reading_type_lessons"("question_type");

-- CreateIndex
CREATE INDEX "listening_sets_part_idx" ON "listening_sets"("part");

-- CreateIndex
CREATE UNIQUE INDEX "listening_tests_number_key" ON "listening_tests"("number");

-- CreateIndex
CREATE INDEX "writing_prompts_task_type_idx" ON "writing_prompts"("task", "type");

-- CreateIndex
CREATE UNIQUE INDEX "mock_tests_letter_key" ON "mock_tests"("letter");

-- CreateIndex
CREATE INDEX "lessons_skill_sort_order_idx" ON "lessons"("skill", "sort_order");

-- CreateIndex
CREATE INDEX "phrases_kind_idx" ON "phrases"("kind");

-- CreateIndex
CREATE INDEX "vocabulary_words_category_idx" ON "vocabulary_words"("category");

-- CreateIndex
CREATE INDEX "academic_words_day_idx" ON "academic_words"("day");

-- CreateIndex
CREATE INDEX "articles_series_sort_order_idx" ON "articles"("series", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "certificate_definitions_code_key" ON "certificate_definitions"("code");

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_token_hash_key" ON "sessions"("token_hash");

-- CreateIndex
CREATE INDEX "sessions_user_id_idx" ON "sessions"("user_id");

-- CreateIndex
CREATE INDEX "otp_codes_phone_purpose_created_at_idx" ON "otp_codes"("phone", "purpose", "created_at");

-- CreateIndex
CREATE INDEX "attempts_user_id_skill_created_at_idx" ON "attempts"("user_id", "skill", "created_at");

-- CreateIndex
CREATE INDEX "attempts_user_id_ref_id_idx" ON "attempts"("user_id", "ref_id");

-- CreateIndex
CREATE INDEX "notifications_user_id_created_at_idx" ON "notifications"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "study_tasks_user_id_date_idx" ON "study_tasks"("user_id", "date");

-- CreateIndex
CREATE INDEX "recordings_user_id_created_at_idx" ON "recordings"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "room_messages_room_id_created_at_idx" ON "room_messages"("room_id", "created_at");

-- CreateIndex
CREATE INDEX "subscriptions_user_id_idx" ON "subscriptions"("user_id");

-- AddForeignKey
ALTER TABLE "reading_passages" ADD CONSTRAINT "reading_passages_question_type_fkey" FOREIGN KEY ("question_type") REFERENCES "reading_type_lessons"("question_type") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "writing_sample_answers" ADD CONSTRAINT "writing_sample_answers_prompt_id_fkey" FOREIGN KEY ("prompt_id") REFERENCES "writing_prompts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "speaking_part3_sets" ADD CONSTRAINT "speaking_part3_sets_cue_card_id_fkey" FOREIGN KEY ("cue_card_id") REFERENCES "speaking_cue_cards"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mock_tests" ADD CONSTRAINT "mock_tests_listening_test_id_fkey" FOREIGN KEY ("listening_test_id") REFERENCES "listening_tests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mock_tests" ADD CONSTRAINT "mock_tests_reading_test_id_fkey" FOREIGN KEY ("reading_test_id") REFERENCES "reading_tests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mock_tests" ADD CONSTRAINT "mock_tests_task1_id_fkey" FOREIGN KEY ("task1_id") REFERENCES "writing_prompts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mock_tests" ADD CONSTRAINT "mock_tests_task2_id_fkey" FOREIGN KEY ("task2_id") REFERENCES "writing_prompts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "word_of_the_day" ADD CONSTRAINT "word_of_the_day_word_id_fkey" FOREIGN KEY ("word_id") REFERENCES "vocabulary_words"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rooms" ADD CONSTRAINT "rooms_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attempts" ADD CONSTRAINT "attempts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "study_tasks" ADD CONSTRAINT "study_tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_state" ADD CONSTRAINT "user_state_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recordings" ADD CONSTRAINT "recordings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recordings" ADD CONSTRAINT "recordings_attempt_id_fkey" FOREIGN KEY ("attempt_id") REFERENCES "attempts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_messages" ADD CONSTRAINT "room_messages_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "room_messages" ADD CONSTRAINT "room_messages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
