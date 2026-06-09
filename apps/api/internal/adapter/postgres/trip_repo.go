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

const tripColumns = `id, boat_id, user_id, group_id, title, kind, scheduled_at,
	checklist_completed_at, departure_port, arrival_port, departure_time,
	arrival_time, distance_nm, max_speed_knots, avg_speed_knots, engine_hours, fuel_consumed_l,
	duration_minutes, crew_members, weather_conditions, notes, photos, status, share_token,
	destination, eta, shore_contact_name, shore_contact_phone, created_at, updated_at`

// tripScanDest returns the scan destinations for tripColumns, in order.
func tripScanDest(t *domain.Trip) []any {
	return []any{
		&t.ID, &t.BoatID, &t.UserID, &t.GroupID, &t.Title, &t.Kind, &t.ScheduledAt,
		&t.ChecklistCompletedAt, &t.DeparturePort, &t.ArrivalPort, &t.DepartureTime,
		&t.ArrivalTime, &t.DistanceNM, &t.MaxSpeedKnots, &t.AvgSpeedKnots, &t.EngineHours,
		&t.FuelConsumedL, &t.DurationMinutes, &t.CrewMembers, &t.WeatherConditions,
		&t.Notes, &t.Photos, &t.Status, &t.ShareToken,
		&t.Destination, &t.ETA, &t.ShoreContactName, &t.ShoreContactPhone,
		&t.CreatedAt, &t.UpdatedAt,
	}
}

// scanTrip scans a single row into a domain.Trip.
func scanTrip(row pgx.Row) (*domain.Trip, error) {
	t := &domain.Trip{}
	err := row.Scan(tripScanDest(t)...)
	return t, err
}

// scanTrips scans multiple rows into a slice of domain.Trip.
func scanTrips(rows pgx.Rows) ([]domain.Trip, error) {
	trips := make([]domain.Trip, 0)
	for rows.Next() {
		t := domain.Trip{}
		if err := rows.Scan(tripScanDest(&t)...); err != nil {
			return nil, err
		}
		trips = append(trips, t)
	}
	return trips, rows.Err()
}

// Create inserts a new trip and returns the created record.
func (r *TripRepo) Create(ctx context.Context, trip *domain.Trip) (*domain.Trip, error) {
	kind := trip.Kind
	if kind == "" {
		kind = domain.TripKindTrip
	}

	query := `
		INSERT INTO trips (boat_id, user_id, group_id, title, kind, scheduled_at,
			departure_port, arrival_port, departure_time,
			arrival_time, distance_nm, max_speed_knots, avg_speed_knots, engine_hours,
			fuel_consumed_l, duration_minutes, crew_members, weather_conditions, notes, photos, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
		RETURNING ` + tripColumns

	t, err := scanTrip(r.pool.QueryRow(ctx, query,
		trip.BoatID, trip.UserID, trip.GroupID, trip.Title, kind, trip.ScheduledAt,
		trip.DeparturePort, trip.ArrivalPort, trip.DepartureTime,
		trip.ArrivalTime, trip.DistanceNM, trip.MaxSpeedKnots,
		trip.AvgSpeedKnots, trip.EngineHours, trip.FuelConsumedL, trip.DurationMinutes,
		trip.CrewMembers, trip.WeatherConditions, trip.Notes, trip.Photos, trip.Status,
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

// GetByIDUnscoped retrieves a trip by ID without an owner filter. Callers must
// enforce their own authorization (e.g., group membership for regattas).
func (r *TripRepo) GetByIDUnscoped(ctx context.Context, id string) (*domain.Trip, error) {
	query := `SELECT ` + tripColumns + ` FROM trips WHERE id = $1`

	t, err := scanTrip(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrTripNotFound
		}
		return nil, fmt.Errorf("getting trip %s: %w", id, err)
	}
	return t, nil
}

// List returns a paginated list of trips for a user using cursor-based pagination.
func (r *TripRepo) List(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Trip, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		if boatID != "" {
			query := `SELECT ` + tripColumns + ` FROM trips
				WHERE user_id = $1 AND boat_id = $2
				ORDER BY created_at DESC, id DESC
				LIMIT $3`
			rows, err = r.pool.Query(ctx, query, userID, boatID, limit+1)
		} else {
			query := `SELECT ` + tripColumns + ` FROM trips
				WHERE user_id = $1
				ORDER BY created_at DESC, id DESC
				LIMIT $2`
			rows, err = r.pool.Query(ctx, query, userID, limit+1)
		}
	} else {
		var cursorCreatedAt time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT created_at FROM trips WHERE id = $1`, cursor,
		).Scan(&cursorCreatedAt)
		if cErr != nil {
			return r.List(ctx, userID, boatID, "", limit)
		}

		if boatID != "" {
			query := `SELECT ` + tripColumns + ` FROM trips
				WHERE user_id = $1 AND boat_id = $2 AND (created_at, id) < ($3, $4)
				ORDER BY created_at DESC, id DESC
				LIMIT $5`
			rows, err = r.pool.Query(ctx, query, userID, boatID, cursorCreatedAt, cursor, limit+1)
		} else {
			query := `SELECT ` + tripColumns + ` FROM trips
				WHERE user_id = $1 AND (created_at, id) < ($2, $3)
				ORDER BY created_at DESC, id DESC
				LIMIT $4`
			rows, err = r.pool.Query(ctx, query, userID, cursorCreatedAt, cursor, limit+1)
		}
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing trips: %w", err)
	}
	defer rows.Close()

	trips, err := scanTrips(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning trips: %w", err)
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
			arrival_time = $6, distance_nm = $7, max_speed_knots = $8,
			avg_speed_knots = $9, engine_hours = $10, fuel_consumed_l = $11,
			duration_minutes = $12, crew_members = $13, weather_conditions = $14,
			notes = $15, photos = $16, status = $17, title = $18,
			scheduled_at = $19, checklist_completed_at = $20, updated_at = now()
		WHERE user_id = $1 AND id = $2
		RETURNING ` + tripColumns

	t, err := scanTrip(r.pool.QueryRow(ctx, query,
		userID, trip.ID, trip.DeparturePort, trip.ArrivalPort,
		trip.DepartureTime, trip.ArrivalTime, trip.DistanceNM, trip.MaxSpeedKnots,
		trip.AvgSpeedKnots, trip.EngineHours, trip.FuelConsumedL, trip.DurationMinutes,
		trip.CrewMembers, trip.WeatherConditions, trip.Notes, trip.Photos, trip.Status,
		trip.Title, trip.ScheduledAt, trip.ChecklistCompletedAt,
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

// ListByGroup returns a paginated list of a group's trips/regattas, ordered by
// scheduled date (falling back to creation time) descending.
func (r *TripRepo) ListByGroup(ctx context.Context, groupID, cursor string, limit int) ([]domain.Trip, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + tripColumns + ` FROM trips
			WHERE group_id = $1
			ORDER BY COALESCE(scheduled_at, created_at) DESC, id DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, groupID, limit+1)
	} else {
		var cursorTime time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT COALESCE(scheduled_at, created_at) FROM trips WHERE id = $1`, cursor,
		).Scan(&cursorTime)
		if cErr != nil {
			return r.ListByGroup(ctx, groupID, "", limit)
		}

		query := `SELECT ` + tripColumns + ` FROM trips
			WHERE group_id = $1 AND (COALESCE(scheduled_at, created_at), id) < ($2, $3)
			ORDER BY COALESCE(scheduled_at, created_at) DESC, id DESC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, groupID, cursorTime, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing group trips: %w", err)
	}
	defer rows.Close()

	trips, err := scanTrips(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning group trips: %w", err)
	}

	var nextCursor string
	if len(trips) > limit {
		nextCursor = trips[limit].ID
		trips = trips[:limit]
	}
	return trips, nextCursor, nil
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

// ListUpcomingRegattas returns planned group regattas scheduled in [from, to).
func (r *TripRepo) ListUpcomingRegattas(ctx context.Context, from, to time.Time) ([]domain.Trip, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+tripColumns+` FROM trips
		 WHERE kind = 'regatta' AND status = 'planned'
		   AND group_id IS NOT NULL AND scheduled_at IS NOT NULL
		   AND scheduled_at >= $1 AND scheduled_at < $2
		 ORDER BY scheduled_at ASC`,
		from, to)
	if err != nil {
		return nil, fmt.Errorf("listing upcoming regattas: %w", err)
	}
	defer rows.Close()
	return scanTrips(rows)
}

// SetShareToken stores a public share token on a trip owned by the user.
func (r *TripRepo) SetShareToken(ctx context.Context, userID, tripID, token string) error {
	ct, err := r.pool.Exec(ctx,
		`UPDATE trips SET share_token = $1, updated_at = now() WHERE user_id = $2 AND id = $3`,
		token, userID, tripID)
	if err != nil {
		return fmt.Errorf("setting share token for trip %s: %w", tripID, err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrTripNotFound
	}
	return nil
}

// ClearShareToken removes a trip's public share token.
func (r *TripRepo) ClearShareToken(ctx context.Context, userID, tripID string) error {
	ct, err := r.pool.Exec(ctx,
		`UPDATE trips SET share_token = NULL, updated_at = now() WHERE user_id = $1 AND id = $2`,
		userID, tripID)
	if err != nil {
		return fmt.Errorf("clearing share token for trip %s: %w", tripID, err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrTripNotFound
	}
	return nil
}

// GetByShareToken returns a trip by its public share token (no user scoping).
func (r *TripRepo) GetByShareToken(ctx context.Context, token string) (*domain.Trip, error) {
	query := `SELECT ` + tripColumns + ` FROM trips WHERE share_token = $1`
	t, err := scanTrip(r.pool.QueryRow(ctx, query, token))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrTripNotFound
		}
		return nil, fmt.Errorf("getting trip by share token: %w", err)
	}
	return t, nil
}
