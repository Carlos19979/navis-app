-- 00015_extend_trips_for_groups.sql
-- Turn trips into group regattas/outings: group link, scheduling, RSVP, and an
-- expanded lifecycle. Solo trips (group_id IS NULL) keep behaving exactly as before.

ALTER TABLE trips
  ADD COLUMN group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  ADD COLUMN title TEXT,
  ADD COLUMN kind TEXT NOT NULL DEFAULT 'trip' CHECK (kind IN ('trip', 'regatta')),
  ADD COLUMN scheduled_at TIMESTAMPTZ,
  ADD COLUMN checklist_completed_at TIMESTAMPTZ;

-- Expand the trip lifecycle: 'planned' (scheduled, not started) and 'cancelled',
-- in addition to the existing 'recording' and 'completed'.
ALTER TABLE trips DROP CONSTRAINT trips_status_check;
ALTER TABLE trips ADD CONSTRAINT trips_status_check
  CHECK (status IN ('planned', 'recording', 'completed', 'cancelled'));

-- RSVP: group members declare attendance to a scheduled regatta/outing.
CREATE TABLE trip_participants (
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rsvp TEXT NOT NULL DEFAULT 'going' CHECK (rsvp IN ('going', 'maybe', 'not_going')),
  responded_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (trip_id, user_id)
);
