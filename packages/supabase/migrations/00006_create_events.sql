-- 00006_create_events.sql
-- Nautical events (regattas, meetups, etc.) and user interest tracking

CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  organizer TEXT NOT NULL,
  organizer_logo_url TEXT,
  description TEXT,
  event_type TEXT NOT NULL CHECK (event_type IN ('regatta', 'cruise', 'meetup', 'exhibition', 'course', 'other')),
  location_name TEXT NOT NULL,
  location GEOGRAPHY(POINT, 4326),
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ,
  boat_classes TEXT[],
  registration_url TEXT,
  documents_url TEXT,
  is_featured BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE event_interests (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, event_id)
);

CREATE TRIGGER set_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
