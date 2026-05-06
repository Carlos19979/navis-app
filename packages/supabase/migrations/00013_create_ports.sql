-- 00013_create_ports.sql
-- Reference table of ports, marinas, and anchorages for nearby-ports queries.

CREATE TABLE ports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  country TEXT NOT NULL,
  port_type TEXT NOT NULL CHECK (port_type IN ('marina', 'anchorage', 'fuel', 'commercial', 'fishing', 'other')),
  depth_m NUMERIC(4,1),
  facilities TEXT[],
  vhf_channel TEXT,
  website TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER set_ports_updated_at
  BEFORE UPDATE ON ports
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX idx_ports_location ON ports USING GIST (location);

-- Public read access; only service_role can manage ports.
ALTER TABLE ports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ports_select_all" ON ports
  FOR SELECT USING (true);
