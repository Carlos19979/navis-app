package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// MaintenanceRepo implements port.MaintenanceRepository using PostgreSQL.
type MaintenanceRepo struct {
	pool *pgxpool.Pool
}

// NewMaintenanceRepo creates a new MaintenanceRepo.
func NewMaintenanceRepo(pool *pgxpool.Pool) *MaintenanceRepo {
	return &MaintenanceRepo{pool: pool}
}

const maintenanceColumns = `id, boat_id, user_id, type, performed_at, engine_hours,
	cost, provider, notes, created_at, updated_at`

func scanMaintenance(row interface {
	Scan(...any) error
}) (*domain.MaintenanceLog, error) {
	m := &domain.MaintenanceLog{}
	err := row.Scan(&m.ID, &m.BoatID, &m.UserID, &m.Type, &m.PerformedAt,
		&m.EngineHours, &m.Cost, &m.Provider, &m.Notes, &m.CreatedAt, &m.UpdatedAt)
	return m, err
}

// Create inserts a maintenance log.
func (r *MaintenanceRepo) Create(ctx context.Context, m *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	query := `INSERT INTO maintenance_logs
		(boat_id, user_id, type, performed_at, engine_hours, cost, provider, notes)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING ` + maintenanceColumns
	out, err := scanMaintenance(r.pool.QueryRow(ctx, query,
		m.BoatID, m.UserID, m.Type, m.PerformedAt, m.EngineHours, m.Cost, m.Provider, m.Notes))
	if err != nil {
		return nil, fmt.Errorf("inserting maintenance log: %w", err)
	}
	return out, nil
}

// ListByBoat returns a boat's maintenance logs, newest first.
func (r *MaintenanceRepo) ListByBoat(ctx context.Context, boatID string) ([]domain.MaintenanceLog, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+maintenanceColumns+` FROM maintenance_logs
		 WHERE boat_id = $1
		 ORDER BY performed_at DESC, created_at DESC`, boatID)
	if err != nil {
		return nil, fmt.Errorf("listing maintenance logs: %w", err)
	}
	defer rows.Close()
	logs := make([]domain.MaintenanceLog, 0)
	for rows.Next() {
		m, err := scanMaintenance(rows)
		if err != nil {
			return nil, err
		}
		logs = append(logs, *m)
	}
	return logs, rows.Err()
}

// Delete removes a maintenance log owned by the user.
func (r *MaintenanceRepo) Delete(ctx context.Context, userID, id string) error {
	ct, err := r.pool.Exec(ctx,
		`DELETE FROM maintenance_logs WHERE user_id = $1 AND id = $2`, userID, id)
	if err != nil {
		return fmt.Errorf("deleting maintenance log %s: %w", id, err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// ExpenseRepo implements port.ExpenseRepository using PostgreSQL.
type ExpenseRepo struct {
	pool *pgxpool.Pool
}

// NewExpenseRepo creates a new ExpenseRepo.
func NewExpenseRepo(pool *pgxpool.Pool) *ExpenseRepo {
	return &ExpenseRepo{pool: pool}
}

const expenseColumns = `id, boat_id, user_id, category, amount, incurred_on, notes, created_at, updated_at`

func scanExpense(row interface {
	Scan(...any) error
}) (*domain.Expense, error) {
	e := &domain.Expense{}
	err := row.Scan(&e.ID, &e.BoatID, &e.UserID, &e.Category, &e.Amount,
		&e.IncurredOn, &e.Notes, &e.CreatedAt, &e.UpdatedAt)
	return e, err
}

// Create inserts an expense.
func (r *ExpenseRepo) Create(ctx context.Context, e *domain.Expense) (*domain.Expense, error) {
	query := `INSERT INTO expenses (boat_id, user_id, category, amount, incurred_on, notes)
		VALUES ($1,$2,$3,$4,$5,$6) RETURNING ` + expenseColumns
	out, err := scanExpense(r.pool.QueryRow(ctx, query,
		e.BoatID, e.UserID, e.Category, e.Amount, e.IncurredOn, e.Notes))
	if err != nil {
		return nil, fmt.Errorf("inserting expense: %w", err)
	}
	return out, nil
}

// ListByBoat returns a boat's expenses, newest first.
func (r *ExpenseRepo) ListByBoat(ctx context.Context, boatID string) ([]domain.Expense, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+expenseColumns+` FROM expenses
		 WHERE boat_id = $1
		 ORDER BY incurred_on DESC, created_at DESC`, boatID)
	if err != nil {
		return nil, fmt.Errorf("listing expenses: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Expense, 0)
	for rows.Next() {
		e, err := scanExpense(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *e)
	}
	return out, rows.Err()
}

// Delete removes an expense owned by the user.
func (r *ExpenseRepo) Delete(ctx context.Context, userID, id string) error {
	ct, err := r.pool.Exec(ctx,
		`DELETE FROM expenses WHERE user_id = $1 AND id = $2`, userID, id)
	if err != nil {
		return fmt.Errorf("deleting expense %s: %w", id, err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// TotalsByCategory sums expense amounts per category for a boat.
func (r *ExpenseRepo) TotalsByCategory(ctx context.Context, boatID string) (map[string]float64, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT category, SUM(amount) FROM expenses
		 WHERE boat_id = $1 GROUP BY category`, boatID)
	if err != nil {
		return nil, fmt.Errorf("summing expenses: %w", err)
	}
	defer rows.Close()
	totals := make(map[string]float64)
	for rows.Next() {
		var cat string
		var sum float64
		if err := rows.Scan(&cat, &sum); err != nil {
			return nil, err
		}
		totals[cat] = sum
	}
	return totals, rows.Err()
}
