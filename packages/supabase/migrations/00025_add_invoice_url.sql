-- Attach an invoice/receipt (image or PDF URL) to maintenance logs and expenses.
ALTER TABLE maintenance_logs ADD COLUMN IF NOT EXISTS invoice_url TEXT;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS invoice_url TEXT;
