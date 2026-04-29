-- seed.sql
-- Test data for local development
--
-- IMPORTANT: Replace the user_id placeholder below with a real auth.users UUID
-- after signing up through the Supabase Auth UI or API.
-- You can create a test user via:
--   INSERT INTO auth.users (id, email) VALUES ('...', 'test@navis.app');
-- or use the Supabase dashboard to sign up, then copy the UUID.

-- ─── Placeholder user ID ───────────────────────────────────────────
-- After creating a test user, replace this UUID everywhere below.
-- Example: SELECT id FROM auth.users WHERE email = 'test@navis.app';
DO $$
DECLARE
  test_user_id UUID := '00000000-0000-0000-0000-000000000001';
  boat_1_id    UUID := 'b0000000-0000-0000-0000-000000000001';
  boat_2_id    UUID := 'b0000000-0000-0000-0000-000000000002';
  doc_1_id     UUID := 'd0000000-0000-0000-0000-000000000001';
  doc_2_id     UUID := 'd0000000-0000-0000-0000-000000000002';
  doc_3_id     UUID := 'd0000000-0000-0000-0000-000000000003';
  doc_4_id     UUID := 'd0000000-0000-0000-0000-000000000004';
  trip_1_id    UUID := 'e0000000-0000-0000-0000-000000000001';
  trip_2_id    UUID := 'e0000000-0000-0000-0000-000000000002';
  event_1_id   UUID := 'f0000000-0000-0000-0000-000000000001';
  event_2_id   UUID := 'f0000000-0000-0000-0000-000000000002';
  event_3_id   UUID := 'f0000000-0000-0000-0000-000000000003';
BEGIN

-- Create test user in auth.users
INSERT INTO auth.users (
  id, instance_id, aud, role, email,
  encrypted_password, email_confirmed_at,
  created_at, updated_at,
  confirmation_token, email_change, email_change_token_new,
  recovery_token, phone, phone_change, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  test_user_id,
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'test@navis.app',
  crypt('password123', gen_salt('bf')),
  now(), now(), now(),
  '', '', '', '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"name":"Test User"}'::jsonb
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id, user_id, provider_id, provider,
  identity_data, last_sign_in_at, created_at, updated_at
) VALUES (
  test_user_id, test_user_id, test_user_id::text, 'email',
  jsonb_build_object('sub', test_user_id::text, 'email', 'test@navis.app'),
  now(), now(), now()
) ON CONFLICT DO NOTHING;

-- ─── Boats ─────────────────────────────────────────────────────────
INSERT INTO boats (id, user_id, name, registration, type, length_m, home_port, home_port_location, engine_hours) VALUES
  (boat_1_id, test_user_id, 'Luna Azul', 'ES-MAL-3-1234', 'sailboat', 12.50, 'Palma de Mallorca',
    ST_MakePoint(2.6347, 39.5696)::geography, 342.5),
  (boat_2_id, test_user_id, 'Rayo Veloz', 'ES-BCN-7-5678', 'motorboat', 7.80, 'Port Olimpic Barcelona',
    ST_MakePoint(2.2008, 41.3877)::geography, 128.0);

-- ─── Documents ─────────────────────────────────────────────────────
-- Doc 1: OK (expires in 8 months)
INSERT INTO documents (id, boat_id, user_id, type, expiry_date, notes, alert_days) VALUES
  (doc_1_id, boat_1_id, test_user_id, 'Seguro RC', (CURRENT_DATE + INTERVAL '8 months')::date,
   'Allianz poliza #12345', '{30, 7}');

-- Doc 2: WARNING (expires in 60 days)
INSERT INTO documents (id, boat_id, user_id, type, expiry_date, last_renewal_date, last_renewal_cost, last_renewal_provider, alert_days) VALUES
  (doc_2_id, boat_1_id, test_user_id, 'ITB (Inspeccion Tecnica)', (CURRENT_DATE + INTERVAL '60 days')::date,
   (CURRENT_DATE - INTERVAL '305 days')::date, 185.00, 'Inspecciones Nauticas SL', '{30, 7}');

-- Doc 3: CRITICAL (expires in 15 days)
INSERT INTO documents (id, boat_id, user_id, type, expiry_date, alert_days) VALUES
  (doc_3_id, boat_2_id, test_user_id, 'Licencia de Navegacion', (CURRENT_DATE + INTERVAL '15 days')::date, '{30, 14, 7}');

-- Doc 4: EXPIRED (expired 10 days ago)
INSERT INTO documents (id, boat_id, user_id, type, expiry_date, notes, alert_days) VALUES
  (doc_4_id, boat_2_id, test_user_id, 'Certificado de Navegabilidad', (CURRENT_DATE - INTERVAL '10 days')::date,
   'Necesita renovacion urgente', '{30, 7}');

-- ─── Trips ─────────────────────────────────────────────────────────
-- Trip 1: completed trip
INSERT INTO trips (id, boat_id, user_id, departure_port, arrival_port, departure_time, arrival_time, distance_nm, duration_minutes, engine_hours, fuel_consumed_l, crew_members, weather_conditions, notes, status) VALUES
  (trip_1_id, boat_1_id, test_user_id,
   'Palma de Mallorca', 'Port de Soller',
   (CURRENT_TIMESTAMP - INTERVAL '3 days')::timestamptz,
   (CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '4 hours 30 minutes')::timestamptz,
   28.5, 270, 2.1, NULL,
   ARRAY['Carlos', 'Maria', 'Pedro'],
   '{"wind_speed_kts": 12, "wind_direction": "SW", "sea_state": "moderate", "visibility": "good"}'::jsonb,
   'Great sailing conditions, reached 7kts beam reach',
   'completed');

-- Trip 2: currently recording
INSERT INTO trips (id, boat_id, user_id, departure_port, departure_time, crew_members, status) VALUES
  (trip_2_id, boat_2_id, test_user_id,
   'Port Olimpic Barcelona',
   (CURRENT_TIMESTAMP - INTERVAL '1 hour')::timestamptz,
   ARRAY['Carlos'],
   'recording');

-- ─── Trip Tracks (GPS breadcrumbs for trip 1) ──────────────────────
INSERT INTO trip_tracks (trip_id, lat, lon, speed_knots, heading, recorded_at) VALUES
  (trip_1_id, 39.5696, 2.6347, 0.0, 315.0,
    (CURRENT_TIMESTAMP - INTERVAL '3 days')::timestamptz),
  (trip_1_id, 39.5800, 2.6200, 5.2, 320.0,
    (CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '30 minutes')::timestamptz),
  (trip_1_id, 39.6100, 2.5900, 6.8, 325.0,
    (CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '1 hour')::timestamptz),
  (trip_1_id, 39.6500, 2.5500, 7.1, 330.0,
    (CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '2 hours')::timestamptz),
  (trip_1_id, 39.7000, 2.5100, 6.5, 340.0,
    (CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '3 hours')::timestamptz),
  (trip_1_id, 39.7500, 2.4900, 4.2, 350.0,
    (CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '4 hours')::timestamptz),
  (trip_1_id, 39.7700, 2.4800, 1.0, 0.0,
    (CURRENT_TIMESTAMP - INTERVAL '3 days' + INTERVAL '4 hours 30 minutes')::timestamptz);

-- Track for trip 2 (in progress — just departed)
INSERT INTO trip_tracks (trip_id, lat, lon, speed_knots, heading, recorded_at) VALUES
  (trip_2_id, 41.3877, 2.2008, 0.0, 180.0,
    (CURRENT_TIMESTAMP - INTERVAL '1 hour')::timestamptz),
  (trip_2_id, 41.3800, 2.2050, 8.5, 170.0,
    (CURRENT_TIMESTAMP - INTERVAL '45 minutes')::timestamptz),
  (trip_2_id, 41.3700, 2.2100, 12.3, 165.0,
    (CURRENT_TIMESTAMP - INTERVAL '30 minutes')::timestamptz);

-- ─── Events ────────────────────────────────────────────────────────
INSERT INTO events (id, name, organizer, description, event_type, location_name, location, start_date, end_date, boat_classes, registration_url, is_featured) VALUES
  (event_1_id, 'Copa del Rey Mapfre', 'Real Club Nautico de Palma',
   'One of the most important sailing regattas in the Mediterranean. International fleet racing across multiple classes.',
   'regatta', 'Palma de Mallorca', ST_MakePoint(2.6347, 39.5696)::geography,
   '2026-07-31 09:00:00+02', '2026-08-06 18:00:00+02',
   ARRAY['TP52', 'ClubSwan 50', 'J80', 'ORC'],
   'https://copadelrey.com/inscripcion', true),

  (event_2_id, 'Barcelona Boat Show', 'Fira de Barcelona',
   'Annual exhibition of boats, sailing equipment, and marine technology. Over 700 exhibitors.',
   'exhibition', 'Port Vell, Barcelona', ST_MakePoint(2.1812, 41.3752)::geography,
   '2026-10-08 10:00:00+02', '2026-10-12 20:00:00+02',
   NULL, 'https://salonanautico.com', true),

  (event_3_id, 'Curso PER Intensivo', 'Escuela Nautica Mediterraneo',
   'Curso intensivo de Patron de Embarcaciones de Recreo. Incluye teoria y practicas de navegacion.',
   'course', 'Port Olimpic, Barcelona', ST_MakePoint(2.2008, 41.3877)::geography,
   '2026-06-15 09:00:00+02', '2026-06-22 14:00:00+02',
   NULL, NULL, false);

-- ─── Event Interests ───────────────────────────────────────────────
INSERT INTO event_interests (user_id, event_id) VALUES
  (test_user_id, event_1_id);

END $$;
