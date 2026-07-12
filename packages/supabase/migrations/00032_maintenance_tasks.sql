-- Task-based maintenance: recurring service tasks per boat (oil change, anodes,
-- antifouling, impeller...), each with its own interval by calendar months and/or
-- engine hours. The maintenance tab is the source of truth; readiness derives the
-- next-service signal per task. Replaces the per-boat single interval added in
-- 00031 (now dropped).
CREATE TABLE IF NOT EXISTS maintenance_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boat_id UUID NOT NULL REFERENCES boats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  interval_months INTEGER,        -- nullable
  interval_hours NUMERIC(8,1),    -- nullable; neither set = history-only task
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_maintenance_tasks_boat ON maintenance_tasks(boat_id);

ALTER TABLE maintenance_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "maintenance_tasks_own" ON maintenance_tasks FOR ALL TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Link a service record to a recurring task (nullable: one-off / historical rows
-- stay standalone). Deleting a task keeps its history (task_id -> NULL).
ALTER TABLE maintenance_logs
  ADD COLUMN IF NOT EXISTS task_id UUID REFERENCES maintenance_tasks(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_maintenance_logs_task ON maintenance_logs(task_id);

-- Revert the per-boat single interval (00031) in favour of per-component tasks.
ALTER TABLE boats DROP COLUMN IF EXISTS maintenance_interval_months;
ALTER TABLE boats DROP COLUMN IF EXISTS maintenance_interval_hours;
