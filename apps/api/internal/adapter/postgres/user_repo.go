package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// UserRepo resolves display names from Supabase auth.users metadata.
type UserRepo struct {
	pool *pgxpool.Pool
}

// NewUserRepo creates a new UserRepo.
func NewUserRepo(pool *pgxpool.Pool) *UserRepo {
	return &UserRepo{pool: pool}
}

// DisplayName returns the user's display name (from auth metadata), falling
// back to their email, then a generic label.
func (r *UserRepo) DisplayName(ctx context.Context, userID string) (string, error) {
	var name string
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(
			NULLIF(raw_user_meta_data->>'name', ''),
			NULLIF(raw_user_meta_data->>'display_name', ''),
			NULLIF(raw_user_meta_data->>'full_name', ''),
			email::text,
			'Alguien'
		)
		FROM auth.users WHERE id = $1`,
		userID,
	).Scan(&name)
	if err != nil {
		return "Alguien", fmt.Errorf("resolving display name for %s: %w", userID, err)
	}
	return name, nil
}

// Email returns the user's sign-in email, or an empty string when the user has
// none (an OAuth identity without a shared email). Callers treat empty as "no
// email channel for this subscriber" rather than as an error.
func (r *UserRepo) Email(ctx context.Context, userID string) (string, error) {
	var email *string
	err := r.pool.QueryRow(ctx,
		`SELECT email::text FROM auth.users WHERE id = $1`, userID,
	).Scan(&email)
	if err != nil {
		return "", fmt.Errorf("resolving email for %s: %w", userID, err)
	}
	if email == nil {
		return "", nil
	}
	return *email, nil
}
