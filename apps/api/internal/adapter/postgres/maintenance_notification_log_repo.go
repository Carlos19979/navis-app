package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

// MaintenanceNotificationLogRepo implements
// port.MaintenanceNotificationLogRepository using PostgreSQL.
type MaintenanceNotificationLogRepo struct {
	pool *pgxpool.Pool
}

// NewMaintenanceNotificationLogRepo creates a new repo.
func NewMaintenanceNotificationLogRepo(pool *pgxpool.Pool) *MaintenanceNotificationLogRepo {
	return &MaintenanceNotificationLogRepo{pool: pool}
}

// Exists checks whether a maintenance-due notification was already sent for
// this task, status and due occurrence.
func (r *MaintenanceNotificationLogRepo) Exists(ctx context.Context, userID, taskID, status, dueKey string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM maintenance_notification_logs
			WHERE user_id = $1 AND task_id = $2 AND status = $3 AND due_key = $4
		)`, userID, taskID, status, dueKey).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking maintenance notification log: %w", err)
	}
	return exists, nil
}

// Create records that a maintenance-due notification was sent.
func (r *MaintenanceNotificationLogRepo) Create(ctx context.Context, userID, taskID, status, dueKey string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO maintenance_notification_logs (user_id, task_id, status, due_key)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT DO NOTHING`,
		userID, taskID, status, dueKey)
	if err != nil {
		return fmt.Errorf("creating maintenance notification log: %w", err)
	}
	return nil
}
