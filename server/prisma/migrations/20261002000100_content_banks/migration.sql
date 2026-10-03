-- Content banks, full tests and study guides from the app (seed files 50-71).
-- Existing rows are the demo content: new "source" columns default to 'demo'.

-- DropIndex
DROP INDEX "listening_tests_number_key";

-- AlterTable
ALTER TABLE "reading_passages" ADD COLUMN     "data" JSONB,
ADD COLUMN     "test_id" TEXT;

-- AlterTable
ALTER TABLE "reading_tests" ADD COLUMN     "data" JSONB;

-- AlterTable
ALTER TABLE "listening_sets" ADD COLUMN     "data" JSONB,
ADD COLUMN     "source" TEXT NOT NULL DEFAULT 'demo',
ADD COLUMN     "test_id" TEXT;

-- AlterTable
ALTER TABLE "listening_tests" ADD COLUMN     "data" JSONB,
ADD COLUMN     "kind" TEXT NOT NULL DEFAULT 'full';

-- AlterTable
ALTER TABLE "writing_prompts" ADD COLUMN     "data" JSONB,
ADD COLUMN     "image" TEXT,
ADD COLUMN     "source" TEXT NOT NULL DEFAULT 'demo',
ADD COLUMN     "test_id" TEXT;

-- AlterTable
ALTER TABLE "speaking_part1_topics" ADD COLUMN     "category" TEXT,
ADD COLUMN     "data" JSONB,
ADD COLUMN     "source" TEXT NOT NULL DEFAULT 'demo',
ADD COLUMN     "test_id" TEXT;

-- AlterTable
ALTER TABLE "speaking_cue_cards" ADD COLUMN     "category" TEXT,
ADD COLUMN     "data" JSONB,
ADD COLUMN     "source" TEXT NOT NULL DEFAULT 'demo',
ADD COLUMN     "test_id" TEXT;

-- AlterTable
ALTER TABLE "speaking_part3_sets" ADD COLUMN     "category" TEXT,
ADD COLUMN     "data" JSONB,
ADD COLUMN     "source" TEXT NOT NULL DEFAULT 'demo',
ADD COLUMN     "test_id" TEXT;

-- AlterTable
ALTER TABLE "mock_tests" ADD COLUMN     "data" JSONB,
ADD COLUMN     "kind" TEXT NOT NULL DEFAULT 'full',
ADD COLUMN     "number" INTEGER,
ADD COLUMN     "speaking_test_id" TEXT,
ADD COLUMN     "writing_test_id" TEXT;

-- AlterTable
ALTER TABLE "phrases" ADD COLUMN     "data" JSONB,
ALTER COLUMN "register" DROP NOT NULL;

-- AlterTable
ALTER TABLE "vocabulary_words" ADD COLUMN     "data" JSONB,
ALTER COLUMN "band" SET DATA TYPE DOUBLE PRECISION,
ALTER COLUMN "category" DROP NOT NULL;

-- AlterTable
ALTER TABLE "academic_words" ADD COLUMN     "data" JSONB,
ALTER COLUMN "day" DROP NOT NULL;

-- AlterTable
ALTER TABLE "irregular_verbs" ADD COLUMN     "example" TEXT,
ADD COLUMN     "meaning" TEXT;

-- CreateTable
CREATE TABLE "writing_tests" (
    "id" TEXT NOT NULL,
    "number" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "task1_id" TEXT NOT NULL,
    "task2_id" TEXT NOT NULL,
    "data" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "writing_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "speaking_tests" (
    "id" TEXT NOT NULL,
    "number" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "part1_id" TEXT NOT NULL,
    "cue_card_id" TEXT NOT NULL,
    "part3_ids" TEXT[],
    "data" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "speaking_tests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "content_documents" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "title" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "data" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "content_documents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "writing_tests_number_key" ON "writing_tests"("number");

-- CreateIndex
CREATE UNIQUE INDEX "speaking_tests_number_key" ON "speaking_tests"("number");

-- CreateIndex
CREATE INDEX "content_documents_kind_sort_order_idx" ON "content_documents"("kind", "sort_order");

-- CreateIndex
CREATE INDEX "listening_sets_source_part_idx" ON "listening_sets"("source", "part");

-- CreateIndex
CREATE UNIQUE INDEX "listening_tests_kind_number_key" ON "listening_tests"("kind", "number");

-- CreateIndex
CREATE INDEX "writing_prompts_source_task_idx" ON "writing_prompts"("source", "task");

-- CreateIndex
CREATE INDEX "speaking_part1_topics_source_category_idx" ON "speaking_part1_topics"("source", "category");

-- CreateIndex
CREATE INDEX "speaking_cue_cards_source_category_idx" ON "speaking_cue_cards"("source", "category");

-- CreateIndex
CREATE INDEX "speaking_part3_sets_source_category_idx" ON "speaking_part3_sets"("source", "category");

-- AddForeignKey
ALTER TABLE "writing_tests" ADD CONSTRAINT "writing_tests_task1_id_fkey" FOREIGN KEY ("task1_id") REFERENCES "writing_prompts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "writing_tests" ADD CONSTRAINT "writing_tests_task2_id_fkey" FOREIGN KEY ("task2_id") REFERENCES "writing_prompts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "speaking_tests" ADD CONSTRAINT "speaking_tests_part1_id_fkey" FOREIGN KEY ("part1_id") REFERENCES "speaking_part1_topics"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "speaking_tests" ADD CONSTRAINT "speaking_tests_cue_card_id_fkey" FOREIGN KEY ("cue_card_id") REFERENCES "speaking_cue_cards"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mock_tests" ADD CONSTRAINT "mock_tests_writing_test_id_fkey" FOREIGN KEY ("writing_test_id") REFERENCES "writing_tests"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mock_tests" ADD CONSTRAINT "mock_tests_speaking_test_id_fkey" FOREIGN KEY ("speaking_test_id") REFERENCES "speaking_tests"("id") ON DELETE SET NULL ON UPDATE CASCADE;
