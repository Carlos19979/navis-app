package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// ReportRepo implements port.ReportRepository using PostgreSQL.
type ReportRepo struct {
	pool *pgxpool.Pool
}

// NewReportRepo creates a new ReportRepo.
func NewReportRepo(pool *pgxpool.Pool) *ReportRepo {
	return &ReportRepo{pool: pool}
}

// Create stores a report. Re-reporting the same content by the same user is a
// no-op thanks to the unique (reporter, content) index.
func (r *ReportRepo) Create(ctx context.Context, report *domain.Report) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO content_reports (reporter_id, content_type, content_id, reason, note)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (reporter_id, content_type, content_id) DO NOTHING`,
		report.ReporterID, string(report.ContentType), report.ContentID,
		string(report.Reason), report.Note,
	)
	return err
}

// BlockRepo implements port.BlockRepository using PostgreSQL.
type BlockRepo struct {
	pool *pgxpool.Pool
}

// NewBlockRepo creates a new BlockRepo.
func NewBlockRepo(pool *pgxpool.Pool) *BlockRepo {
	return &BlockRepo{pool: pool}
}

// Block records that blockerID blocks blockedID (idempotent).
func (r *BlockRepo) Block(ctx context.Context, blockerID, blockedID string) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO blocked_users (blocker_id, blocked_id)
		VALUES ($1, $2)
		ON CONFLICT (blocker_id, blocked_id) DO NOTHING`,
		blockerID, blockedID,
	)
	return err
}

// Unblock removes the block from blockerID to blockedID (no-op if absent).
func (r *BlockRepo) Unblock(ctx context.Context, blockerID, blockedID string) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM blocked_users WHERE blocker_id = $1 AND blocked_id = $2`,
		blockerID, blockedID,
	)
	return err
}

// ListBlockedIDs returns the user IDs that blockerID has blocked.
func (r *BlockRepo) ListBlockedIDs(ctx context.Context, blockerID string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT blocked_id FROM blocked_users WHERE blocker_id = $1`, blockerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}
