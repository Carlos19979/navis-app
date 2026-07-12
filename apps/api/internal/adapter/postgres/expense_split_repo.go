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
