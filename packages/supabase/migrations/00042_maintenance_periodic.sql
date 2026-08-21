-- Maintenance rework: the task IS the unit the owner manages.
--
-- Before this, a "task" was a plan (name + interval) and every service was a
-- separate `maintenance_logs` row the client had to create AND link by itself,
-- guessing the link by comparing names. The due date existed nowhere: it was
-- re-derived from "latest log + interval", so a task that had never been
-- serviced had no date at all and could never warn.
--
-- Now a task carries its own `next_due_date`, stored and editable, and expires
-- exactly like a document. A task is either:
--   * periodic  — has an interval, a next due date, and warns/expires;
--   * one_off   — a job with a history and no calendar (a repair).
-- Marking a task done writes its history row and rolls the date forward, so the
-- owner never creates a service one by one.

ALTER TABLE maintenance_tasks
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'periodic',
  ADD COLUMN IF NOT EXISTS next_due_date DATE,
  ADD COLUMN IF NOT EXISTS next_due_hours NUMERIC(8, 1);

-- A task with no interval at all was the old history-only bucket, which is
-- exactly a one-off job. Reclassify before the CHECK below is enforced.
UPDATE maintenance_tasks
   SET kind = 'one_off'
 WHERE interval_months IS NULL
   AND interval_hours IS NULL;

ALTER TABLE maintenance_tasks
  DROP CONSTRAINT IF EXISTS maintenance_tasks_kind_check;
ALTER TABLE maintenance_tasks
  ADD CONSTRAINT maintenance_tasks_kind_check
  CHECK (kind IN ('periodic', 'one_off'));

-- A periodic task without any interval could never roll forward: the invariant
-- that keeps "periodic" meaningful.
ALTER TABLE maintenance_tasks
  DROP CONSTRAINT IF EXISTS maintenance_tasks_periodic_interval_check;
ALTER TABLE maintenance_tasks
  ADD CONSTRAINT maintenance_tasks_periodic_interval_check
  CHECK (
    kind <> 'periodic'
    OR interval_months IS NOT NULL
    OR interval_hours IS NOT NULL
  );

-- Adopt the orphan history. A log used to be allowed to float free of any task,
-- which is what made "servicios" a second thing to manage. First hand each
-- unlinked log to a task of the same name on the same boat...
UPDATE maintenance_logs l
   SET task_id = t.id
  FROM maintenance_tasks t
 WHERE l.task_id IS NULL
   AND t.boat_id = l.boat_id
   AND lower(btrim(t.name)) = lower(btrim(l.type));

-- ...then group whatever is left by what was done and give each group its own
-- one-off task, so every history row lives under a task from here on.
WITH orphan_groups AS (
  SELECT boat_id,
         lower(btrim(type))                              AS key,
         (array_agg(type ORDER BY performed_at DESC))[1] AS name,
         (array_agg(user_id ORDER BY performed_at DESC))[1] AS user_id
    FROM maintenance_logs
   WHERE task_id IS NULL
     AND btrim(type) <> ''
   GROUP BY boat_id, lower(btrim(type))
), adopted AS (
  INSERT INTO maintenance_tasks (boat_id, user_id, name, kind)
  SELECT boat_id, user_id, name, 'one_off' FROM orphan_groups
  RETURNING id, boat_id, lower(btrim(name)) AS key
)
UPDATE maintenance_logs l
   SET task_id = a.id
  FROM adopted a
 WHERE l.task_id IS NULL
   AND l.boat_id = a.boat_id
   AND lower(btrim(l.type)) = a.key;

-- Backfill the due date from the last service, or from the day the task was
-- created when it was never serviced — that second case is the one that used to
-- sit silent as "pending" forever.
UPDATE maintenance_tasks t
   SET next_due_date = (
         COALESCE(
           (SELECT max(l.performed_at)
              FROM maintenance_logs l
             WHERE l.task_id = t.id),
           t.created_at::date
         ) + make_interval(months => t.interval_months)
       )::date
 WHERE t.kind = 'periodic'
   AND t.interval_months IS NOT NULL
   AND t.next_due_date IS NULL;

-- Same for the engine-hours limit: last serviced reading (or the boat's current
-- one, for a task never serviced) plus the interval.
UPDATE maintenance_tasks t
   SET next_due_hours = COALESCE(
         (SELECT l.engine_hours
            FROM maintenance_logs l
           WHERE l.task_id = t.id
             AND l.engine_hours IS NOT NULL
           ORDER BY l.performed_at DESC
           LIMIT 1),
         (SELECT b.engine_hours FROM boats b WHERE b.id = t.boat_id),
         0
       ) + t.interval_hours
 WHERE t.kind = 'periodic'
   AND t.interval_hours IS NOT NULL
   AND t.next_due_hours IS NULL;

-- The maintenance list is read by due date on every open of the tab.
CREATE INDEX IF NOT EXISTS idx_maintenance_tasks_due
  ON maintenance_tasks(next_due_date)
  WHERE kind = 'periodic';
