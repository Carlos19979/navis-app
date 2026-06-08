-- Live coverage links for events (e.g. YouTube live, official trackers).
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS stream_url TEXT,
  ADD COLUMN IF NOT EXISTS tracking_url TEXT;
