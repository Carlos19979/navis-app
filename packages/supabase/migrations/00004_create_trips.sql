-- 00004_create_trips.sql
-- Trip logbook entries

CREATE TABLE trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boat_id UUID NOT NULL REFERENCES boats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  departure_port TEXT NOT NULL,
  arrival_port TEXT,
  departure_time TIMESTAMPTZ NOT NULL,
  arrival_time TIMESTAMPTZ,
  distance_nm NUMERIC(8,2),
  duration_minutes INTEGER,
  engine_hours NUMERIC(6,1),
  fuel_consumed_l NUMERIC(6,1),
  crew_members TEXT[],
  weather_conditions JSONB,
  notes TEXT,
  photos TEXT[],
  status TEXT DEFAULT 'recording' CHECK (status IN ('recording', 'completed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER set_trips_updated_at
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
