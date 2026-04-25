-- 00009_create_indexes.sql
-- Performance indexes for all tables

-- Boats
CREATE INDEX idx_boats_user_id ON boats (user_id);

-- Documents
CREATE INDEX idx_documents_boat_id_expiry ON documents (boat_id, expiry_date);

-- Trips
CREATE INDEX idx_trips_boat_id_departure ON trips (boat_id, departure_time DESC);

-- Trip tracks
CREATE INDEX idx_trip_tracks_location ON trip_tracks USING GIST (location);
CREATE INDEX idx_trip_tracks_trip_recorded ON trip_tracks (trip_id, recorded_at);

-- Events
CREATE INDEX idx_events_start_date ON events (start_date);
CREATE INDEX idx_events_location ON events USING GIST (location);

-- Notification logs
CREATE INDEX idx_notification_logs_user_doc ON notification_logs (user_id, document_id);
