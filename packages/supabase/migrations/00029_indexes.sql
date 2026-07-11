-- Composite indexes matching the cursor-paginated List queries, which order by
-- (created_at DESC, id) scoped to a user or boat. The existing single-column
-- indexes (idx_boats_user_id, etc.) force a sort per page; these cover the
-- scan and the order.

CREATE INDEX IF NOT EXISTS idx_boats_user_created
  ON boats (user_id, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_trips_user_created
  ON trips (user_id, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_documents_boat_created
  ON documents (boat_id, created_at DESC, id);

-- The user-wide documents listing (GDPR export, expiry sweep per user) had no
-- user_id index at all.
CREATE INDEX IF NOT EXISTS idx_documents_user_created
  ON documents (user_id, created_at DESC, id);

-- Superseded by idx_boats_user_created (same leading column).
DROP INDEX IF EXISTS idx_boats_user_id;
