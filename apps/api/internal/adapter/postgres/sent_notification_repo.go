package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// SentNotificationRepo is a generic dedup log for scheduled notifications.
type SentNotificationRepo struct {
	pool *pgxpool.Pool
}

// NewSentNotificationRepo creates a new SentNotificationRepo.
func NewSentNotificationRepo(pool *pgxpool.Pool) *SentNotificationRepo {
	return &SentNotificationRepo{pool: pool}
}

// Exists reports whether this (user, kind, ref, dedupKey) was already recorded.
func (r *SentNotificationRepo) Exists(ctx context.Context, userID, kind, refID, dedupKey string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM sent_notifications
			WHERE user_id = $1 AND kind = $2 AND ref_id = $3 AND dedup_key = $4
		)`,
		userID, kind, refID, dedupKey,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking sent notification: %w", err)
	}
	return exists, nil
}

// Record marks a (user, kind, ref, dedupKey) notification as sent.
func (r *SentNotificationRepo) Record(ctx context.Context, userID, kind, refID, dedupKey string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO sent_notifications (user_id, kind, ref_id, dedup_key)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (user_id, kind, ref_id, dedup_key) DO NOTHING`,
		userID, kind, refID, dedupKey,
	)
	if err != nil {
		return fmt.Errorf("recording sent notification: %w", err)
	}
	return nil
}
