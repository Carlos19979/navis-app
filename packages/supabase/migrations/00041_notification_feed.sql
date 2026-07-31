-- Notification feed + per-category opt-out.
--
-- Until now a notification existed only as a Novu trigger: if the push was
-- missed (permission denied, Firebase not configured, app uninstalled) the
-- event was gone for good and there was nothing for the app's bell icon to
-- show. This stores every delivered notification so it can be listed, counted
-- and marked as read.
--
-- `category` is the Novu workflow the notification was delivered through
-- (notifications are grouped by domain into five workflows), which doubles as
-- the user-facing preference axis.

CREATE TABLE IF NOT EXISTS notifications (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  category   text NOT NULL CHECK (category IN (
               'reminders', 'regatta-updates', 'group-updates',
               'boat-activity', 'event-live')),
  title      text NOT NULL,
  body       text NOT NULL DEFAULT '',
  -- Deep-link target for the tap, mirroring the Novu payload {type, id}.
  link_type  text NOT NULL DEFAULT '',
  link_id    text NOT NULL DEFAULT '',
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Feed page: (user, created_at DESC, id DESC) is the keyset order the list
-- endpoint pages through.
CREATE INDEX IF NOT EXISTS notifications_feed
  ON notifications (user_id, created_at DESC, id DESC);

-- Badge count: partial index so counting unread stays cheap as history grows.
CREATE INDEX IF NOT EXISTS notifications_unread
  ON notifications (user_id) WHERE read_at IS NULL;

-- Opt-out is stored as the exception: one row = "this user muted this
-- category". Absence means enabled, so new users need no seeding and a new
-- category ships enabled by default.
CREATE TABLE IF NOT EXISTS notification_mutes (
  user_id    uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  category   text NOT NULL CHECK (category IN (
               'reminders', 'regatta-updates', 'group-updates',
               'boat-activity', 'event-live')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category)
);

-- RLS: the Go API writes with the service role, so the client needs READ only.
-- Granting writes here would let the app's own Supabase client forge bell
-- entries, flip read_at or delete history, bypassing the API — the same reason
-- 00028 made sent_notifications select-only.
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_mutes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_own ON notifications;
DROP POLICY IF EXISTS notification_mutes_own ON notification_mutes;

CREATE POLICY notifications_own ON notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY notification_mutes_own ON notification_mutes
  FOR SELECT TO authenticated USING (user_id = auth.uid());
