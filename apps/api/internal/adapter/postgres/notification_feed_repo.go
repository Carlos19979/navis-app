package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// notificationColumns is the column list shared by the feed queries.
const notificationColumns = `id, user_id, category, title, body, link_type, link_id, read_at, created_at`

// NotificationFeedRepo implements port.NotificationFeedRepository using PostgreSQL.
type NotificationFeedRepo struct {
	pool *pgxpool.Pool
}

// NewNotificationFeedRepo creates a new NotificationFeedRepo.
func NewNotificationFeedRepo(pool *pgxpool.Pool) *NotificationFeedRepo {
	return &NotificationFeedRepo{pool: pool}
}

// Create stores a delivered notification.
func (r *NotificationFeedRepo) Create(ctx context.Context, n *domain.Notification) error {
	_, err := querier(ctx, r.pool).Exec(ctx, `
		INSERT INTO notifications (user_id, category, title, body, link_type, link_id)
		VALUES ($1, $2, $3, $4, $5, $6)`,
		n.UserID, string(n.Category), n.Title, n.Body, n.LinkType, n.LinkID,
	)
	if err != nil {
		return fmt.Errorf("creating notification: %w", err)
	}
	return nil
}

// List returns the user's notifications newest-first, keyset-paginated on
// (created_at, id). Fetches limit+1 to detect a next page.
func (r *NotificationFeedRepo) List(
	ctx context.Context, userID, cursor string, limit int,
) ([]domain.Notification, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursorTime, cursorID, ok := pagination.DecodeKeysetTime(cursor); ok {
		rows, err = querier(ctx, r.pool).Query(ctx, `
			SELECT `+notificationColumns+` FROM notifications
			WHERE user_id = $1 AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`, userID, cursorTime, cursorID, limit+1)
	} else {
		rows, err = querier(ctx, r.pool).Query(ctx, `
			SELECT `+notificationColumns+` FROM notifications
			WHERE user_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT $2`, userID, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing notifications: %w", err)
	}
	defer rows.Close()

	items := make([]domain.Notification, 0, limit)
	for rows.Next() {
		var n domain.Notification
		var category string
		if err := rows.Scan(
			&n.ID, &n.UserID, &category, &n.Title, &n.Body,
			&n.LinkType, &n.LinkID, &n.ReadAt, &n.CreatedAt,
		); err != nil {
			return nil, "", fmt.Errorf("scanning notification row: %w", err)
		}
		n.Category = domain.NotificationCategory(category)
		items = append(items, n)
	}
	if err := rows.Err(); err != nil {
		return nil, "", fmt.Errorf("iterating notification rows: %w", err)
	}

	var nextCursor string
	if len(items) > limit {
		items = items[:limit]
		last := items[limit-1]
		nextCursor = pagination.EncodeKeysetTime(last.CreatedAt, last.ID)
	}
	return items, nextCursor, nil
}

// UnreadCount counts the user's unread notifications (badge value).
func (r *NotificationFeedRepo) UnreadCount(ctx context.Context, userID string) (int, error) {
	var count int
	err := querier(ctx, r.pool).QueryRow(ctx,
		`SELECT count(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL`,
		userID,
	).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("counting unread notifications: %w", err)
	}
	return count, nil
}

// MarkRead marks one notification as read. Marking an already-read
// notification is a no-op; an unknown id (or another user's) is ErrNotFound.
func (r *NotificationFeedRepo) MarkRead(ctx context.Context, userID, id string) error {
	tag, err := querier(ctx, r.pool).Exec(ctx, `
		UPDATE notifications SET read_at = coalesce(read_at, now())
		WHERE user_id = $1 AND id = $2`, userID, id)
	if err != nil {
		return fmt.Errorf("marking notification read: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// MarkAllRead marks every unread notification of the user as read.
func (r *NotificationFeedRepo) MarkAllRead(ctx context.Context, userID string) error {
	_, err := querier(ctx, r.pool).Exec(ctx, `
		UPDATE notifications SET read_at = now()
		WHERE user_id = $1 AND read_at IS NULL`, userID)
	if err != nil {
		return fmt.Errorf("marking all notifications read: %w", err)
	}
	return nil
}

// NotificationPrefsRepo implements port.NotificationPrefsRepository using PostgreSQL.
type NotificationPrefsRepo struct {
	pool *pgxpool.Pool
}

// NewNotificationPrefsRepo creates a new NotificationPrefsRepo.
func NewNotificationPrefsRepo(pool *pgxpool.Pool) *NotificationPrefsRepo {
	return &NotificationPrefsRepo{pool: pool}
}

// ListMuted returns the categories the user has muted (rows present = muted).
func (r *NotificationPrefsRepo) ListMuted(
	ctx context.Context, userID string,
) ([]domain.NotificationCategory, error) {
	rows, err := querier(ctx, r.pool).Query(ctx,
		`SELECT category FROM notification_mutes WHERE user_id = $1`, userID)
	if err != nil {
		return nil, fmt.Errorf("listing muted categories: %w", err)
	}
	defer rows.Close()

	muted := make([]domain.NotificationCategory, 0)
	for rows.Next() {
		var category string
		if err := rows.Scan(&category); err != nil {
			return nil, fmt.Errorf("scanning muted category: %w", err)
		}
		muted = append(muted, domain.NotificationCategory(category))
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating muted categories: %w", err)
	}
	return muted, nil
}

// ReplaceMuted makes muted the user's complete set of muted categories. Both
// statements run in one transaction so a failed insert cannot leave the user
// with everything un-muted.
func (r *NotificationPrefsRepo) ReplaceMuted(
	ctx context.Context, userID string, muted []domain.NotificationCategory,
) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin notification prefs tx: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx,
		`DELETE FROM notification_mutes WHERE user_id = $1`, userID); err != nil {
		return fmt.Errorf("clearing muted categories: %w", err)
	}

	if len(muted) > 0 {
		batch := &pgx.Batch{}
		for _, category := range muted {
			batch.Queue(`
				INSERT INTO notification_mutes (user_id, category)
				VALUES ($1, $2) ON CONFLICT DO NOTHING`, userID, string(category))
		}
		if err := tx.SendBatch(ctx, batch).Close(); err != nil {
			return fmt.Errorf("inserting muted categories: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit notification prefs tx: %w", err)
	}
	return nil
}
