package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// TripRepo implements port.TripRepository using PostgreSQL.
type TripRepo struct {
	pool *pgxpool.Pool
}

// NewTripRepo creates a new TripRepo.
func NewTripRepo(pool *pgxpool.Pool) *TripRepo {
	return &TripRepo{pool: pool}
}

const tripColumns = `id, boat_id, user_id, departure_port, arrival_port, departure_time,
	arrival_time, distance_nm, engine_hours, fuel_consumed_l, duration_minutes,
	crew_members, weather_conditions, notes, photos, status, created_at, updated_at`

// scanTrip scans a single row into a domain.Trip.
func scanTrip(row pgx.Row) (*domain.Trip, error) {
	t := &domain.Trip{}
	err := row.Scan(
		&t.ID, &t.BoatID, &t.UserID, &t.DeparturePort, &t.ArrivalPort,
		&t.DepartureTime, &t.ArrivalTime, &t.DistanceNM, &t.EngineHours,
		&t.FuelConsumedL, &t.DurationMinutes, &t.CrewMembers,
		&t.WeatherConditions, &t.Notes, &t.Photos, &t.Status,
		&t.CreatedAt, &t.UpdatedAt,
	)
	return t, err
}

// Create inserts a new trip and returns the created record.
func (r *TripRepo) Create(ctx context.Context, trip *domain.Trip) (*domain.Trip, error) {
	query := `
		INSERT INTO trips (boat_id, user_id, departure_port, arrival_port, departure_time,
			arrival_time, distance_nm, engine_hours, fuel_consumed_l, duration_minutes,
			crew_members, weather_conditions, notes, photos, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
		RETURNING ` + tripColumns

	t, err := scanTrip(r.pool.QueryRow(ctx, query,
		trip.BoatID, trip.UserID, trip.DeparturePort, trip.ArrivalPort,
		trip.DepartureTime, trip.ArrivalTime, trip.DistanceNM, trip.EngineHours,
		trip.FuelConsumedL, trip.DurationMinutes, trip.CrewMembers,
		trip.WeatherConditions, trip.Notes, trip.Photos, trip.Status,
	))
	if err != nil {
		return nil, fmt.Errorf("inserting trip: %w", err)
	}
	return t, nil
}

// GetByID retrieves a trip by ID, scoped to the given user.
func (r *TripRepo) GetByID(ctx context.Context, userID, id string) (*domain.Trip, error) {
	query := `SELECT ` + tripColumns + ` FROM trips WHERE user_id = $1 AND id = $2`

	t, err := scanTrip(r.pool.QueryRow(ctx, query, userID, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrTripNotFound
		}
		return nil, fmt.Errorf("getting trip %s: %w", id, err)
	}
	return t, nil
}

// List returns a paginated list of trips for a user using cursor-based pagination.
func (r *TripRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Trip, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + tripColumns + ` FROM trips
			WHERE user_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, userID, limit+1)
	} else {
		var cursorCreatedAt time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT created_at FROM trips WHERE id = $1`, cursor,
		).Scan(&cursorCreatedAt)
		if cErr != nil {
			return r.List(ctx, userID, "", limit)
		}

		query := `SELECT ` + tripColumns + ` FROM trips
			WHERE user_id = $1 AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, userID, cursorCreatedAt, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing trips: %w", err)
	}
	defer rows.Close()

	trips := make([]domain.Trip, 0, limit)
	for rows.Next() {
		t := domain.Trip{}
		if err := rows.Scan(
			&t.ID, &t.BoatID, &t.UserID, &t.DeparturePort, &t.ArrivalPort,
			&t.DepartureTime, &t.ArrivalTime, &t.DistanceNM, &t.EngineHours,
			&t.FuelConsumedL, &t.DurationMinutes, &t.CrewMembers,
			&t.WeatherConditions, &t.Notes, &t.Photos, &t.Status,
			&t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, "", fmt.Errorf("scanning trip row: %w", err)
		}
		trips = append(trips, t)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("iterating trip rows: %w", err)
	}

	var nextCursor string
	if len(trips) > limit {
		nextCursor = trips[limit].ID
		trips = trips[:limit]
	}

	return trips, nextCursor, nil
}

// Update modifies an existing trip and returns the updated record.
func (r *TripRepo) Update(ctx context.Context, userID string, trip *domain.Trip) (*domain.Trip, error) {
	query := `
		UPDATE trips
		SET departure_port = $3, arrival_port = $4, departure_time = $5,
			arrival_time = $6, distance_nm = $7, engine_hours = $8,
			fuel_consumed_l = $9, duration_minutes = $10, crew_members = $11,
			weather_conditions = $12, notes = $13, photos = $14,
			status = $15, updated_at = now()
		WHERE user_id = $1 AND id = $2
		RETURNING ` + tripColumns

	t, err := scanTrip(r.pool.QueryRow(ctx, query,
		userID, trip.ID, trip.DeparturePort, trip.ArrivalPort,
		trip.DepartureTime, trip.ArrivalTime, trip.DistanceNM, trip.EngineHours,
		trip.FuelConsumedL, trip.DurationMinutes, trip.CrewMembers,
		trip.WeatherConditions, trip.Notes, trip.Photos, trip.Status,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrTripNotFound
		}
		return nil, fmt.Errorf("updating trip %s: %w", trip.ID, err)
	}
	return t, nil
}

// Delete removes a trip by ID, scoped to the given user.
func (r *TripRepo) Delete(ctx context.Context, userID, id string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM trips WHERE user_id = $1 AND id = $2`, userID, id)
	if err != nil {
		return fmt.Errorf("deleting trip %s: %w", id, err)
	}
	if result.RowsAffected() == 0 {
		return domain.ErrTripNotFound
	}
	return nil
}

// TripTrackRepo implements port.TripTrackRepository using PostgreSQL.
type TripTrackRepo struct {
	pool *pgxpool.Pool
}

// NewTripTrackRepo creates a new TripTrackRepo.
func NewTripTrackRepo(pool *pgxpool.Pool) *TripTrackRepo {
	return &TripTrackRepo{pool: pool}
}

// BatchCreate inserts multiple track points in a single batch.
func (r *TripTrackRepo) BatchCreate(ctx context.Context, tracks []domain.TripTrack) error {
	if len(tracks) == 0 {
		return nil
	}

	batch := &pgx.Batch{}
	query := `INSERT INTO trip_tracks (trip_id, lat, lon, speed_knots, heading, recorded_at)
		VALUES ($1, $2, $3, $4, $5, $6)`

	for _, t := range tracks {
		batch.Queue(query, t.TripID, t.Lat, t.Lon, t.SpeedKnots, t.Heading, t.RecordedAt)
	}

	br := r.pool.SendBatch(ctx, batch)
	defer func() { _ = br.Close() }()

	for range tracks {
		if _, err := br.Exec(); err != nil {
			return fmt.Errorf("inserting track point: %w", err)
		}
	}

	return nil
}

// ListByTrip returns all track points for a trip, ordered by recorded_at.
func (r *TripTrackRepo) ListByTrip(ctx context.Context, tripID string) ([]domain.TripTrack, error) {
	query := `
		SELECT id, trip_id, lat, lon, speed_knots, heading, recorded_at
		FROM trip_tracks
		WHERE trip_id = $1
		ORDER BY recorded_at ASC`

	rows, err := r.pool.Query(ctx, query, tripID)
	if err != nil {
		return nil, fmt.Errorf("listing track points for trip %s: %w", tripID, err)
	}
	defer rows.Close()

	var tracks []domain.TripTrack
	for rows.Next() {
		var t domain.TripTrack
		if err := rows.Scan(
			&t.ID, &t.TripID, &t.Lat, &t.Lon, &t.SpeedKnots, &t.Heading, &t.RecordedAt,
		); err != nil {
			return nil, fmt.Errorf("scanning track point row: %w", err)
		}
		tracks = append(tracks, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating track point rows: %w", err)
	}

	return tracks, nil
}
