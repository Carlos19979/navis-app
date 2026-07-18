-- Optional litres for fuel expenses, so cost intelligence can derive a real
-- €/L trend (amount already captured; litres were previously lost).
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS liters NUMERIC(10,2);
