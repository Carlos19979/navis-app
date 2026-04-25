-- 00008_create_rls_policies.sql
-- Row Level Security policies for all tables

-- ───────────────────────────────────────────────
-- BOATS — users manage their own boats
-- ───────────────────────────────────────────────
ALTER TABLE boats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "boats_select_own" ON boats
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "boats_insert_own" ON boats
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "boats_update_own" ON boats
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "boats_delete_own" ON boats
  FOR DELETE USING (auth.uid() = user_id);

-- ───────────────────────────────────────────────
-- DOCUMENTS — users manage their own documents
-- ───────────────────────────────────────────────
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "documents_select_own" ON documents
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "documents_insert_own" ON documents
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "documents_update_own" ON documents
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "documents_delete_own" ON documents
  FOR DELETE USING (auth.uid() = user_id);

-- ───────────────────────────────────────────────
-- TRIPS — users manage their own trips
-- ───────────────────────────────────────────────
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trips_select_own" ON trips
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "trips_insert_own" ON trips
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "trips_update_own" ON trips
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "trips_delete_own" ON trips
  FOR DELETE USING (auth.uid() = user_id);

-- ───────────────────────────────────────────────
-- TRIP TRACKS — users manage tracks for their trips
-- ───────────────────────────────────────────────
ALTER TABLE trip_tracks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trip_tracks_select_own" ON trip_tracks
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM trips WHERE trips.id = trip_tracks.trip_id AND trips.user_id = auth.uid()
    )
  );

CREATE POLICY "trip_tracks_insert_own" ON trip_tracks
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM trips WHERE trips.id = trip_tracks.trip_id AND trips.user_id = auth.uid()
    )
  );

CREATE POLICY "trip_tracks_delete_own" ON trip_tracks
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM trips WHERE trips.id = trip_tracks.trip_id AND trips.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- EVENTS — everyone can read, only service_role writes
-- ───────────────────────────────────────────────
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "events_select_all" ON events
  FOR SELECT USING (true);

-- No INSERT/UPDATE/DELETE policies for anon/authenticated.
-- Only service_role (bypasses RLS) can manage events.

-- ───────────────────────────────────────────────
-- EVENT INTERESTS — users manage their own interests
-- ───────────────────────────────────────────────
ALTER TABLE event_interests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "event_interests_select_own" ON event_interests
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "event_interests_insert_own" ON event_interests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "event_interests_delete_own" ON event_interests
  FOR DELETE USING (auth.uid() = user_id);

-- ───────────────────────────────────────────────
-- NOTIFICATION LOGS — service_role only (no user policies)
-- ───────────────────────────────────────────────
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- No policies: only the Go cron job with service_role key
-- can read/write notification_logs.
