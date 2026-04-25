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

// BoatRepo implements port.BoatRepository using PostgreSQL.
type BoatRepo struct {
	pool *pgxpool.Pool
}

// NewBoatRepo creates a new BoatRepo.
func NewBoatRepo(pool *pgxpool.Pool) *BoatRepo {
	return &BoatRepo{pool: pool}
}

// Create inserts a new boat and returns the created record.
func (r *BoatRepo) Create(ctx context.Context, boat *domain.Boat) (*domain.Boat, error) {
	query := `
		INSERT INTO boats (user_id, name, registration, type, length_m, home_port, home_port_location, photo_url, engine_hours)
		VALUES ($1, $2, $3, $4, $5, $6,
			CASE WHEN $7::float8 IS NOT NULL AND $8::float8 IS NOT NULL
				THEN ST_MakePoint($8, $7)
				ELSE NULL
			END,
			$9, $10)
		RETURNING id, user_id, name, registration, type, length_m, home_port,
			ST_Y(home_port_location::geometry) AS home_port_lat,
			ST_X(home_port_location::geometry) AS home_port_lon,
			photo_url, engine_hours, created_at, updated_at`

	b := &domain.Boat{}
	err := r.pool.QueryRow(ctx, query,
		boat.UserID, boat.Name, boat.Registration, boat.Type, boat.LengthM,
		boat.HomePort, boat.HomePortLat, boat.HomePortLon,
		boat.PhotoURL, boat.EngineHours,
	).Scan(
		&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
		&b.HomePort, &b.HomePortLat, &b.HomePortLon,
		&b.PhotoURL, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("inserting boat: %w", err)
	}

	return b, nil
}

// GetByID retrieves a boat by ID, scoped to the given user.
func (r *BoatRepo) GetByID(ctx context.Context, userID, id string) (*domain.Boat, error) {
	query := `
		SELECT id, user_id, name, registration, type, length_m, home_port,
			ST_Y(home_port_location::geometry) AS home_port_lat,
			ST_X(home_port_location::geometry) AS home_port_lon,
			photo_url, engine_hours, created_at, updated_at
		FROM boats
		WHERE user_id = $1 AND id = $2`

	b := &domain.Boat{}
	err := r.pool.QueryRow(ctx, query, userID, id).Scan(
		&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
		&b.HomePort, &b.HomePortLat, &b.HomePortLon,
		&b.PhotoURL, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrBoatNotFound
		}
		return nil, fmt.Errorf("getting boat %s: %w", id, err)
	}

	return b, nil
}

// List returns a paginated list of boats for a user using cursor-based pagination.
// The cursor is the ID of the last item. We fetch limit+1 to determine if there is a next page.
func (r *BoatRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `
			SELECT id, user_id, name, registration, type, length_m, home_port,
				ST_Y(home_port_location::geometry) AS home_port_lat,
				ST_X(home_port_location::geometry) AS home_port_lon,
				photo_url, engine_hours, created_at, updated_at
			FROM boats
			WHERE user_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, userID, limit+1)
	} else {
		// Fetch the created_at of the cursor to paginate accurately.
		var cursorCreatedAt time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT created_at FROM boats WHERE id = $1`, cursor,
		).Scan(&cursorCreatedAt)
		if cErr != nil {
			// If cursor is invalid, just start from the beginning.
			return r.List(ctx, userID, "", limit)
		}

		query := `
			SELECT id, user_id, name, registration, type, length_m, home_port,
				ST_Y(home_port_location::geometry) AS home_port_lat,
				ST_X(home_port_location::geometry) AS home_port_lon,
				photo_url, engine_hours, created_at, updated_at
			FROM boats
			WHERE user_id = $1 AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, userID, cursorCreatedAt, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing boats: %w", err)
	}
	defer rows.Close()

	boats := make([]domain.Boat, 0, limit)
	for rows.Next() {
		var b domain.Boat
		if err := rows.Scan(
			&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
			&b.HomePort, &b.HomePortLat, &b.HomePortLon,
			&b.PhotoURL, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
		); err != nil {
			return nil, "", fmt.Errorf("scanning boat row: %w", err)
		}
		boats = append(boats, b)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("iterating boat rows: %w", err)
	}

	var nextCursor string
	if len(boats) > limit {
		nextCursor = boats[limit].ID
		boats = boats[:limit]
	}

	return boats, nextCursor, nil
}

// Update modifies an existing boat and returns the updated record.
func (r *BoatRepo) Update(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error) {
	query := `
		UPDATE boats
		SET name = $3, registration = $4, type = $5, length_m = $6, home_port = $7,
			home_port_location = CASE WHEN $8::float8 IS NOT NULL AND $9::float8 IS NOT NULL
				THEN ST_MakePoint($9, $8)
				ELSE NULL
			END,
			photo_url = $10, engine_hours = $11, updated_at = now()
		WHERE user_id = $1 AND id = $2
		RETURNING id, user_id, name, registration, type, length_m, home_port,
			ST_Y(home_port_location::geometry) AS home_port_lat,
			ST_X(home_port_location::geometry) AS home_port_lon,
			photo_url, engine_hours, created_at, updated_at`

	b := &domain.Boat{}
	err := r.pool.QueryRow(ctx, query,
		userID, boat.ID, boat.Name, boat.Registration, boat.Type, boat.LengthM,
		boat.HomePort, boat.HomePortLat, boat.HomePortLon,
		boat.PhotoURL, boat.EngineHours,
	).Scan(
		&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
		&b.HomePort, &b.HomePortLat, &b.HomePortLon,
		&b.PhotoURL, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrBoatNotFound
		}
		return nil, fmt.Errorf("updating boat %s: %w", boat.ID, err)
	}

	return b, nil
}

// Delete removes a boat by ID, scoped to the given user.
func (r *BoatRepo) Delete(ctx context.Context, userID, id string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM boats WHERE user_id = $1 AND id = $2`, userID, id)
	if err != nil {
		return fmt.Errorf("deleting boat %s: %w", id, err)
	}
	if result.RowsAffected() == 0 {
		return domain.ErrBoatNotFound
	}
	return nil
}
