-- Shared-boat coordination: a bookings calendar and expense splitting among
-- co-owners/crew. Why: co-owned boats need to coordinate who has the boat when,
-- and split shared costs. Access follows the existing boat owner/member model;
-- the Go API enforces it in-code (owner connection bypasses RLS), with RLS as
-- defense-in-depth for direct Supabase access.

-- Membership helper (owner OR member), SECURITY DEFINER to avoid recursive RLS
-- across boats/boat_members.
CREATE OR REPLACE FUNCTION public.can_access_boat(bid UUID, uid UUID)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM boats WHERE id = bid AND user_id = uid)
      OR EXISTS (SELECT 1 FROM boat_members WHERE boat_id = bid AND user_id = uid);
$$;
REVOKE ALL ON FUNCTION public.can_access_boat(UUID, UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.can_access_boat(UUID, UUID) TO authenticated;

-- Bookings: reservations of boat time.
CREATE TABLE IF NOT EXISTS bookings (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boat_id    UUID NOT NULL REFERENCES boats(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  starts_at  TIMESTAMPTZ NOT NULL,
  ends_at    TIMESTAMPTZ NOT NULL,
  purpose    TEXT,
  status     TEXT NOT NULL DEFAULT 'confirmed'
             CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bookings_boat ON bookings (boat_id, starts_at DESC);

CREATE TRIGGER set_bookings_updated_at
  BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bookings_select_boat_members" ON bookings
  FOR SELECT TO authenticated USING (can_access_boat(boat_id, auth.uid()));

CREATE POLICY "bookings_write_own" ON bookings
  FOR ALL TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Expense splits: who owes what share of an expense.
CREATE TABLE IF NOT EXISTS expense_splits (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id   UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  share_amount NUMERIC(10, 2) NOT NULL,
  settled_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expense_splits_expense
  ON expense_splits (expense_id);

ALTER TABLE expense_splits ENABLE ROW LEVEL SECURITY;

-- Readable/writable by anyone with access to the parent expense's boat.
CREATE POLICY "expense_splits_boat_members" ON expense_splits
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_splits.expense_id
        AND can_access_boat(e.boat_id, auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM expenses e
      WHERE e.id = expense_splits.expense_id
        AND can_access_boat(e.boat_id, auth.uid())
    )
  );
