package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// GroupRepo implements port.GroupRepository using PostgreSQL.
type GroupRepo struct {
	pool *pgxpool.Pool
}

// NewGroupRepo creates a new GroupRepo.
func NewGroupRepo(pool *pgxpool.Pool) *GroupRepo {
	return &GroupRepo{pool: pool}
}

// groupSelectBase selects the stored columns plus derived fields for viewer $1.
const groupSelectBase = `
	g.id, g.owner_id, g.name, g.description, g.photo_url, g.visibility, g.invite_code,
	g.created_at, g.updated_at,
	(SELECT count(*) FROM group_members m WHERE m.group_id = g.id AND m.status = 'active') AS member_count,
	(SELECT count(*) FROM group_members m WHERE m.group_id = g.id AND m.status = 'pending') AS pending_count,
	COALESCE((SELECT m.status FROM group_members m WHERE m.group_id = g.id AND m.user_id = $1), 'none') AS my_status,
	COALESCE((SELECT m.role FROM group_members m WHERE m.group_id = g.id AND m.user_id = $1), '') AS my_role`

func scanGroup(row pgx.Row) (*domain.Group, error) {
	g := &domain.Group{}
	err := row.Scan(
		&g.ID, &g.OwnerID, &g.Name, &g.Description, &g.PhotoURL, &g.Visibility, &g.InviteCode,
		&g.CreatedAt, &g.UpdatedAt,
		&g.MemberCount, &g.PendingCount, &g.MyMembershipStatus, &g.MyRole,
	)
	return g, err
}

func scanGroups(rows pgx.Rows) ([]domain.Group, error) {
	groups := make([]domain.Group, 0)
	for rows.Next() {
		g := domain.Group{}
		if err := rows.Scan(
			&g.ID, &g.OwnerID, &g.Name, &g.Description, &g.PhotoURL, &g.Visibility, &g.InviteCode,
			&g.CreatedAt, &g.UpdatedAt,
			&g.MemberCount, &g.PendingCount, &g.MyMembershipStatus, &g.MyRole,
		); err != nil {
			return nil, err
		}
		groups = append(groups, g)
	}
	return groups, rows.Err()
}

// Create inserts a new group and returns the stored record (without derived fields).
func (r *GroupRepo) Create(ctx context.Context, group *domain.Group) (*domain.Group, error) {
	query := `
		INSERT INTO groups (owner_id, name, description, photo_url, visibility, invite_code)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, owner_id, name, description, photo_url, visibility, invite_code, created_at, updated_at`

	g := &domain.Group{}
	err := r.pool.QueryRow(ctx, query,
		group.OwnerID, group.Name, group.Description, group.PhotoURL, group.Visibility, group.InviteCode,
	).Scan(
		&g.ID, &g.OwnerID, &g.Name, &g.Description, &g.PhotoURL, &g.Visibility, &g.InviteCode,
		&g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		// The only UNIQUE constraint on groups is invite_code, so a unique
		// violation here means the generated code collided.
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, domain.ErrConflict
		}
		return nil, fmt.Errorf("inserting group: %w", err)
	}
	return g, nil
}

// GetByID retrieves a group visible to the user (public, owned, or active member).
func (r *GroupRepo) GetByID(ctx context.Context, userID, id string) (*domain.Group, error) {
	query := `SELECT ` + groupSelectBase + ` FROM groups g
		WHERE g.id = $2
			AND (g.visibility = 'public' OR g.owner_id = $1
				OR EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = g.id AND m.user_id = $1 AND m.status = 'active'))`

	g, err := scanGroup(r.pool.QueryRow(ctx, query, userID, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupNotFound
		}
		return nil, fmt.Errorf("getting group %s: %w", id, err)
	}
	return g, nil
}

// GetByInviteCode retrieves a group by its invite code.
func (r *GroupRepo) GetByInviteCode(ctx context.Context, userID, code string) (*domain.Group, error) {
	query := `SELECT ` + groupSelectBase + ` FROM groups g WHERE g.invite_code = $2`

	g, err := scanGroup(r.pool.QueryRow(ctx, query, userID, code))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrInvalidInviteCode
		}
		return nil, fmt.Errorf("getting group by invite code: %w", err)
	}
	return g, nil
}

// List returns groups the user is an active member of, newest first.
func (r *GroupRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	membership := `EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = g.id AND m.user_id = $1 AND m.status = 'active')`
	return r.listWhere(ctx, userID, membership, cursor, limit)
}

// ListPublic returns public groups the user has not yet actively joined.
func (r *GroupRepo) ListPublic(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	condition := `g.visibility = 'public'
		AND NOT EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = g.id AND m.user_id = $1 AND m.status = 'active')`
	return r.listWhere(ctx, userID, condition, cursor, limit)
}

// listWhere runs a cursor-paginated group query with the given WHERE condition.
// The condition may reference $1 (viewer userID) and g.* columns.
func (r *GroupRepo) listWhere(ctx context.Context, userID, condition, cursor string, limit int) ([]domain.Group, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + groupSelectBase + ` FROM groups g
			WHERE ` + condition + `
			ORDER BY g.created_at DESC, g.id DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, userID, limit+1)
	} else {
		var cursorCreatedAt time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT created_at FROM groups WHERE id = $1`, cursor,
		).Scan(&cursorCreatedAt)
		if cErr != nil {
			return r.listWhere(ctx, userID, condition, "", limit)
		}

		query := `SELECT ` + groupSelectBase + ` FROM groups g
			WHERE ` + condition + ` AND (g.created_at, g.id) < ($2, $3)
			ORDER BY g.created_at DESC, g.id DESC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, userID, cursorCreatedAt, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing groups: %w", err)
	}
	defer rows.Close()

	groups, err := scanGroups(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning groups: %w", err)
	}

	var nextCursor string
	if len(groups) > limit {
		nextCursor = groups[limit].ID
		groups = groups[:limit]
	}
	return groups, nextCursor, nil
}

// Update modifies a group owned by the user and returns the stored record.
func (r *GroupRepo) Update(ctx context.Context, userID string, group *domain.Group) (*domain.Group, error) {
	query := `
		UPDATE groups
		SET name = $3, description = $4, photo_url = $5, visibility = $6, updated_at = now()
		WHERE owner_id = $1 AND id = $2
		RETURNING id, owner_id, name, description, photo_url, visibility, invite_code, created_at, updated_at`

	g := &domain.Group{}
	err := r.pool.QueryRow(ctx, query,
		userID, group.ID, group.Name, group.Description, group.PhotoURL, group.Visibility,
	).Scan(
		&g.ID, &g.OwnerID, &g.Name, &g.Description, &g.PhotoURL, &g.Visibility, &g.InviteCode,
		&g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrGroupNotFound
		}
		return nil, fmt.Errorf("updating group %s: %w", group.ID, err)
	}
	return g, nil
}

// Delete removes a group owned by the user.
func (r *GroupRepo) Delete(ctx context.Context, userID, id string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM groups WHERE owner_id = $1 AND id = $2`, userID, id)
	if err != nil {
		return fmt.Errorf("deleting group %s: %w", id, err)
	}
	if result.RowsAffected() == 0 {
		return domain.ErrGroupNotFound
	}
	return nil
}

// GroupMemberRepo implements port.GroupMemberRepository using PostgreSQL.
type GroupMemberRepo struct {
	pool *pgxpool.Pool
}

// NewGroupMemberRepo creates a new GroupMemberRepo.
func NewGroupMemberRepo(pool *pgxpool.Pool) *GroupMemberRepo {
	return &GroupMemberRepo{pool: pool}
}

// scanMembersWithName scans member rows that additionally select a display name.
func scanMembersWithName(rows pgx.Rows) ([]domain.GroupMember, error) {
	members := make([]domain.GroupMember, 0)
	for rows.Next() {
		m := domain.GroupMember{}
		if err := rows.Scan(&m.GroupID, &m.UserID, &m.Role, &m.Status, &m.JoinedAt, &m.Name); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

// memberName resolves a display name from the user's auth metadata, falling
// back to email then a generic label.
const memberNameExpr = `COALESCE(
	NULLIF(u.raw_user_meta_data->>'name', ''),
	NULLIF(u.raw_user_meta_data->>'display_name', ''),
	NULLIF(u.raw_user_meta_data->>'full_name', ''),
	u.email::text,
	'Miembro'
)`

// Add inserts a membership row (idempotent: existing rows are left untouched).
func (r *GroupMemberRepo) Add(ctx context.Context, groupID, userID string, role domain.GroupMemberRole, status domain.GroupMemberStatus) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO group_members (group_id, user_id, role, status)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (group_id, user_id) DO NOTHING`,
		groupID, userID, role, status)
	if err != nil {
		return fmt.Errorf("adding member to group %s: %w", groupID, err)
	}
	return nil
}

// Get retrieves a single membership row.
func (r *GroupMemberRepo) Get(ctx context.Context, groupID, userID string) (*domain.GroupMember, error) {
	m := &domain.GroupMember{}
	err := r.pool.QueryRow(ctx,
		`SELECT group_id, user_id, role, status, joined_at
		 FROM group_members WHERE group_id = $1 AND user_id = $2`,
		groupID, userID,
	).Scan(&m.GroupID, &m.UserID, &m.Role, &m.Status, &m.JoinedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrMembershipNotFound
		}
		return nil, fmt.Errorf("getting membership in group %s: %w", groupID, err)
	}
	return m, nil
}

// SetStatus updates a membership's status (e.g., pending -> active on approval).
func (r *GroupMemberRepo) SetStatus(ctx context.Context, groupID, userID string, status domain.GroupMemberStatus) error {
	result, err := r.pool.Exec(ctx,
		`UPDATE group_members SET status = $3 WHERE group_id = $1 AND user_id = $2`,
		groupID, userID, status)
	if err != nil {
		return fmt.Errorf("updating membership in group %s: %w", groupID, err)
	}
	if result.RowsAffected() == 0 {
		return domain.ErrMembershipNotFound
	}
	return nil
}

// Remove deletes a membership row.
func (r *GroupMemberRepo) Remove(ctx context.Context, groupID, userID string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM group_members WHERE group_id = $1 AND user_id = $2`,
		groupID, userID)
	if err != nil {
		return fmt.Errorf("removing member from group %s: %w", groupID, err)
	}
	if result.RowsAffected() == 0 {
		return domain.ErrMembershipNotFound
	}
	return nil
}

// ListMembers returns the active members of a group (owner first, then by join time).
func (r *GroupMemberRepo) ListMembers(ctx context.Context, groupID string) ([]domain.GroupMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT gm.group_id, gm.user_id, gm.role, gm.status, gm.joined_at, `+memberNameExpr+`
		 FROM group_members gm
		 LEFT JOIN auth.users u ON u.id = gm.user_id
		 WHERE gm.group_id = $1 AND gm.status = 'active'
		 ORDER BY (gm.role = 'owner') DESC, gm.joined_at ASC`,
		groupID)
	if err != nil {
		return nil, fmt.Errorf("listing members of group %s: %w", groupID, err)
	}
	defer rows.Close()

	members, err := scanMembersWithName(rows)
	if err != nil {
		return nil, fmt.Errorf("scanning members of group %s: %w", groupID, err)
	}
	return members, nil
}

// ListPending returns the pending join requests of a group, oldest first.
func (r *GroupMemberRepo) ListPending(ctx context.Context, groupID string) ([]domain.GroupMember, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT gm.group_id, gm.user_id, gm.role, gm.status, gm.joined_at, `+memberNameExpr+`
		 FROM group_members gm
		 LEFT JOIN auth.users u ON u.id = gm.user_id
		 WHERE gm.group_id = $1 AND gm.status = 'pending'
		 ORDER BY gm.joined_at ASC`,
		groupID)
	if err != nil {
		return nil, fmt.Errorf("listing pending requests of group %s: %w", groupID, err)
	}
	defer rows.Close()

	members, err := scanMembersWithName(rows)
	if err != nil {
		return nil, fmt.Errorf("scanning pending requests of group %s: %w", groupID, err)
	}
	return members, nil
}
