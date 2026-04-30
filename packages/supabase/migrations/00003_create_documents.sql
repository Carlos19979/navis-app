-- 00003_create_documents.sql
-- Boat documents with computed expiry status

CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  boat_id UUID NOT NULL REFERENCES boats(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  custom_name TEXT,
  expiry_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'ok',
  photo_url TEXT,
  notes TEXT,
  last_renewal_date DATE,
  last_renewal_cost NUMERIC(10,2),
  last_renewal_provider TEXT,
  alert_days INTEGER[] DEFAULT '{30, 7}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION compute_document_status()
RETURNS TRIGGER AS $$
BEGIN
  NEW.status := CASE
    WHEN NEW.expiry_date < CURRENT_DATE THEN 'expired'
    WHEN NEW.expiry_date < CURRENT_DATE + INTERVAL '30 days' THEN 'critical'
    WHEN NEW.expiry_date < CURRENT_DATE + INTERVAL '90 days' THEN 'warning'
    ELSE 'ok'
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_document_status
  BEFORE INSERT OR UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION compute_document_status();

CREATE TRIGGER set_documents_updated_at
  BEFORE UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
