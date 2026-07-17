package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// boatColumns is the shared column list for boat queries.
const boatColumns = `id, user_id, name, registration, type, length_m, home_port,
	ST_Y(home_port_location::geometry) AS home_port_lat,
	ST_X(home_port_location::geometry) AS home_port_lon,
	photo_url, photo_urls, engine_hours,
	created_at, updated_at`

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
		INSERT INTO boats (user_id, name, registration, type, length_m, home_port, home_port_location, photo_url, photo_urls, engine_hours)
		VALUES ($1, $2, $3, $4, $5, $6,
			CASE WHEN $7::float8 IS NOT NULL AND $8::float8 IS NOT NULL
				THEN ST_MakePoint($8, $7)
				ELSE NULL
			END,
			$9, $10, $11)
		RETURNING ` + boatColumns

	b := &domain.Boat{}
	err := r.pool.QueryRow(ctx, query,
		boat.UserID, boat.Name, boat.Registration, boat.Type, boat.LengthM,
		boat.HomePort, boat.HomePortLat, boat.HomePortLon,
		boat.PhotoURL, photoArray(boat.PhotoURLs), boat.EngineHours,
	).Scan(
		&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
		&b.HomePort, &b.HomePortLat, &b.HomePortLon,
		&b.PhotoURL, &b.PhotoURLs, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("inserting boat: %w", err)
	}

	return b, nil
}

// GetByID retrieves a boat by ID, scoped to the given user.
func (r *BoatRepo) GetByID(ctx context.Context, userID, id string) (*domain.Boat, error) {
	query := `SELECT ` + boatColumns + ` FROM boats WHERE user_id = $1 AND id = $2`

	b := &domain.Boat{}
	err := r.pool.QueryRow(ctx, query, userID, id).Scan(
		&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
		&b.HomePort, &b.HomePortLat, &b.HomePortLon,
		&b.PhotoURL, &b.PhotoURLs, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrBoatNotFound
		}
		return nil, fmt.Errorf("getting boat %s: %w", id, err)
	}

	return b, nil
}

// List returns a paginated list of boats for a user using keyset pagination.
// The cursor encodes the (created_at, id) position of the last returned item.
// We fetch limit+1 to determine if there is a next page.
func (r *BoatRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursorTime, cursorID, ok := pagination.DecodeKeysetTime(cursor); ok {
		query := `SELECT ` + boatColumns + ` FROM boats
			WHERE user_id = $1 AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, userID, cursorTime, cursorID, limit+1)
	} else {
		query := `SELECT ` + boatColumns + ` FROM boats
			WHERE user_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, userID, limit+1)
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
			&b.PhotoURL, &b.PhotoURLs, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
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
		boats = boats[:limit]
		last := boats[limit-1]
		nextCursor = pagination.EncodeKeysetTime(last.CreatedAt, last.ID)
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
			photo_url = $10, photo_urls = $11, engine_hours = $12,
			updated_at = now()
		WHERE user_id = $1 AND id = $2
		RETURNING ` + boatColumns

	b := &domain.Boat{}
	err := r.pool.QueryRow(ctx, query,
		userID, boat.ID, boat.Name, boat.Registration, boat.Type, boat.LengthM,
		boat.HomePort, boat.HomePortLat, boat.HomePortLon,
		boat.PhotoURL, photoArray(boat.PhotoURLs), boat.EngineHours,
	).Scan(
		&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
		&b.HomePort, &b.HomePortLat, &b.HomePortLon,
		&b.PhotoURL, &b.PhotoURLs, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt,
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

// Count returns how many boats the user owns.
func (r *BoatRepo) Count(ctx context.Context, userID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT count(*) FROM boats WHERE user_id = $1`, userID).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("counting boats for %s: %w", userID, err)
	}
	return n, nil
}

func scanBoatRow(row interface{ Scan(...any) error }) (*domain.Boat, error) {
	b := &domain.Boat{}
	err := row.Scan(&b.ID, &b.UserID, &b.Name, &b.Registration, &b.Type, &b.LengthM,
		&b.HomePort, &b.HomePortLat, &b.HomePortLon,
		&b.PhotoURL, &b.PhotoURLs, &b.EngineHours, &b.CreatedAt, &b.UpdatedAt)
	return b, err
}

// GetByIDAccessible returns a boat the user owns OR is a shared member of.
func (r *BoatRepo) GetByIDAccessible(ctx context.Context, userID, id string) (*domain.Boat, error) {
	query := `SELECT ` + boatColumns + ` FROM boats
		WHERE id = $2 AND (user_id = $1
			OR id IN (SELECT boat_id FROM boat_members WHERE user_id = $1))`
	b, err := scanBoatRow(r.pool.QueryRow(ctx, query, userID, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrBoatNotFound
		}
		return nil, fmt.Errorf("getting accessible boat %s: %w", id, err)
	}
	return b, nil
}

// HasAccess reports whether the user owns or is a member of the boat.
func (r *BoatRepo) HasAccess(ctx context.Context, userID, boatID string) (bool, error) {
	var ok bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM boats WHERE id = $2 AND user_id = $1)
			OR EXISTS (SELECT 1 FROM boat_members WHERE boat_id = $2 AND user_id = $1)`,
		userID, boatID).Scan(&ok)
	if err != nil {
		return false, fmt.Errorf("checking boat access: %w", err)
	}
	return ok, nil
}

// ListShared returns boats shared with the user (where they are a member,
// not the owner).
func (r *BoatRepo) ListShared(ctx context.Context, userID string) ([]domain.Boat, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+boatColumns+` FROM boats
		 WHERE id IN (SELECT boat_id FROM boat_members WHERE user_id = $1)
		 ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, fmt.Errorf("listing shared boats: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Boat, 0)
	for rows.Next() {
		b, err := scanBoatRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *b)
	}
	return out, rows.Err()
}

// EnsureShareCode sets the share code only if absent (idempotent) and returns
// the effective code. Owner only.
func (r *BoatRepo) EnsureShareCode(ctx context.Context, userID, boatID, candidate string) (string, error) {
	var code string
	err := r.pool.QueryRow(ctx,
		`UPDATE boats SET share_code = COALESCE(share_code, $1)
		 WHERE user_id = $2 AND id = $3 RETURNING share_code`,
		candidate, userID, boatID).Scan(&code)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", domain.ErrBoatNotFound
		}
		return "", fmt.Errorf("setting boat share code: %w", err)
	}
	return code, nil
}

// GetIDByShareCode returns the owner and boat id for a share code.
func (r *BoatRepo) GetIDByShareCode(ctx context.Context, code string) (boatID, ownerID string, err error) {
	err = r.pool.QueryRow(ctx,
		`SELECT id, user_id FROM boats WHERE share_code = $1`, code).Scan(&boatID, &ownerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", "", domain.ErrBoatNotFound
		}
		return "", "", fmt.Errorf("getting boat by share code: %w", err)
	}
	return boatID, ownerID, nil
}

// AddMember grants a user shared access to a boat.
func (r *BoatRepo) AddMember(ctx context.Context, boatID, userID, role string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO boat_members (boat_id, user_id, role) VALUES ($1, $2, $3)
		 ON CONFLICT (boat_id, user_id) DO NOTHING`, boatID, userID, role)
	if err != nil {
		return fmt.Errorf("adding boat member: %w", err)
	}
	return nil
}

// ListMembers returns the shared members of a boat, with display names.
func (r *BoatRepo) ListMembers(ctx context.Context, boatID string) ([]domain.BoatMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT bm.user_id, `+memberNameExpr+`,
			bm.can_record_trips, bm.can_manage_expenses, bm.can_manage_maintenance,
			bm.can_view_documents, bm.can_manage_documents
		 FROM boat_members bm
		 LEFT JOIN auth.users u ON u.id = bm.user_id
		 WHERE bm.boat_id = $1 ORDER BY bm.created_at ASC`, boatID)
	if err != nil {
		return nil, fmt.Errorf("listing boat members: %w", err)
	}
	defer rows.Close()
	out := make([]domain.BoatMember, 0)
	for rows.Next() {
		var m domain.BoatMember
		p := &m.Permissions
		if err := rows.Scan(&m.UserID, &m.Name,
			&p.CanRecordTrips, &p.CanManageExpenses, &p.CanManageMaintenance,
			&p.CanViewDocuments, &p.CanManageDocuments); err != nil {
			return nil, err
		}
		m.BoatID = boatID
		out = append(out, m)
	}
	return out, rows.Err()
}

// RemoveMember revokes a member's access (owner only — enforced via ownerID).
func (r *BoatRepo) RemoveMember(ctx context.Context, ownerID, boatID, memberUserID string) error {
	ct, err := r.pool.Exec(ctx,
		`DELETE FROM boat_members WHERE boat_id = $2 AND user_id = $3
		 AND boat_id IN (SELECT id FROM boats WHERE user_id = $1)`,
		ownerID, boatID, memberUserID)
	if err != nil {
		return fmt.Errorf("removing boat member: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// Leave removes the user's own shared membership of a boat.
func (r *BoatRepo) Leave(ctx context.Context, userID, boatID string) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM boat_members WHERE boat_id = $1 AND user_id = $2`, boatID, userID)
	if err != nil {
		return fmt.Errorf("leaving boat: %w", err)
	}
	return nil
}

// GetPermissions resolves a user's permission set for a boat. The owner has all
// permissions; a member has their stored flags; a non-member has access=false.
func (r *BoatRepo) GetPermissions(ctx context.Context, userID, boatID string) (domain.BoatPermissions, bool, error) {
	var isOwner bool
	if err := r.pool.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM boats WHERE id = $2 AND user_id = $1)`,
		userID, boatID).Scan(&isOwner); err != nil {
		return domain.BoatPermissions{}, false, fmt.Errorf("checking boat owner: %w", err)
	}
	if isOwner {
		return domain.OwnerPermissions(), true, nil
	}
	var p domain.BoatPermissions
	err := r.pool.QueryRow(ctx,
		`SELECT can_record_trips, can_manage_expenses, can_manage_maintenance,
			can_view_documents, can_manage_documents
		 FROM boat_members WHERE boat_id = $1 AND user_id = $2`, boatID, userID).
		Scan(&p.CanRecordTrips, &p.CanManageExpenses, &p.CanManageMaintenance,
			&p.CanViewDocuments, &p.CanManageDocuments)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.BoatPermissions{}, false, nil
		}
		return domain.BoatPermissions{}, false, fmt.Errorf("getting boat permissions: %w", err)
	}
	return p, true, nil
}

// SetPermissions updates a member's permission flags (owner only).
func (r *BoatRepo) SetPermissions(ctx context.Context, ownerID, boatID, memberUserID string, p domain.BoatPermissions) error {
	ct, err := r.pool.Exec(ctx,
		`UPDATE boat_members SET can_record_trips=$1, can_manage_expenses=$2,
			can_manage_maintenance=$3, can_view_documents=$4, can_manage_documents=$5
		 WHERE boat_id = $6 AND user_id = $7
			AND boat_id IN (SELECT id FROM boats WHERE user_id = $8)`,
		p.CanRecordTrips, p.CanManageExpenses, p.CanManageMaintenance,
		p.CanViewDocuments, p.CanManageDocuments,
		boatID, memberUserID, ownerID)
	if err != nil {
		return fmt.Errorf("setting boat member permissions: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
