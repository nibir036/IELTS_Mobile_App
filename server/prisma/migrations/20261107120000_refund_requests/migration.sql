-- Refund requests for website (bKash) passes: asked for on the IELTS website,
-- decided on the API's /admin/refunds page.
CREATE TABLE "refund_requests" (
    "id" TEXT NOT NULL,
    "payment_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'requested',
    "amount" INTEGER,
    "refund_trx_id" TEXT,
    "decision_note" TEXT,
    "decided_by" TEXT,
    "decided_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "refund_requests_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "refund_requests_payment_id_key" ON "refund_requests"("payment_id");
CREATE INDEX "refund_requests_status_created_at_idx" ON "refund_requests"("status", "created_at");
CREATE INDEX "refund_requests_user_id_idx" ON "refund_requests"("user_id");

ALTER TABLE "refund_requests" ADD CONSTRAINT "refund_requests_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "refund_requests" ADD CONSTRAINT "refund_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
