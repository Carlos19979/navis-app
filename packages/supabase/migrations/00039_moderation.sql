-- UGC moderation, required by App Store Review Guideline 1.2 for apps with
-- user-generated content (Navis has public groups/clubs and events that other
-- users can discover). Adds the two server-side building blocks:
--   * content_reports — users flag objectionable groups/events for operator review
--   * blocked_users    — users block abusive users; blocked users' public content
--                        is hidden from the blocker's discovery feeds
-- Content filtering at creation time is enforced in the API (pkg/moderation),
-- not the DB.

CREATE TABLE IF NOT EXISTS content_reports (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id    uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  content_type   text NOT NULL CHECK (content_type IN ('group', 'event')),
  content_id     uuid NOT NULL,
  reason         text NOT NULL CHECK (reason IN ('spam', 'offensive', 'harassment', 'other')),
  note           text,
  status         text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'actioned', 'dismissed')),
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- One report per user per piece of content (re-reporting updates nothing).
CREATE UNIQUE INDEX IF NOT EXISTS content_reports_unique
  ON content_reports (reporter_id, content_type, content_id);
CREATE INDEX IF NOT EXISTS content_reports_pending
  ON content_reports (content_type, content_id) WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS blocked_users (
  blocker_id  uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  blocked_id  uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS blocked_users_by_blocker ON blocked_users (blocker_id);

-- RLS: the Go API uses the service role and enforces access itself, but keep
-- rows owner-scoped for defence in depth (consistent with the rest of the schema).
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY content_reports_own ON content_reports
  FOR ALL USING (reporter_id = auth.uid()) WITH CHECK (reporter_id = auth.uid());
CREATE POLICY blocked_users_own ON blocked_users
  FOR ALL USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());
