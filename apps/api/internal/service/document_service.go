package service

import (
	"context"
	"fmt"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// DocumentService implements business logic for document operations.
type DocumentService struct {
	docRepo  port.DocumentRepository
	boatRepo port.BoatRepository
}

// NewDocumentService creates a new DocumentService.
func NewDocumentService(docRepo port.DocumentRepository, boatRepo port.BoatRepository) *DocumentService {
	return &DocumentService{
		docRepo:  docRepo,
		boatRepo: boatRepo,
	}
}

// Create persists a new document after validating boat ownership.
func (s *DocumentService) Create(ctx context.Context, doc *domain.Document) (*domain.Document, error) {
	if doc.UserID == "" {
		return nil, fmt.Errorf("creating document: %w", domain.ErrUnauthorized)
	}

	// Validate boat ownership.
	if _, err := s.boatRepo.GetByID(ctx, doc.UserID, doc.BoatID); err != nil {
		return nil, fmt.Errorf("creating document: boat ownership check: %w", err)
	}

	doc.Status = computeStatus(doc.ExpiryDate, doc.AlertDays)

	created, err := s.docRepo.Create(ctx, doc)
	if err != nil {
		return nil, fmt.Errorf("creating document: %w", err)
	}
	return created, nil
}

// GetByID retrieves a single document owned by the given user.
func (s *DocumentService) GetByID(ctx context.Context, userID, id string) (*domain.Document, error) {
	doc, err := s.docRepo.GetByID(ctx, userID, id)
	if err != nil {
		return nil, fmt.Errorf("getting document %s: %w", id, err)
	}
	return doc, nil
}

// List returns a paginated list of all documents for a user.
func (s *DocumentService) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Document, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	docs, nextCursor, err := s.docRepo.List(ctx, userID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing documents: %w", err)
	}
	return docs, nextCursor, nil
}

// ListByBoat returns documents for a specific boat.
func (s *DocumentService) ListByBoat(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Document, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	docs, nextCursor, err := s.docRepo.ListByBoat(ctx, userID, boatID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing documents for boat %s: %w", boatID, err)
	}
	return docs, nextCursor, nil
}

// Update modifies an existing document after validating boat ownership.
func (s *DocumentService) Update(ctx context.Context, userID string, doc *domain.Document) (*domain.Document, error) {
	if doc.ID == "" {
		return nil, &domain.ValidationError{Field: "id", Message: "id is required"}
	}

	// Verify the user owns the boat associated with this document.
	existing, err := s.docRepo.GetByID(ctx, userID, doc.ID)
	if err != nil {
		return nil, fmt.Errorf("updating document %s: %w", doc.ID, err)
	}

	if _, err := s.boatRepo.GetByID(ctx, userID, existing.BoatID); err != nil {
		return nil, fmt.Errorf("updating document: boat ownership check: %w", err)
	}

	doc.Status = computeStatus(doc.ExpiryDate, doc.AlertDays)

	updated, err := s.docRepo.Update(ctx, userID, doc)
	if err != nil {
		return nil, fmt.Errorf("updating document %s: %w", doc.ID, err)
	}
	return updated, nil
}

// Delete removes a document if owned by the user.
func (s *DocumentService) Delete(ctx context.Context, userID, id string) error {
	if err := s.docRepo.Delete(ctx, userID, id); err != nil {
		return fmt.Errorf("deleting document %s: %w", id, err)
	}
	return nil
}

// CheckExpirations finds documents expiring within the configured alert windows.
// It is intended to be called periodically by a cron job.
func (s *DocumentService) CheckExpirations(ctx context.Context) ([]domain.Document, error) {
	// Look ahead 90 days to cover the widest typical alert window.
	docs, err := s.docRepo.ListExpiring(ctx, 90)
	if err != nil {
		return nil, fmt.Errorf("checking expirations: %w", err)
	}

	// Recompute status for each document so callers get up-to-date values.
	for i := range docs {
		docs[i].Status = computeStatus(docs[i].ExpiryDate, docs[i].AlertDays)
	}

	return docs, nil
}

// computeStatus derives a DocumentStatus from the expiry date and the
// configured alert-day thresholds.
func computeStatus(expiry time.Time, alertDays []int) domain.DocumentStatus {
	daysUntilExpiry := int(time.Until(expiry).Hours() / 24)

	if daysUntilExpiry < 0 {
		return domain.DocumentStatusExpired
	}

	// Find the largest alert threshold that has been reached.
	maxCritical := 0
	maxWarning := 0
	for _, d := range alertDays {
		if d <= 7 && d > maxCritical {
			maxCritical = d
		}
		if d > 7 && d > maxWarning {
			maxWarning = d
		}
	}

	if maxCritical > 0 && daysUntilExpiry <= maxCritical {
		return domain.DocumentStatusCritical
	}
	if maxWarning > 0 && daysUntilExpiry <= maxWarning {
		return domain.DocumentStatusWarning
	}

	return domain.DocumentStatusOK
}
