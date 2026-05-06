package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// PortRepo implements port.PortRepository using PostgreSQL.
type PortRepo struct {
	pool *pgxpool.Pool
}

// NewPortRepo creates a new PortRepo.
func NewPortRepo(pool *pgxpool.Pool) *PortRepo {
	return &PortRepo{pool: pool}
}

const portColumns = `id, name, ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lon,
	country, port_type, depth_m, facilities, vhf_channel, website, created_at, updated_at`

func scanPort(row pgx.Row) (*domain.Port, error) {
	p := &domain.Port{}
	err := row.Scan(
		&p.ID, &p.Name, &p.Lat, &p.Lon,
		&p.Country, &p.PortType, &p.DepthM, &p.Facilities,
		&p.VHFChannel, &p.Website, &p.CreatedAt, &p.UpdatedAt,
	)
	return p, err
}

func scanPorts(rows pgx.Rows) ([]domain.Port, error) {
	var ports []domain.Port
	for rows.Next() {
		p := domain.Port{}
		if err := rows.Scan(
			&p.ID, &p.Name, &p.Lat, &p.Lon,
			&p.Country, &p.PortType, &p.DepthM, &p.Facilities,
			&p.VHFChannel, &p.Website, &p.CreatedAt, &p.UpdatedAt,
		); err != nil {
			return nil, err
		}
		ports = append(ports, p)
	}
	return ports, rows.Err()
}

// GetByID retrieves a port by ID.
func (r *PortRepo) GetByID(ctx context.Context, id string) (*domain.Port, error) {
	query := `SELECT ` + portColumns + ` FROM ports WHERE id = $1`

	p, err := scanPort(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrPortNotFound
		}
		return nil, fmt.Errorf("getting port %s: %w", id, err)
	}
	return p, nil
}

// NearLocation returns ports within radiusKM of the given coordinates.
func (r *PortRepo) NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Port, string, error) {
	radiusM := radiusKM * 1000

	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + portColumns + ` FROM ports
			WHERE ST_DWithin(location, ST_MakePoint($2, $1)::geography, $3)
			ORDER BY name ASC, id ASC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, lat, lon, radiusM, limit+1)
	} else {
		var cursorName string
		cErr := r.pool.QueryRow(ctx,
			`SELECT name FROM ports WHERE id = $1`, cursor,
		).Scan(&cursorName)
		if cErr != nil {
			return r.NearLocation(ctx, lat, lon, radiusKM, "", limit)
		}

		query := `SELECT ` + portColumns + ` FROM ports
			WHERE ST_DWithin(location, ST_MakePoint($2, $1)::geography, $3)
				AND (name, id) > ($4, $5)
			ORDER BY name ASC, id ASC
			LIMIT $6`
		rows, err = r.pool.Query(ctx, query, lat, lon, radiusM, cursorName, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing ports near %.4f,%.4f: %w", lat, lon, err)
	}
	defer rows.Close()

	ports, err := scanPorts(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning nearby ports: %w", err)
	}

	var nextCursor string
	if len(ports) > limit {
		nextCursor = ports[limit].ID
		ports = ports[:limit]
	}

	return ports, nextCursor, nil
}
