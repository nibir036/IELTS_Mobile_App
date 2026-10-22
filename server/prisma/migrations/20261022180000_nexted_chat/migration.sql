-- The AI counsellor conversation, kept per student.
CREATE TABLE "nexted_chat_messages" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "meta" JSONB,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "nexted_chat_messages_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "nexted_chat_messages_user_id_created_at_idx" ON "nexted_chat_messages"("user_id", "created_at");

ALTER TABLE "nexted_chat_messages" ADD CONSTRAINT "nexted_chat_messages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
