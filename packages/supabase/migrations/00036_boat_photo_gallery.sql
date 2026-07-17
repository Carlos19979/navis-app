-- Per-boat photo gallery: extra photos beyond the single photo_url cover.
-- Free keeps just the cover (GalleryLimit=1); Pro may add gallery extras
-- (GalleryLimit=10, cover included) — enforced in the Go service.
ALTER TABLE boats
  ADD COLUMN IF NOT EXISTS photo_urls TEXT[] NOT NULL DEFAULT '{}';
