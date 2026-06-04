package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// TripChecklistRepo implements port.TripChecklistRepository using PostgreSQL.
type TripChecklistRepo struct {
	pool *pgxpool.Pool
}

// NewTripChecklistRepo creates a new TripChecklistRepo.
func NewTripChecklistRepo(pool *pgxpool.Pool) *TripChecklistRepo {
	return &TripChecklistRepo{pool: pool}
}

const checklistItemColumns = `id, trip_id, label, is_checked, position, created_at, updated_at`

func scanChecklistItem(row pgx.Row) (*domain.ChecklistItem, error) {
	i := &domain.ChecklistItem{}
	err := row.Scan(&i.ID, &i.TripID, &i.Label, &i.IsChecked, &i.Position, &i.CreatedAt, &i.UpdatedAt)
	return i, err
}

// CopyDefaults seeds a trip's checklist from the default items, but only if the
// trip has no checklist items yet (idempotent).
func (r *TripChecklistRepo) CopyDefaults(ctx context.Context, tripID string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO trip_checklist_items (trip_id, label, position)
		 SELECT $1, d.label, d.position FROM checklist_default_items d
		 WHERE NOT EXISTS (SELECT 1 FROM trip_checklist_items WHERE trip_id = $1)`,
		tripID)
	if err != nil {
		return fmt.Errorf("copying default checklist for trip %s: %w", tripID, err)
	}
	return nil
}

// Count returns the number of checklist items attached to a trip.
func (r *TripChecklistRepo) Count(ctx context.Context, tripID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT count(*) FROM trip_checklist_items WHERE trip_id = $1`, tripID).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("counting checklist items for trip %s: %w", tripID, err)
	}
	return n, nil
}

// ListByTrip returns all checklist items for a trip, ordered by position.
func (r *TripChecklistRepo) ListByTrip(ctx context.Context, tripID string) ([]domain.ChecklistItem, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+checklistItemColumns+` FROM trip_checklist_items
		 WHERE trip_id = $1 ORDER BY position ASC, created_at ASC`,
		tripID)
	if err != nil {
		return nil, fmt.Errorf("listing checklist for trip %s: %w", tripID, err)
	}
	defer rows.Close()

	items := make([]domain.ChecklistItem, 0)
	for rows.Next() {
		i := domain.ChecklistItem{}
		if err := rows.Scan(&i.ID, &i.TripID, &i.Label, &i.IsChecked, &i.Position, &i.CreatedAt, &i.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scanning checklist item for trip %s: %w", tripID, err)
		}
		items = append(items, i)
	}
	return items, rows.Err()
}

// AddItem appends a new checklist item to a trip.
func (r *TripChecklistRepo) AddItem(ctx context.Context, tripID, label string, position int) (*domain.ChecklistItem, error) {
	item, err := scanChecklistItem(r.pool.QueryRow(ctx,
		`INSERT INTO trip_checklist_items (trip_id, label, position)
		 VALUES ($1, $2, $3) RETURNING `+checklistItemColumns,
		tripID, label, position))
	if err != nil {
		return nil, fmt.Errorf("adding checklist item to trip %s: %w", tripID, err)
	}
	return item, nil
}

// SetChecked updates the checked state of a checklist item scoped to its trip.
func (r *TripChecklistRepo) SetChecked(ctx context.Context, tripID, itemID string, checked bool) (*domain.ChecklistItem, error) {
	item, err := scanChecklistItem(r.pool.QueryRow(ctx,
		`UPDATE trip_checklist_items SET is_checked = $3, updated_at = now()
		 WHERE id = $2 AND trip_id = $1 RETURNING `+checklistItemColumns,
		tripID, itemID, checked))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("updating checklist item %s: %w", itemID, err)
	}
	return item, nil
}

// RemoveItem deletes a checklist item scoped to its trip.
func (r *TripChecklistRepo) RemoveItem(ctx context.Context, tripID, itemID string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM trip_checklist_items WHERE id = $2 AND trip_id = $1`,
		tripID, itemID)
	if err != nil {
		return fmt.Errorf("removing checklist item %s: %w", itemID, err)
	}
	if result.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
