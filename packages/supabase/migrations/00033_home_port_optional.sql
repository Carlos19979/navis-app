-- Home port is optional: the app UI has always labelled it "(optional)" and
-- the mobile client sends null when empty, but the column was NOT NULL and
-- the API validated it as required, so boat creation without a home port
-- failed with 422. Align DB (and API, in the same change) with the UI.
ALTER TABLE boats ALTER COLUMN home_port DROP NOT NULL;
