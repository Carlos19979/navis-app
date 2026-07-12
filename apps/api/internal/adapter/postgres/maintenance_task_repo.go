package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// MaintenanceTaskRepo implements port.MaintenanceTaskRepository using PostgreSQL.
type MaintenanceTaskRepo struct {
	pool *pgxpool.Pool
}

// NewMaintenanceTaskRepo creates a new MaintenanceTaskRepo.
func NewMaintenanceTaskRepo(pool *pgxpool.Pool) *MaintenanceTaskRepo {
	return &MaintenanceTaskRepo{pool: pool}
}

const maintenanceTaskColumns = `id, boat_id, user_id, name, interval_months,
	interval_hours, created_at, updated_at`

func scanMaintenanceTask(row interface {
	Scan(...any) error
}) (*domain.MaintenanceTask, error) {
	t := &domain.MaintenanceTask{}
	err := row.Scan(&t.ID, &t.BoatID, &t.UserID, &t.Name, &t.IntervalMonths,
		&t.IntervalHours, &t.CreatedAt, &t.UpdatedAt)
	return t, err
}

// Create inserts a maintenance task.
func (r *MaintenanceTaskRepo) Create(ctx context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	query := `INSERT INTO maintenance_tasks
		(boat_id, user_id, name, interval_months, interval_hours)
		VALUES ($1,$2,$3,$4,$5)
		RETURNING ` + maintenanceTaskColumns
	out, err := scanMaintenanceTask(r.pool.QueryRow(ctx, query,
		t.BoatID, t.UserID, t.Name, t.IntervalMonths, t.IntervalHours))
	if err != nil {
		return nil, fmt.Errorf("inserting maintenance task: %w", err)
	}
	return out, nil
}

// Update modifies a maintenance task scoped to its boat.
func (r *MaintenanceTaskRepo) Update(ctx context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	query := `UPDATE maintenance_tasks
		SET name=$1, interval_months=$2, interval_hours=$3, updated_at=now()
		WHERE id=$4 AND boat_id=$5
		RETURNING ` + maintenanceTaskColumns
	out, err := scanMaintenanceTask(r.pool.QueryRow(ctx, query,
		t.Name, t.IntervalMonths, t.IntervalHours, t.ID, t.BoatID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("updating maintenance task %s: %w", t.ID, err)
	}
	return out, nil
}

// ListByBoat returns a boat's maintenance tasks, oldest first (stable order).
func (r *MaintenanceTaskRepo) ListByBoat(ctx context.Context, boatID string) ([]domain.MaintenanceTask, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+maintenanceTaskColumns+` FROM maintenance_tasks
		 WHERE boat_id = $1
		 ORDER BY created_at ASC`, boatID)
	if err != nil {
		return nil, fmt.Errorf("listing maintenance tasks: %w", err)
	}
	defer rows.Close()
	tasks := make([]domain.MaintenanceTask, 0)
	for rows.Next() {
		t, err := scanMaintenanceTask(rows)
		if err != nil {
			return nil, err
		}
		tasks = append(tasks, *t)
	}
	return tasks, rows.Err()
}

// GetByID returns a single maintenance task on a boat (caller enforces access).
func (r *MaintenanceTaskRepo) GetByID(ctx context.Context, boatID, id string) (*domain.MaintenanceTask, error) {
	out, err := scanMaintenanceTask(r.pool.QueryRow(ctx,
		`SELECT `+maintenanceTaskColumns+` FROM maintenance_tasks WHERE boat_id = $1 AND id = $2`,
		boatID, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("getting maintenance task %s: %w", id, err)
	}
	return out, nil
}

// Delete removes a maintenance task on a boat (its logs survive, task_id -> NULL).
func (r *MaintenanceTaskRepo) Delete(ctx context.Context, boatID, id string) error {
	ct, err := r.pool.Exec(ctx,
		`DELETE FROM maintenance_tasks WHERE boat_id = $1 AND id = $2`, boatID, id)
	if err != nil {
		return fmt.Errorf("deleting maintenance task %s: %w", id, err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
