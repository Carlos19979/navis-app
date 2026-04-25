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

// EventRepo implements port.EventRepository using PostgreSQL.
type EventRepo struct {
	pool *pgxpool.Pool
}

// NewEventRepo creates a new EventRepo.
func NewEventRepo(pool *pgxpool.Pool) *EventRepo {
	return &EventRepo{pool: pool}
}

const eventColumns = `id, name, organizer, organizer_logo_url, description, event_type,
	location_name, ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lon,
	start_date, end_date, boat_classes, registration_url, documents_url, is_featured,
	created_at, updated_at`

// scanEvent scans a single row into a domain.Event.
func scanEvent(row pgx.Row) (*domain.Event, error) {
	e := &domain.Event{}
	err := row.Scan(
		&e.ID, &e.Name, &e.Organizer, &e.OrganizerLogoURL, &e.Description,
		&e.EventType, &e.LocationName, &e.Lat, &e.Lon,
		&e.StartDate, &e.EndDate, &e.BoatClasses, &e.RegistrationURL, &e.DocumentsURL,
		&e.IsFeatured, &e.CreatedAt, &e.UpdatedAt,
	)
	return e, err
}

// scanEvents scans multiple rows into a slice of domain.Event.
func scanEvents(rows pgx.Rows) ([]domain.Event, error) {
	var events []domain.Event
	for rows.Next() {
		e := domain.Event{}
		if err := rows.Scan(
			&e.ID, &e.Name, &e.Organizer, &e.OrganizerLogoURL, &e.Description,
			&e.EventType, &e.LocationName, &e.Lat, &e.Lon,
			&e.StartDate, &e.EndDate, &e.BoatClasses, &e.RegistrationURL, &e.DocumentsURL,
			&e.IsFeatured, &e.CreatedAt, &e.UpdatedAt,
		); err != nil {
			return nil, err
		}
		events = append(events, e)
	}
	return events, rows.Err()
}

// GetByID retrieves an event by ID.
func (r *EventRepo) GetByID(ctx context.Context, id string) (*domain.Event, error) {
	query := `SELECT ` + eventColumns + ` FROM events WHERE id = $1`

	e, err := scanEvent(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrEventNotFound
		}
		return nil, fmt.Errorf("getting event %s: %w", id, err)
	}
	return e, nil
}

// List returns a paginated list of all events.
func (r *EventRepo) List(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + eventColumns + ` FROM events
			ORDER BY start_date DESC, id DESC
			LIMIT $1`
		rows, err = r.pool.Query(ctx, query, limit+1)
	} else {
		var cursorStartDate time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT start_date FROM events WHERE id = $1`, cursor,
		).Scan(&cursorStartDate)
		if cErr != nil {
			return r.List(ctx, "", limit)
		}

		query := `SELECT ` + eventColumns + ` FROM events
			WHERE (start_date, id) < ($1, $2)
			ORDER BY start_date DESC, id DESC
			LIMIT $3`
		rows, err = r.pool.Query(ctx, query, cursorStartDate, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing events: %w", err)
	}
	defer rows.Close()

	events, err := scanEvents(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning events: %w", err)
	}

	var nextCursor string
	if len(events) > limit {
		nextCursor = events[limit].ID
		events = events[:limit]
	}

	return events, nextCursor, nil
}

// ListUpcoming returns a paginated list of future events ordered by start_date ASC.
func (r *EventRepo) ListUpcoming(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + eventColumns + ` FROM events
			WHERE start_date >= now()
			ORDER BY start_date ASC, id ASC
			LIMIT $1`
		rows, err = r.pool.Query(ctx, query, limit+1)
	} else {
		var cursorStartDate time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT start_date FROM events WHERE id = $1`, cursor,
		).Scan(&cursorStartDate)
		if cErr != nil {
			return r.ListUpcoming(ctx, "", limit)
		}

		query := `SELECT ` + eventColumns + ` FROM events
			WHERE start_date >= now() AND (start_date, id) > ($1, $2)
			ORDER BY start_date ASC, id ASC
			LIMIT $3`
		rows, err = r.pool.Query(ctx, query, cursorStartDate, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing upcoming events: %w", err)
	}
	defer rows.Close()

	events, err := scanEvents(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning upcoming events: %w", err)
	}

	var nextCursor string
	if len(events) > limit {
		nextCursor = events[limit].ID
		events = events[:limit]
	}

	return events, nextCursor, nil
}

// NearLocation returns events within radiusKM of the given coordinates using PostGIS ST_DWithin.
func (r *EventRepo) NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Event, string, error) {
	// ST_DWithin with geography type uses meters, so convert km to meters.
	radiusM := radiusKM * 1000

	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + eventColumns + ` FROM events
			WHERE location IS NOT NULL
				AND ST_DWithin(location, ST_MakePoint($2, $1)::geography, $3)
			ORDER BY start_date ASC, id ASC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, lat, lon, radiusM, limit+1)
	} else {
		var cursorStartDate time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT start_date FROM events WHERE id = $1`, cursor,
		).Scan(&cursorStartDate)
		if cErr != nil {
			return r.NearLocation(ctx, lat, lon, radiusKM, "", limit)
		}

		query := `SELECT ` + eventColumns + ` FROM events
			WHERE location IS NOT NULL
				AND ST_DWithin(location, ST_MakePoint($2, $1)::geography, $3)
				AND (start_date, id) > ($4, $5)
			ORDER BY start_date ASC, id ASC
			LIMIT $6`
		rows, err = r.pool.Query(ctx, query, lat, lon, radiusM, cursorStartDate, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing events near %.4f,%.4f: %w", lat, lon, err)
	}
	defer rows.Close()

	events, err := scanEvents(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning nearby events: %w", err)
	}

	var nextCursor string
	if len(events) > limit {
		nextCursor = events[limit].ID
		events = events[:limit]
	}

	return events, nextCursor, nil
}

// EventInterestRepo implements port.EventInterestRepository using PostgreSQL.
type EventInterestRepo struct {
	pool *pgxpool.Pool
}

// NewEventInterestRepo creates a new EventInterestRepo.
func NewEventInterestRepo(pool *pgxpool.Pool) *EventInterestRepo {
	return &EventInterestRepo{pool: pool}
}

// Toggle inserts interest if it does not exist, or deletes it if it does.
// Returns true if the user is now interested, false if interest was removed.
func (r *EventInterestRepo) Toggle(ctx context.Context, userID, eventID string) (bool, error) {
	// Try to delete first; if no rows affected, insert.
	result, err := r.pool.Exec(ctx,
		`DELETE FROM event_interests WHERE user_id = $1 AND event_id = $2`,
		userID, eventID)
	if err != nil {
		return false, fmt.Errorf("toggling interest for event %s: %w", eventID, err)
	}

	if result.RowsAffected() > 0 {
		// Was interested, now removed.
		return false, nil
	}

	// Not interested yet, add interest.
	_, err = r.pool.Exec(ctx,
		`INSERT INTO event_interests (user_id, event_id) VALUES ($1, $2)
		 ON CONFLICT (user_id, event_id) DO NOTHING`,
		userID, eventID)
	if err != nil {
		return false, fmt.Errorf("inserting interest for event %s: %w", eventID, err)
	}

	return true, nil
}

// IsInterested checks whether a user has expressed interest in an event.
func (r *EventInterestRepo) IsInterested(ctx context.Context, userID, eventID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM event_interests WHERE user_id = $1 AND event_id = $2)`,
		userID, eventID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking interest for event %s: %w", eventID, err)
	}
	return exists, nil
}

// NotificationLogRepo implements port.NotificationLogRepository using PostgreSQL.
type NotificationLogRepo struct {
	pool *pgxpool.Pool
}

// NewNotificationLogRepo creates a new NotificationLogRepo.
func NewNotificationLogRepo(pool *pgxpool.Pool) *NotificationLogRepo {
	return &NotificationLogRepo{pool: pool}
}

// Exists checks if a notification has already been sent for a document at a given alert threshold.
func (r *NotificationLogRepo) Exists(ctx context.Context, userID, documentID string, daysBefore int) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM notification_logs
			WHERE user_id = $1 AND document_id = $2 AND days_before = $3
		)`, userID, documentID, daysBefore).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking notification log: %w", err)
	}
	return exists, nil
}

// Create records that a notification was sent.
func (r *NotificationLogRepo) Create(ctx context.Context, userID, documentID string, daysBefore int) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO notification_logs (user_id, document_id, days_before)
		 VALUES ($1, $2, $3)
		 ON CONFLICT DO NOTHING`,
		userID, documentID, daysBefore)
	if err != nil {
		return fmt.Errorf("creating notification log: %w", err)
	}
	return nil
}
