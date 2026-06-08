-- Generic dedup log for non-document notifications (regatta reminders,
-- live-event alerts, etc.). One row = "user X already notified about
-- (kind, ref_id, dedup_key)".
CREATE TABLE IF NOT EXISTS sent_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  ref_id TEXT NOT NULL,
  dedup_key TEXT NOT NULL DEFAULT '',
  sent_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, kind, ref_id, dedup_key)
);

CREATE INDEX IF NOT EXISTS idx_sent_notifications_lookup
  ON sent_notifications (user_id, kind, ref_id, dedup_key);
