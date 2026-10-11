-- Devices: at most 2 per account, one signed-in screen at a time.
ALTER TABLE "sessions" ADD COLUMN "device_id" TEXT;
ALTER TABLE "sessions" ADD COLUMN "revoke_reason" TEXT;

CREATE TABLE "devices" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "device_key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "platform" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "locked_until" TIMESTAMPTZ(3),
    "lock_count" INTEGER NOT NULL DEFAULT 0,
    "last_ip" TEXT,
    "first_seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "removed_at" TIMESTAMPTZ(3),
    CONSTRAINT "devices_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "devices_user_id_device_key_key" ON "devices"("user_id", "device_key");
CREATE INDEX "devices_user_id_status_idx" ON "devices"("user_id", "status");

ALTER TABLE "devices" ADD CONSTRAINT "devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
