-- Public share token for trips (logbook sharing via link).
ALTER TABLE trips ADD COLUMN IF NOT EXISTS share_token TEXT UNIQUE;
