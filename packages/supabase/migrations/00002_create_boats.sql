-- 00002_create_boats.sql
-- User boats — the central entity of the app

CREATE TABLE boats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  registration TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('sailboat', 'motorboat', 'jetski', 'catamaran', 'other')),
  length_m NUMERIC(5,2) NOT NULL,
  home_port TEXT NOT NULL,
  home_port_location GEOGRAPHY(POINT, 4326),
  photo_url TEXT,
  engine_hours NUMERIC(8,1) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-update updated_at on row modification
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_boats_updated_at
  BEFORE UPDATE ON boats
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
