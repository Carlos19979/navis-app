-- 00012_fix_trip_tracks_add_stats.sql
-- Fix trip_tracks to use lat/lon columns instead of PostGIS GEOGRAPHY,
-- and add server-computed speed stats to trips.

-- Drop the GIST index on the geography column
DROP INDEX IF EXISTS idx_trip_tracks_location;

-- Add lat/lon columns
ALTER TABLE trip_tracks ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
ALTER TABLE trip_tracks ADD COLUMN IF NOT EXISTS lon DOUBLE PRECISION;

-- Migrate any existing data from geography to lat/lon
UPDATE trip_tracks
SET lat = ST_Y(location::geometry),
    lon = ST_X(location::geometry)
WHERE location IS NOT NULL AND lat IS NULL;

-- Make lat/lon NOT NULL with defaults for safety
ALTER TABLE trip_tracks ALTER COLUMN lat SET NOT NULL;
ALTER TABLE trip_tracks ALTER COLUMN lon SET NOT NULL;

-- Drop the old geography column
ALTER TABLE trip_tracks DROP COLUMN IF EXISTS location;

-- Recreate spatial index using lat/lon (B-tree composite for range queries)
CREATE INDEX idx_trip_tracks_lat_lon ON trip_tracks (lat, lon);

-- Add server-computed speed stats to trips
ALTER TABLE trips ADD COLUMN IF NOT EXISTS max_speed_knots NUMERIC(5,1);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS avg_speed_knots NUMERIC(5,1);
