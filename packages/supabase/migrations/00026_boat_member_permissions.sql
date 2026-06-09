-- Granular per-member permissions for shared boats (replaces the coarse role).
ALTER TABLE boat_members ADD COLUMN IF NOT EXISTS can_record_trips boolean NOT NULL DEFAULT false;
ALTER TABLE boat_members ADD COLUMN IF NOT EXISTS can_manage_expenses boolean NOT NULL DEFAULT false;
ALTER TABLE boat_members ADD COLUMN IF NOT EXISTS can_manage_maintenance boolean NOT NULL DEFAULT false;
ALTER TABLE boat_members ADD COLUMN IF NOT EXISTS can_view_documents boolean NOT NULL DEFAULT true;
ALTER TABLE boat_members ADD COLUMN IF NOT EXISTS can_manage_documents boolean NOT NULL DEFAULT false;

-- Backfill: existing 'editor' members keep their write abilities.
UPDATE boat_members
  SET can_record_trips = true, can_manage_expenses = true, can_manage_maintenance = true
  WHERE role = 'editor';
