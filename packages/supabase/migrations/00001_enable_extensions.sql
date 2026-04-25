-- 00001_enable_extensions.sql
-- Enable required PostgreSQL extensions for Navis

-- PostGIS: geographic data types (GEOGRAPHY) and spatial queries
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

-- uuid-ossp: UUID generation functions (gen_random_uuid is built-in since PG 13,
-- but uuid-ossp provides additional uuid_generate_v4() etc.)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
