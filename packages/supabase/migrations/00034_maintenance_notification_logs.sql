-- 00034_maintenance_notification_logs.sql
-- Tracks sent maintenance-due notifications to prevent duplicates.
-- Written by the Go cron job using service_role key.
-- due_key identifies the concrete due occurrence (next due date or the
-- engine-hours threshold): after servicing, the key changes, so the next
-- season's due state notifies again naturally.

CREATE TABLE maintenance_notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id UUID NOT NULL REFERENCES maintenance_tasks(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  due_key TEXT NOT NULL,
  sent_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, task_id, status, due_key)
);

ALTER TABLE maintenance_notification_logs ENABLE ROW LEVEL SECURITY;
