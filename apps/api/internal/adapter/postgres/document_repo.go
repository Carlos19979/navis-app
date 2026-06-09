package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// DocumentRepo implements port.DocumentRepository using PostgreSQL.
type DocumentRepo struct {
	pool *pgxpool.Pool
}

// NewDocumentRepo creates a new DocumentRepo.
func NewDocumentRepo(pool *pgxpool.Pool) *DocumentRepo {
	return &DocumentRepo{pool: pool}
}

// documentColumns is the shared column list for document queries.
const documentColumns = `id, boat_id, user_id, type, custom_name, expiry_date, status,
	photo_url, notes, last_renewal_date, last_renewal_cost, last_renewal_provider,
	alert_days, created_at, updated_at`

// scanDocument scans a single row into a domain.Document.
func scanDocument(row pgx.Row) (*domain.Document, error) {
	d := &domain.Document{}
	err := row.Scan(
		&d.ID, &d.BoatID, &d.UserID, &d.Type, &d.CustomName, &d.ExpiryDate, &d.Status,
		&d.PhotoURL, &d.Notes, &d.LastRenewalDate, &d.LastRenewalCost, &d.LastRenewalProvider,
		&d.AlertDays, &d.CreatedAt, &d.UpdatedAt,
	)
	return d, err
}

// scanDocuments scans multiple rows into a slice of domain.Document.
func scanDocuments(rows pgx.Rows) ([]domain.Document, error) {
	var docs []domain.Document
	for rows.Next() {
		d := domain.Document{}
		if err := rows.Scan(
			&d.ID, &d.BoatID, &d.UserID, &d.Type, &d.CustomName, &d.ExpiryDate, &d.Status,
			&d.PhotoURL, &d.Notes, &d.LastRenewalDate, &d.LastRenewalCost, &d.LastRenewalProvider,
			&d.AlertDays, &d.CreatedAt, &d.UpdatedAt,
		); err != nil {
			return nil, err
		}
		docs = append(docs, d)
	}
	return docs, rows.Err()
}

// Create inserts a new document and returns the created record.
func (r *DocumentRepo) Create(ctx context.Context, doc *domain.Document) (*domain.Document, error) {
	query := `
		INSERT INTO documents (boat_id, user_id, type, custom_name, expiry_date, status,
			photo_url, notes, last_renewal_date, last_renewal_cost, last_renewal_provider, alert_days)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING ` + documentColumns

	d, err := scanDocument(r.pool.QueryRow(ctx, query,
		doc.BoatID, doc.UserID, doc.Type, doc.CustomName, doc.ExpiryDate, doc.Status,
		doc.PhotoURL, doc.Notes, doc.LastRenewalDate, doc.LastRenewalCost,
		doc.LastRenewalProvider, doc.AlertDays,
	))
	if err != nil {
		return nil, fmt.Errorf("inserting document: %w", err)
	}
	return d, nil
}

// GetByID retrieves a document by ID, scoped to the given user.
func (r *DocumentRepo) GetByID(ctx context.Context, userID, id string) (*domain.Document, error) {
	query := `SELECT ` + documentColumns + ` FROM documents WHERE user_id = $1 AND id = $2`

	d, err := scanDocument(r.pool.QueryRow(ctx, query, userID, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrDocumentNotFound
		}
		return nil, fmt.Errorf("getting document %s: %w", id, err)
	}
	return d, nil
}

// GetByIDUnscoped retrieves a document by ID without a user filter. Callers
// must enforce their own authorization (e.g., shared boat access).
func (r *DocumentRepo) GetByIDUnscoped(ctx context.Context, id string) (*domain.Document, error) {
	query := `SELECT ` + documentColumns + ` FROM documents WHERE id = $1`
	d, err := scanDocument(r.pool.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrDocumentNotFound
		}
		return nil, fmt.Errorf("getting document %s: %w", id, err)
	}
	return d, nil
}

// List returns a paginated list of all documents for a user.
func (r *DocumentRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Document, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + documentColumns + ` FROM documents
			WHERE user_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, userID, limit+1)
	} else {
		var cursorCreatedAt time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT created_at FROM documents WHERE id = $1`, cursor,
		).Scan(&cursorCreatedAt)
		if cErr != nil {
			return r.List(ctx, userID, "", limit)
		}

		query := `SELECT ` + documentColumns + ` FROM documents
			WHERE user_id = $1 AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, userID, cursorCreatedAt, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing documents: %w", err)
	}
	defer rows.Close()

	docs, err := scanDocuments(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning documents: %w", err)
	}

	var nextCursor string
	if len(docs) > limit {
		nextCursor = docs[limit].ID
		docs = docs[:limit]
	}

	return docs, nextCursor, nil
}

// ListByBoat returns a paginated list of documents for a specific boat.
func (r *DocumentRepo) ListByBoat(ctx context.Context, boatID, cursor string, limit int) ([]domain.Document, string, error) {
	var (
		rows pgx.Rows
		err  error
	)

	if cursor == "" {
		query := `SELECT ` + documentColumns + ` FROM documents
			WHERE boat_id = $1
			ORDER BY created_at DESC, id DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, query, boatID, limit+1)
	} else {
		var cursorCreatedAt time.Time
		cErr := r.pool.QueryRow(ctx,
			`SELECT created_at FROM documents WHERE id = $1`, cursor,
		).Scan(&cursorCreatedAt)
		if cErr != nil {
			return r.ListByBoat(ctx, boatID, "", limit)
		}

		query := `SELECT ` + documentColumns + ` FROM documents
			WHERE boat_id = $1 AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`
		rows, err = r.pool.Query(ctx, query, boatID, cursorCreatedAt, cursor, limit+1)
	}
	if err != nil {
		return nil, "", fmt.Errorf("listing documents for boat %s: %w", boatID, err)
	}
	defer rows.Close()

	docs, err := scanDocuments(rows)
	if err != nil {
		return nil, "", fmt.Errorf("scanning documents: %w", err)
	}

	var nextCursor string
	if len(docs) > limit {
		nextCursor = docs[limit].ID
		docs = docs[:limit]
	}

	return docs, nextCursor, nil
}

// ListExpiring returns documents with expiry dates between now and now+withinDays.
// Results include the boat name via a JOIN for notification purposes.
func (r *DocumentRepo) ListExpiring(ctx context.Context, withinDays int) ([]domain.Document, error) {
	query := `
		SELECT d.id, d.boat_id, d.user_id, d.type, d.custom_name, d.expiry_date, d.status,
			d.photo_url, d.notes, d.last_renewal_date, d.last_renewal_cost, d.last_renewal_provider,
			d.alert_days, d.created_at, d.updated_at
		FROM documents d
		JOIN boats b ON b.id = d.boat_id
		WHERE d.expiry_date BETWEEN now() AND now() + ($1 || ' days')::interval
		ORDER BY d.expiry_date ASC`

	rows, err := r.pool.Query(ctx, query, fmt.Sprintf("%d", withinDays))
	if err != nil {
		return nil, fmt.Errorf("listing expiring documents: %w", err)
	}
	defer rows.Close()

	docs, err := scanDocuments(rows)
	if err != nil {
		return nil, fmt.Errorf("scanning expiring documents: %w", err)
	}

	return docs, nil
}

// Update modifies an existing document and returns the updated record.
func (r *DocumentRepo) Update(ctx context.Context, doc *domain.Document) (*domain.Document, error) {
	query := `
		UPDATE documents
		SET type = $3, custom_name = $4, expiry_date = $5, status = $6,
			photo_url = $7, notes = $8, last_renewal_date = $9, last_renewal_cost = $10,
			last_renewal_provider = $11, alert_days = $12, updated_at = now()
		WHERE id = $1 AND boat_id = $2
		RETURNING ` + documentColumns

	d, err := scanDocument(r.pool.QueryRow(ctx, query,
		doc.ID, doc.BoatID, doc.Type, doc.CustomName, doc.ExpiryDate, doc.Status,
		doc.PhotoURL, doc.Notes, doc.LastRenewalDate, doc.LastRenewalCost,
		doc.LastRenewalProvider, doc.AlertDays,
	))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrDocumentNotFound
		}
		return nil, fmt.Errorf("updating document %s: %w", doc.ID, err)
	}
	return d, nil
}

// Delete removes a document by ID, scoped to its boat.
func (r *DocumentRepo) Delete(ctx context.Context, boatID, id string) error {
	result, err := r.pool.Exec(ctx,
		`DELETE FROM documents WHERE boat_id = $1 AND id = $2`, boatID, id)
	if err != nil {
		return fmt.Errorf("deleting document %s: %w", id, err)
	}
	if result.RowsAffected() == 0 {
		return domain.ErrDocumentNotFound
	}
	return nil
}
