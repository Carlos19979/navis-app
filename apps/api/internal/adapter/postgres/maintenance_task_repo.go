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

const maintenanceTaskColumns = `id, boat_id, user_id, name, kind, interval_months,
	interval_hours, next_due_date, next_due_hours, created_at, updated_at`

func scanMaintenanceTask(row interface {
	Scan(...any) error
}) (*domain.MaintenanceTask, error) {
	t := &domain.MaintenanceTask{}
	err := row.Scan(&t.ID, &t.BoatID, &t.UserID, &t.Name, &t.Kind, &t.IntervalMonths,
		&t.IntervalHours, &t.NextDueDate, &t.NextDueHours, &t.CreatedAt, &t.UpdatedAt)
	return t, err
}

// Create inserts a maintenance task.
func (r *MaintenanceTaskRepo) Create(ctx context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	query := `INSERT INTO maintenance_tasks
		(boat_id, user_id, name, kind, interval_months, interval_hours, next_due_date, next_due_hours)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING ` + maintenanceTaskColumns
	out, err := scanMaintenanceTask(querier(ctx, r.pool).QueryRow(ctx, query,
		t.BoatID, t.UserID, t.Name, t.Kind, t.IntervalMonths, t.IntervalHours,
		t.NextDueDate, t.NextDueHours))
	if err != nil {
		return nil, fmt.Errorf("inserting maintenance task: %w", err)
	}
	return out, nil
}

// Update modifies a maintenance task scoped to its boat.
func (r *MaintenanceTaskRepo) Update(ctx context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	query := `UPDATE maintenance_tasks
		SET name=$1, kind=$2, interval_months=$3, interval_hours=$4,
		    next_due_date=$5, next_due_hours=$6, updated_at=now()
		WHERE id=$7 AND boat_id=$8
		RETURNING ` + maintenanceTaskColumns
	out, err := scanMaintenanceTask(querier(ctx, r.pool).QueryRow(ctx, query,
		t.Name, t.Kind, t.IntervalMonths, t.IntervalHours,
		t.NextDueDate, t.NextDueHours, t.ID, t.BoatID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("updating maintenance task %s: %w", t.ID, err)
	}
	return out, nil
}

// ListByBoat returns a boat's maintenance tasks, soonest due first so the plan
// reads in the order it needs attention; one-off jobs (no date) come last.
func (r *MaintenanceTaskRepo) ListByBoat(ctx context.Context, boatID string) ([]domain.MaintenanceTask, error) {
	rows, err := querier(ctx, r.pool).Query(ctx,
		`SELECT `+maintenanceTaskColumns+` FROM maintenance_tasks
		 WHERE boat_id = $1
		 ORDER BY next_due_date ASC NULLS LAST, created_at ASC`, boatID)
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
	out, err := scanMaintenanceTask(querier(ctx, r.pool).QueryRow(ctx,
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

// ListAllWithLatest returns every task across all boats joined with its boat
// context (name, owner, engine hours). Input for the maintenance-due reminder
// cron. No history join: a task carries its own due date now, and the boat's
// engine hours are all the hours limit is measured against.
func (r *MaintenanceTaskRepo) ListAllWithLatest(ctx context.Context) ([]domain.MaintenanceTaskWithLatest, error) {
	rows, err := querier(ctx, r.pool).Query(ctx, `
		SELECT t.id, t.boat_id, t.name, t.kind, t.interval_months, t.interval_hours,
		       t.next_due_date, t.next_due_hours, t.created_at, t.updated_at,
		       b.name, b.user_id, b.engine_hours
		FROM maintenance_tasks t
		JOIN boats b ON b.id = t.boat_id
		WHERE t.kind = 'periodic'`)
	if err != nil {
		return nil, fmt.Errorf("listing tasks for notify: %w", err)
	}
	defer rows.Close()

	var out []domain.MaintenanceTaskWithLatest
	for rows.Next() {
		var row domain.MaintenanceTaskWithLatest
		if err := rows.Scan(
			&row.Task.ID, &row.Task.BoatID, &row.Task.Name, &row.Task.Kind,
			&row.Task.IntervalMonths, &row.Task.IntervalHours,
			&row.Task.NextDueDate, &row.Task.NextDueHours,
			&row.Task.CreatedAt, &row.Task.UpdatedAt,
			&row.BoatName, &row.OwnerID, &row.EngineHours,
		); err != nil {
			return nil, fmt.Errorf("scanning task for notify: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}
