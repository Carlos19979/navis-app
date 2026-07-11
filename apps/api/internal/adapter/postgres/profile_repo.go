package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// ProfileRepo implements port.ProfileRepository using PostgreSQL.
type ProfileRepo struct {
	pool *pgxpool.Pool
}

// NewProfileRepo creates a new ProfileRepo.
func NewProfileRepo(pool *pgxpool.Pool) *ProfileRepo {
	return &ProfileRepo{pool: pool}
}

// GetOrCreate returns the user's profile, inserting a default 'free' one if
// it doesn't exist yet (the DB default drives the plan value).
func (r *ProfileRepo) GetOrCreate(ctx context.Context, userID string) (*domain.Profile, error) {
	p := &domain.Profile{}
	err := r.pool.QueryRow(ctx,
		`INSERT INTO profiles (id) VALUES ($1)
		 ON CONFLICT (id) DO UPDATE SET updated_at = profiles.updated_at
		 RETURNING id, plan, created_at, updated_at`,
		userID,
	).Scan(&p.UserID, &p.Plan, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get-or-create profile for %s: %w", userID, err)
	}
	return p, nil
}

// SetPlan updates the user's plan and returns the updated profile.
func (r *ProfileRepo) SetPlan(ctx context.Context, userID string, plan domain.Plan) (*domain.Profile, error) {
	p := &domain.Profile{}
	err := r.pool.QueryRow(ctx,
		`INSERT INTO profiles (id, plan) VALUES ($1, $2)
		 ON CONFLICT (id) DO UPDATE SET plan = EXCLUDED.plan, updated_at = now()
		 RETURNING id, plan, created_at, updated_at`,
		userID, plan,
	).Scan(&p.UserID, &p.Plan, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("setting plan for %s: %w", userID, err)
	}
	return p, nil
}
