-- Maintenance schedule per boat: a service interval by calendar time and/or by
-- engine hours. Readiness uses this to flag the next service as due/overdue —
-- whichever limit (date or hours) comes first. Both are optional; if neither is
-- set the boat has no plan and readiness keeps flagging maintenance as pending.
ALTER TABLE boats ADD COLUMN IF NOT EXISTS maintenance_interval_months INTEGER;
ALTER TABLE boats ADD COLUMN IF NOT EXISTS maintenance_interval_hours NUMERIC(8, 1);
