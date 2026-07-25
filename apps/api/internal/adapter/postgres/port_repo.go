package postgres

import (
	"context"
	"errors"
	"fmt"
	"strconv"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
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

	if cursorName, cursorID, ok := pagination.DecodeKeysetText(cursor); ok {
		query := `SELECT ` + portColumns + ` FROM ports
			WHERE ST_DWithin(location, ST_MakePoint($2, $1)::geography, $3)
				AND (name, id) > ($4, $5)
			ORDER BY name ASC, id ASC
			LIMIT $6`
		rows, err = r.pool.Query(ctx, query, lat, lon, radiusM, cursorName, cursorID, limit+1)
	} else {
		query := `SELECT ` + portColumns + ` FROM ports
			WHERE ST_DWithin(location, ST_MakePoint($2, $1)::geography, $3)
			ORDER BY name ASC, id ASC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, lat, lon, radiusM, limit+1)
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
		ports = ports[:limit]
		last := ports[limit-1]
		nextCursor = pagination.EncodeKeysetText(last.Name, last.ID)
	}

	return ports, nextCursor, nil
}

// Search returns ports whose name matches query (ILIKE). When a near point is
// given, results are ordered by geographic distance to it; otherwise
// alphabetically. Both modes keyset-paginate.
func (r *PortRepo) Search(ctx context.Context, query string, nearLat, nearLon *float64, cursor string, limit int) ([]domain.Port, string, error) {
	pattern := "%" + query + "%"
	if nearLat != nil && nearLon != nil {
		return r.searchNear(ctx, pattern, *nearLat, *nearLon, cursor, limit)
	}
	return r.searchByName(ctx, pattern, cursor, limit)
}

// searchByName lists name-matching ports ordered by (name, id).
func (r *PortRepo) searchByName(ctx context.Context, pattern, cursor string, limit int) ([]domain.Port, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursorName, cursorID, ok := pagination.DecodeKeysetText(cursor); ok {
		query := `SELECT ` + portColumns + ` FROM ports
			WHERE name ILIKE $1 AND (name, id) > ($2, $3)
			ORDER BY name ASC, id ASC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, pattern, cursorName, cursorID, limit+1)
	} else {
		query := `SELECT ` + portColumns + ` FROM ports
			WHERE name ILIKE $1
			ORDER BY name ASC, id ASC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, pattern, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("searching ports by name: %w", err)
	}
	defer rows.Close()

	ports, err := scanPorts(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning searched ports: %w", err)
	}

	var nextCursor string
	if len(ports) > limit {
		ports = ports[:limit]
		last := ports[limit-1]
		nextCursor = pagination.EncodeKeysetText(last.Name, last.ID)
	}

	return ports, nextCursor, nil
}

// searchNear lists name-matching ports ordered by distance to (lat, lon). The
// keyset cursor carries the boundary distance (metres) and id.
func (r *PortRepo) searchNear(ctx context.Context, pattern string, lat, lon float64, cursor string, limit int) ([]domain.Port, string, error) {
	const distExpr = `ST_Distance(location, ST_MakePoint($3, $2)::geography)`

	var (
		rows pgx.Rows
		err  error
	)

	if cursorKey, cursorID, ok := pagination.DecodeKeysetText(cursor); ok {
		if d, perr := strconv.ParseFloat(cursorKey, 64); perr == nil {
			query := `SELECT ` + portColumns + `, ` + distExpr + ` AS dist FROM ports
				WHERE name ILIKE $1 AND (` + distExpr + `, id) > ($4, $5)
				ORDER BY dist ASC, id ASC
				LIMIT $6`
			rows, err = r.pool.Query(ctx, query, pattern, lat, lon, d, cursorID, limit+1)
		}
	}
	if rows == nil && err == nil {
		query := `SELECT ` + portColumns + `, ` + distExpr + ` AS dist FROM ports
			WHERE name ILIKE $1
			ORDER BY dist ASC, id ASC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, pattern, lat, lon, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("searching ports near %.4f,%.4f: %w", lat, lon, err)
	}
	defer rows.Close()

	ports, dists, err := scanPortsWithDist(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning searched ports: %w", err)
	}

	var nextCursor string
	if len(ports) > limit {
		ports = ports[:limit]
		last := ports[limit-1]
		nextCursor = pagination.EncodeKeysetText(
			strconv.FormatFloat(dists[limit-1], 'f', -1, 64), last.ID)
	}

	return ports, nextCursor, nil
}

// scanPortsWithDist scans rows that carry the port columns plus a trailing
// distance column, returning the ports and their distances in lockstep.
func scanPortsWithDist(rows pgx.Rows) ([]domain.Port, []float64, error) {
	var (
		ports []domain.Port
		dists []float64
	)
	for rows.Next() {
		p := domain.Port{}
		var dist float64
		if err := rows.Scan(
			&p.ID, &p.Name, &p.Lat, &p.Lon,
			&p.Country, &p.PortType, &p.DepthM, &p.Facilities,
			&p.VHFChannel, &p.Website, &p.CreatedAt, &p.UpdatedAt, &dist,
		); err != nil {
			return nil, nil, err
		}
		ports = append(ports, p)
		dists = append(dists, dist)
	}
	return ports, dists, rows.Err()
}

// WithinBBox returns ports whose location falls inside the geographic bounding
// box [minLon, minLat, maxLon, maxLat]. The bbox overlap (`&&`) against the
// geography column is answered by the GIST index idx_ports_location, and the
// same (name, id) keyset pagination and ST_Y/ST_X projection as NearLocation
// keep result shape consistent.
func (r *PortRepo) WithinBBox(ctx context.Context, minLon, minLat, maxLon, maxLat float64, cursor string, limit int) ([]domain.Port, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursorName, cursorID, ok := pagination.DecodeKeysetText(cursor); ok {
		query := `SELECT ` + portColumns + ` FROM ports
			WHERE location && ST_MakeEnvelope($1, $2, $3, $4, 4326)::geography
				AND (name, id) > ($5, $6)
			ORDER BY name ASC, id ASC
			LIMIT $7`
		rows, err = r.pool.Query(ctx, query, minLon, minLat, maxLon, maxLat, cursorName, cursorID, limit+1)
	} else {
		query := `SELECT ` + portColumns + ` FROM ports
			WHERE location && ST_MakeEnvelope($1, $2, $3, $4, 4326)::geography
			ORDER BY name ASC, id ASC
			LIMIT $5`
		rows, err = r.pool.Query(ctx, query, minLon, minLat, maxLon, maxLat, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing ports within bbox [%.4f,%.4f,%.4f,%.4f]: %w", minLon, minLat, maxLon, maxLat, err)
	}
	defer rows.Close()

	ports, err := scanPorts(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning ports within bbox: %w", err)
	}

	var nextCursor string
	if len(ports) > limit {
		ports = ports[:limit]
		last := ports[limit-1]
		nextCursor = pagination.EncodeKeysetText(last.Name, last.ID)
	}

	return ports, nextCursor, nil
}
