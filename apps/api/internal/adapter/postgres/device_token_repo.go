package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// DeviceTokenRepo implements port.DeviceTokenRepository using PostgreSQL.
type DeviceTokenRepo struct {
	pool *pgxpool.Pool
}

// NewDeviceTokenRepo creates a new DeviceTokenRepo.
func NewDeviceTokenRepo(pool *pgxpool.Pool) *DeviceTokenRepo {
	return &DeviceTokenRepo{pool: pool}
}

// Upsert inserts a device token or updates it if the token already exists.
func (r *DeviceTokenRepo) Upsert(ctx context.Context, userID, token string, platform domain.Platform) error {
	query := `
		INSERT INTO device_tokens (user_id, token, platform)
		VALUES ($1, $2, $3)
		ON CONFLICT (token) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			platform = EXCLUDED.platform,
			updated_at = now()
	`
	_, err := r.pool.Exec(ctx, query, userID, token, string(platform))
	return err
}

// Delete removes a device token owned by the given user. The user_id filter
// prevents one user from unregistering another user's device.
func (r *DeviceTokenRepo) Delete(ctx context.Context, userID, token string) error {
	query := `DELETE FROM device_tokens WHERE user_id = $1 AND token = $2`
	_, err := r.pool.Exec(ctx, query, userID, token)
	return err
}

// GetByUserID returns all device tokens for a given user.
func (r *DeviceTokenRepo) GetByUserID(ctx context.Context, userID string) ([]domain.DeviceToken, error) {
	query := `
		SELECT id, user_id, token, platform, created_at, updated_at
		FROM device_tokens
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []domain.DeviceToken
	for rows.Next() {
		var dt domain.DeviceToken
		var platform string
		if err := rows.Scan(&dt.ID, &dt.UserID, &dt.Token, &platform, &dt.CreatedAt, &dt.UpdatedAt); err != nil {
			return nil, err
		}
		dt.Platform = domain.Platform(platform)
		tokens = append(tokens, dt)
	}

	return tokens, rows.Err()
}
