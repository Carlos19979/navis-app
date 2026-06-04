-- 00017_rls_and_indexes_groups.sql
-- RLS policies + indexes for groups, membership, regatta RSVP and trip checklists.
--
-- NOTE: the Go API connects as the table owner and performs user_id filtering in
-- every query, so it is the primary enforcement layer. These policies provide
-- defense-in-depth and govern any direct Supabase client access.

-- ───────────────────────────────────────────────
-- Helper functions (SECURITY DEFINER) to break the mutual recursion between
-- groups <-> group_members RLS policies. They run as the owner, bypassing RLS.
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION is_active_group_member(gid UUID, uid UUID)
  RETURNS BOOLEAN
  LANGUAGE sql
  SECURITY DEFINER
  STABLE
  SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = gid AND user_id = uid AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION is_group_owner(gid UUID, uid UUID)
  RETURNS BOOLEAN
  LANGUAGE sql
  SECURITY DEFINER
  STABLE
  SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM groups WHERE id = gid AND owner_id = uid
  );
$$;

CREATE OR REPLACE FUNCTION is_trip_group_member(tid UUID, uid UUID)
  RETURNS BOOLEAN
  LANGUAGE sql
  SECURITY DEFINER
  STABLE
  SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM trips t
    JOIN group_members gm ON gm.group_id = t.group_id
    WHERE t.id = tid AND gm.user_id = uid AND gm.status = 'active'
  );
$$;

-- ───────────────────────────────────────────────
-- GROUPS — public groups are discoverable; private only to owner/members.
-- ───────────────────────────────────────────────
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "groups_select_visible" ON groups
  FOR SELECT USING (
    visibility = 'public'
    OR owner_id = auth.uid()
    OR is_active_group_member(id, auth.uid())
  );

CREATE POLICY "groups_insert_own" ON groups
  FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "groups_update_own" ON groups
  FOR UPDATE USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "groups_delete_own" ON groups
  FOR DELETE USING (owner_id = auth.uid());

-- ───────────────────────────────────────────────
-- GROUP MEMBERS — see your own row; owners see/manage all rows (join requests).
-- ───────────────────────────────────────────────
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "group_members_select" ON group_members
  FOR SELECT USING (
    user_id = auth.uid() OR is_group_owner(group_id, auth.uid())
  );

CREATE POLICY "group_members_insert_own" ON group_members
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "group_members_update_owner" ON group_members
  FOR UPDATE USING (is_group_owner(group_id, auth.uid()))
  WITH CHECK (is_group_owner(group_id, auth.uid()));

CREATE POLICY "group_members_delete" ON group_members
  FOR DELETE USING (
    user_id = auth.uid() OR is_group_owner(group_id, auth.uid())
  );

-- ───────────────────────────────────────────────
-- TRIPS — add group visibility on top of the existing owner-only policies.
-- Group regattas/outings are readable by active members of their group.
-- ───────────────────────────────────────────────
CREATE POLICY "trips_select_group_member" ON trips
  FOR SELECT USING (
    group_id IS NOT NULL AND is_active_group_member(group_id, auth.uid())
  );

-- ───────────────────────────────────────────────
-- TRIP PARTICIPANTS (RSVP) — group members see all RSVPs; manage only their own.
-- ───────────────────────────────────────────────
ALTER TABLE trip_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trip_participants_select" ON trip_participants
  FOR SELECT USING (
    user_id = auth.uid() OR is_trip_group_member(trip_id, auth.uid())
  );

CREATE POLICY "trip_participants_insert_own" ON trip_participants
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "trip_participants_update_own" ON trip_participants
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "trip_participants_delete_own" ON trip_participants
  FOR DELETE USING (user_id = auth.uid());

-- ───────────────────────────────────────────────
-- TRIP CHECKLIST ITEMS — owned by the trip owner (the skipper). Same pattern as
-- trip_tracks: access inherited from the parent trip.
-- ───────────────────────────────────────────────
ALTER TABLE trip_checklist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trip_checklist_items_select_own" ON trip_checklist_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_checklist_items.trip_id AND trips.user_id = auth.uid())
  );

CREATE POLICY "trip_checklist_items_insert_own" ON trip_checklist_items
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_checklist_items.trip_id AND trips.user_id = auth.uid())
  );

CREATE POLICY "trip_checklist_items_update_own" ON trip_checklist_items
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_checklist_items.trip_id AND trips.user_id = auth.uid())
  );

CREATE POLICY "trip_checklist_items_delete_own" ON trip_checklist_items
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_checklist_items.trip_id AND trips.user_id = auth.uid())
  );

-- checklist_default_items: read-only reference data for all authenticated users.
ALTER TABLE checklist_default_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "checklist_default_items_select_all" ON checklist_default_items
  FOR SELECT USING (true);

-- ───────────────────────────────────────────────
-- INDEXES
-- ───────────────────────────────────────────────
CREATE INDEX idx_groups_owner ON groups (owner_id);
CREATE INDEX idx_groups_visibility ON groups (visibility);
CREATE INDEX idx_group_members_user ON group_members (user_id);
CREATE INDEX idx_group_members_group_status ON group_members (group_id, status);
CREATE INDEX idx_trips_group_id ON trips (group_id) WHERE group_id IS NOT NULL;
CREATE INDEX idx_trip_participants_trip ON trip_participants (trip_id);
CREATE INDEX idx_trip_checklist_items_trip ON trip_checklist_items (trip_id, position);
