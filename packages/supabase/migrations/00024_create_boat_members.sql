-- Shared access to a boat for crew / co-owners. The boat's owner stays in
-- boats.user_id; boat_members grants additional people read access.
CREATE TABLE IF NOT EXISTS boat_members (
  boat_id UUID NOT NULL REFERENCES boats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('viewer', 'editor')),
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (boat_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_boat_members_user ON boat_members(user_id);

-- Invite code per boat (so an owner can share access).
ALTER TABLE boats ADD COLUMN IF NOT EXISTS share_code TEXT UNIQUE;

ALTER TABLE boat_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "boat_members_read" ON boat_members FOR SELECT TO authenticated
  USING (user_id = auth.uid()
    OR boat_id IN (SELECT id FROM boats WHERE user_id = auth.uid()));
