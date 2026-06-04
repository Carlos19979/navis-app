-- 00016_create_trip_checklists.sql
-- Pre-trip safety checklist. A default item list (seeded data) is copied into a
-- per-trip, editable instance when a trip/regatta is prepared. The checklist is a
-- mandatory gate before recording starts (see trips.checklist_completed_at).

CREATE TABLE checklist_default_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE trip_checklist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  is_checked BOOLEAN NOT NULL DEFAULT false,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER set_trip_checklist_items_updated_at
  BEFORE UPDATE ON trip_checklist_items
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
