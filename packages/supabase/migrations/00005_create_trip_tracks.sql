-- 00005_create_trip_tracks.sql
-- GPS breadcrumb trail for each trip

CREATE TABLE trip_tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  speed_knots NUMERIC(5,1),
  heading NUMERIC(5,1),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
