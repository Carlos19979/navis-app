package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// ExpenseSplitRepo implements port.ExpenseSplitRepository using PostgreSQL.
type ExpenseSplitRepo struct {
	pool *pgxpool.Pool
}

// NewExpenseSplitRepo creates a new ExpenseSplitRepo.
func NewExpenseSplitRepo(pool *pgxpool.Pool) *ExpenseSplitRepo {
	return &ExpenseSplitRepo{pool: pool}
}

// ReplaceForExpense atomically replaces all splits for an expense.
func (r *ExpenseSplitRepo) ReplaceForExpense(ctx context.Context, expenseID string, splits []domain.ExpenseSplit) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin split tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx,
		`DELETE FROM expense_splits WHERE expense_id = $1`, expenseID); err != nil {
		return fmt.Errorf("clearing splits: %w", err)
	}

	batch := &pgx.Batch{}
	for _, s := range splits {
		batch.Queue(
			`INSERT INTO expense_splits (expense_id, user_id, share_amount) VALUES ($1,$2,$3)`,
			expenseID, s.UserID, s.ShareAmount)
	}
	br := tx.SendBatch(ctx, batch)
	for range splits {
		if _, err := br.Exec(); err != nil {
			_ = br.Close()
			return fmt.Errorf("inserting split: %w", err)
		}
	}
	if err := br.Close(); err != nil {
		return fmt.Errorf("closing split batch: %w", err)
	}
	return tx.Commit(ctx)
}

// ListByExpense returns the splits for an expense.
func (r *ExpenseSplitRepo) ListByExpense(ctx context.Context, expenseID string) ([]domain.ExpenseSplit, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, expense_id, user_id, share_amount, settled_at, created_at
		 FROM expense_splits WHERE expense_id = $1 ORDER BY created_at ASC`, expenseID)
	if err != nil {
		return nil, fmt.Errorf("listing splits: %w", err)
	}
	defer rows.Close()

	var out []domain.ExpenseSplit
	for rows.Next() {
		var s domain.ExpenseSplit
		if err := rows.Scan(&s.ID, &s.ExpenseID, &s.UserID, &s.ShareAmount,
			&s.SettledAt, &s.CreatedAt); err != nil {
			return nil, fmt.Errorf("scanning split: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// SummaryByBoat rolls up splits per expense for a boat, including the viewer's
// own share and settled state. Only expenses that have splits are returned.
func (r *ExpenseSplitRepo) SummaryByBoat(ctx context.Context, boatID, viewerID string) ([]domain.ExpenseSplitSummary, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT s.expense_id,
		       COUNT(*) AS cnt,
		       SUM(s.share_amount) FILTER (WHERE s.user_id = $2) AS my_share,
		       COALESCE(bool_or(s.settled_at IS NOT NULL) FILTER (WHERE s.user_id = $2), false) AS my_settled
		FROM expense_splits s
		JOIN expenses e ON e.id = s.expense_id
		WHERE e.boat_id = $1
		GROUP BY s.expense_id`, boatID, viewerID)
	if err != nil {
		return nil, fmt.Errorf("split summary: %w", err)
	}
	defer rows.Close()

	var out []domain.ExpenseSplitSummary
	for rows.Next() {
		var s domain.ExpenseSplitSummary
		if err := rows.Scan(&s.ExpenseID, &s.Count, &s.MyShare, &s.MySettled); err != nil {
			return nil, fmt.Errorf("scanning split summary: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// SetSettled marks a split settled (or not).
func (r *ExpenseSplitRepo) SetSettled(ctx context.Context, splitID string, settled bool) error {
	var expr string
	if settled {
		expr = "now()"
	} else {
		expr = "NULL"
	}
	ct, err := r.pool.Exec(ctx,
		`UPDATE expense_splits SET settled_at = `+expr+` WHERE id = $1`, splitID)
	if err != nil {
		return fmt.Errorf("settling split %s: %w", splitID, err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
