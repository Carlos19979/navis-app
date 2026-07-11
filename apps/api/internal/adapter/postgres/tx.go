package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// txKey carries an open pgx.Tx through the context so repos participate in a
// service-initiated transaction without signature changes.
type txKey struct{}

// dbtx is the query surface shared by *pgxpool.Pool and pgx.Tx. Repos that can
// run inside a transaction resolve it with querier().
type dbtx interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// querier returns the transaction bound to ctx, or the pool when none is open.
func querier(ctx context.Context, pool *pgxpool.Pool) dbtx {
	if tx, ok := ctx.Value(txKey{}).(pgx.Tx); ok {
		return tx
	}
	return pool
}

// TxManager implements port.TxManager: services open the transaction, repos
// called with the returned context run inside it.
type TxManager struct {
	pool *pgxpool.Pool
}

// NewTxManager creates a TxManager on the given pool.
func NewTxManager(pool *pgxpool.Pool) *TxManager {
	return &TxManager{pool: pool}
}

// WithinTx runs fn inside a transaction. Any error (or panic) rolls back;
// otherwise the transaction commits.
func (m *TxManager) WithinTx(ctx context.Context, fn func(ctx context.Context) error) error {
	tx, err := m.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer func() {
		// No-op after a successful commit.
		if rbErr := tx.Rollback(ctx); rbErr != nil && !errors.Is(rbErr, pgx.ErrTxClosed) {
			_ = rbErr
		}
	}()

	if err := fn(context.WithValue(ctx, txKey{}, tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
