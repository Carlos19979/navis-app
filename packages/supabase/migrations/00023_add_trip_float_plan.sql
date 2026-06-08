-- Float plan: destination, ETA and a shore contact, plus a safety-alert flag.
ALTER TABLE trips ADD COLUMN IF NOT EXISTS destination TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS eta TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS shore_contact_name TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS shore_contact_phone TEXT;
