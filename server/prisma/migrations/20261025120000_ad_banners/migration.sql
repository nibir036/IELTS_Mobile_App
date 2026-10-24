-- Ad banners on the home pages (uploaded from the admin page).
CREATE TABLE "ad_banners" (
    "id" TEXT NOT NULL,
    "place" TEXT NOT NULL,
    "title" TEXT NOT NULL DEFAULT '',
    "r2_key" TEXT NOT NULL,
    "link_type" TEXT NOT NULL DEFAULT 'none',
    "link" TEXT NOT NULL DEFAULT '',
    "sort" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "starts_at" TIMESTAMPTZ(3),
    "ends_at" TIMESTAMPTZ(3),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "ad_banners_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ad_banners_place_active_idx" ON "ad_banners"("place", "active");
