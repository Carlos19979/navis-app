package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// --- mock DocumentRepository ---

type mockDocumentRepo struct {
	createFn       func(ctx context.Context, doc *domain.Document) (*domain.Document, error)
	getByIDFn      func(ctx context.Context, userID, id string) (*domain.Document, error)
	listFn         func(ctx context.Context, userID, cursor string, limit int) ([]domain.Document, string, error)
	listByBoatFn   func(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Document, string, error)
	listExpiringFn func(ctx context.Context, withinDays int) ([]domain.Document, error)
	updateFn       func(ctx context.Context, userID string, doc *domain.Document) (*domain.Document, error)
	deleteFn       func(ctx context.Context, userID, id string) error
}

func (m *mockDocumentRepo) Create(ctx context.Context, doc *domain.Document) (*domain.Document, error) {
	return m.createFn(ctx, doc)
}

func (m *mockDocumentRepo) GetByID(ctx context.Context, userID, id string) (*domain.Document, error) {
	return m.getByIDFn(ctx, userID, id)
}

func (m *mockDocumentRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Document, string, error) {
	return m.listFn(ctx, userID, cursor, limit)
}

func (m *mockDocumentRepo) ListByBoat(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Document, string, error) {
	return m.listByBoatFn(ctx, userID, boatID, cursor, limit)
}

func (m *mockDocumentRepo) ListExpiring(ctx context.Context, withinDays int) ([]domain.Document, error) {
	return m.listExpiringFn(ctx, withinDays)
}

func (m *mockDocumentRepo) Update(ctx context.Context, userID string, doc *domain.Document) (*domain.Document, error) {
	return m.updateFn(ctx, userID, doc)
}

func (m *mockDocumentRepo) Delete(ctx context.Context, userID, id string) error {
	return m.deleteFn(ctx, userID, id)
}

// --- helpers ---

func newTestDocument() *domain.Document {
	return &domain.Document{
		ID:         "doc-1",
		BoatID:     "boat-1",
		UserID:     "user-1",
		Type:       domain.DocumentTypeITB,
		ExpiryDate: time.Now().Add(180 * 24 * time.Hour), // 180 days from now
		AlertDays:  []int{30, 7},
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}
}

func boatOwnershipRepo() *mockBoatRepo {
	return &mockBoatRepo{
		getByIDFn: func(_ context.Context, userID, _ string) (*domain.Boat, error) {
			if userID == "user-1" {
				return newTestBoat(), nil
			}
			return nil, domain.ErrBoatNotFound
		},
	}
}

// --- Create tests ---

func TestDocumentService_Create_Success(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	docRepo := &mockDocumentRepo{
		createFn: func(_ context.Context, d *domain.Document) (*domain.Document, error) {
			d.ID = "doc-1"
			return d, nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	result, err := svc.Create(context.Background(), doc)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "doc-1" {
		t.Errorf("expected doc ID %q, got %q", "doc-1", result.ID)
	}
	// Status should be computed as OK since expiry is 180 days away.
	if result.Status != domain.DocumentStatusOK {
		t.Errorf("expected status %q, got %q", domain.DocumentStatusOK, result.Status)
	}
}

func TestDocumentService_Create_EmptyUserID(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	doc.UserID = ""
	docRepo := &mockDocumentRepo{}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	_, err := svc.Create(context.Background(), doc)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrUnauthorized) {
		t.Errorf("expected ErrUnauthorized, got %v", err)
	}
}

func TestDocumentService_Create_BoatNotFound(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	boatRepo := &mockBoatRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Boat, error) {
			return nil, domain.ErrBoatNotFound
		},
	}
	docRepo := &mockDocumentRepo{}
	svc := NewDocumentService(docRepo, boatRepo)

	_, err := svc.Create(context.Background(), doc)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("expected ErrBoatNotFound, got %v", err)
	}
}

func TestDocumentService_Create_BoatNotOwnedByUser(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	doc.UserID = "other-user" // Different from boat owner
	boatRepo := &mockBoatRepo{
		getByIDFn: func(_ context.Context, userID, _ string) (*domain.Boat, error) {
			if userID == "other-user" {
				return nil, domain.ErrBoatNotFound
			}
			return newTestBoat(), nil
		},
	}
	docRepo := &mockDocumentRepo{}
	svc := NewDocumentService(docRepo, boatRepo)

	_, err := svc.Create(context.Background(), doc)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("expected ErrBoatNotFound, got %v", err)
	}
}

func TestDocumentService_Create_RepoError(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	repoErr := errors.New("insert failed")
	docRepo := &mockDocumentRepo{
		createFn: func(_ context.Context, _ *domain.Document) (*domain.Document, error) {
			return nil, repoErr
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	_, err := svc.Create(context.Background(), doc)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- GetByID tests ---

func TestDocumentService_GetByID_Success(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	docRepo := &mockDocumentRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Document, error) {
			return doc, nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	result, err := svc.GetByID(context.Background(), "user-1", "doc-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "doc-1" {
		t.Errorf("expected doc ID %q, got %q", "doc-1", result.ID)
	}
}

func TestDocumentService_GetByID_NotFound(t *testing.T) {
	t.Parallel()

	docRepo := &mockDocumentRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Document, error) {
			return nil, domain.ErrDocumentNotFound
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	_, err := svc.GetByID(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrDocumentNotFound) {
		t.Errorf("expected ErrDocumentNotFound, got %v", err)
	}
}

// --- List tests ---

func TestDocumentService_List_Success(t *testing.T) {
	t.Parallel()

	docs := []domain.Document{*newTestDocument()}
	docRepo := &mockDocumentRepo{
		listFn: func(_ context.Context, _ string, _ string, _ int) ([]domain.Document, string, error) {
			return docs, "next-cursor", nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	result, cursor, err := svc.List(context.Background(), "user-1", "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 document, got %d", len(result))
	}
	if cursor != "next-cursor" {
		t.Errorf("expected cursor %q, got %q", "next-cursor", cursor)
	}
}

func TestDocumentService_List_DefaultLimit(t *testing.T) {
	t.Parallel()

	var capturedLimit int
	docRepo := &mockDocumentRepo{
		listFn: func(_ context.Context, _ string, _ string, limit int) ([]domain.Document, string, error) {
			capturedLimit = limit
			return []domain.Document{}, "", nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	tests := []struct {
		name          string
		inputLimit    int
		expectedLimit int
	}{
		{"zero limit defaults to 20", 0, 20},
		{"negative limit defaults to 20", -1, 20},
		{"over 50 defaults to 20", 51, 20},
		{"valid limit preserved", 25, 25},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, _ = svc.List(context.Background(), "user-1", "", tt.inputLimit)
			if capturedLimit != tt.expectedLimit {
				t.Errorf("expected limit %d, got %d", tt.expectedLimit, capturedLimit)
			}
		})
	}
}

// --- ListByBoat tests ---

func TestDocumentService_ListByBoat_Success(t *testing.T) {
	t.Parallel()

	docs := []domain.Document{*newTestDocument()}
	docRepo := &mockDocumentRepo{
		listByBoatFn: func(_ context.Context, _, boatID, _ string, _ int) ([]domain.Document, string, error) {
			if boatID != "boat-1" {
				return nil, "", errors.New("unexpected boatID")
			}
			return docs, "cursor-2", nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	result, cursor, err := svc.ListByBoat(context.Background(), "user-1", "boat-1", "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 document, got %d", len(result))
	}
	if cursor != "cursor-2" {
		t.Errorf("expected cursor %q, got %q", "cursor-2", cursor)
	}
}

func TestDocumentService_ListByBoat_DefaultLimit(t *testing.T) {
	t.Parallel()

	var capturedLimit int
	docRepo := &mockDocumentRepo{
		listByBoatFn: func(_ context.Context, _, _, _ string, limit int) ([]domain.Document, string, error) {
			capturedLimit = limit
			return []domain.Document{}, "", nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	_, _, _ = svc.ListByBoat(context.Background(), "user-1", "boat-1", "", 0)
	if capturedLimit != 20 {
		t.Errorf("expected default limit 20, got %d", capturedLimit)
	}
}

// --- Update tests ---

func TestDocumentService_Update_Success(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	existingDoc := newTestDocument()

	docRepo := &mockDocumentRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Document, error) {
			return existingDoc, nil
		},
		updateFn: func(_ context.Context, _ string, d *domain.Document) (*domain.Document, error) {
			return d, nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	result, err := svc.Update(context.Background(), "user-1", doc)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "doc-1" {
		t.Errorf("expected doc ID %q, got %q", "doc-1", result.ID)
	}
}

func TestDocumentService_Update_EmptyID(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	doc.ID = ""
	docRepo := &mockDocumentRepo{}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	_, err := svc.Update(context.Background(), "user-1", doc)
	if err == nil {
		t.Fatal("expected error, got nil")
	}

	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
	if ve.Field != "id" {
		t.Errorf("expected field %q, got %q", "id", ve.Field)
	}
}

func TestDocumentService_Update_NotFound(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	docRepo := &mockDocumentRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Document, error) {
			return nil, domain.ErrDocumentNotFound
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	_, err := svc.Update(context.Background(), "user-1", doc)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrDocumentNotFound) {
		t.Errorf("expected ErrDocumentNotFound, got %v", err)
	}
}

func TestDocumentService_Update_BoatOwnershipFails(t *testing.T) {
	t.Parallel()

	doc := newTestDocument()
	existingDoc := newTestDocument()

	docRepo := &mockDocumentRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Document, error) {
			return existingDoc, nil
		},
	}
	boatRepo := &mockBoatRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Boat, error) {
			return nil, domain.ErrBoatNotFound
		},
	}
	svc := NewDocumentService(docRepo, boatRepo)

	_, err := svc.Update(context.Background(), "user-1", doc)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("expected ErrBoatNotFound, got %v", err)
	}
}

// --- Delete tests ---

func TestDocumentService_Delete_Success(t *testing.T) {
	t.Parallel()

	docRepo := &mockDocumentRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	err := svc.Delete(context.Background(), "user-1", "doc-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestDocumentService_Delete_NotFound(t *testing.T) {
	t.Parallel()

	docRepo := &mockDocumentRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return domain.ErrDocumentNotFound
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	err := svc.Delete(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrDocumentNotFound) {
		t.Errorf("expected ErrDocumentNotFound, got %v", err)
	}
}

// --- CheckExpirations tests ---

func TestDocumentService_CheckExpirations_Success(t *testing.T) {
	t.Parallel()

	docs := []domain.Document{
		{
			ID:         "doc-exp",
			ExpiryDate: time.Now().Add(-1 * 24 * time.Hour), // Expired yesterday
			AlertDays:  []int{30, 7},
		},
		{
			ID:         "doc-ok",
			ExpiryDate: time.Now().Add(180 * 24 * time.Hour), // OK
			AlertDays:  []int{30, 7},
		},
	}
	docRepo := &mockDocumentRepo{
		listExpiringFn: func(_ context.Context, withinDays int) ([]domain.Document, error) {
			if withinDays != 90 {
				t.Errorf("expected withinDays 90, got %d", withinDays)
			}
			return docs, nil
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	result, err := svc.CheckExpirations(context.Background())
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 2 {
		t.Fatalf("expected 2 documents, got %d", len(result))
	}
	if result[0].Status != domain.DocumentStatusExpired {
		t.Errorf("expected first doc status %q, got %q", domain.DocumentStatusExpired, result[0].Status)
	}
	if result[1].Status != domain.DocumentStatusOK {
		t.Errorf("expected second doc status %q, got %q", domain.DocumentStatusOK, result[1].Status)
	}
}

func TestDocumentService_CheckExpirations_RepoError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("db error")
	docRepo := &mockDocumentRepo{
		listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
			return nil, repoErr
		},
	}
	svc := NewDocumentService(docRepo, boatOwnershipRepo())

	_, err := svc.CheckExpirations(context.Background())
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- computeStatus tests (status computation) ---

func TestComputeStatus_OK(t *testing.T) {
	t.Parallel()

	// Expiry 180 days from now: well beyond any alert window.
	expiry := time.Now().Add(180 * 24 * time.Hour)
	alertDays := []int{30, 7}

	status := computeStatus(expiry, alertDays)
	if status != domain.DocumentStatusOK {
		t.Errorf("expected %q, got %q", domain.DocumentStatusOK, status)
	}
}

func TestComputeStatus_Warning(t *testing.T) {
	t.Parallel()

	// Expiry 20 days from now: within the 30-day warning window.
	expiry := time.Now().Add(20 * 24 * time.Hour)
	alertDays := []int{30, 7}

	status := computeStatus(expiry, alertDays)
	if status != domain.DocumentStatusWarning {
		t.Errorf("expected %q, got %q", domain.DocumentStatusWarning, status)
	}
}

func TestComputeStatus_Critical(t *testing.T) {
	t.Parallel()

	// Expiry 5 days from now: within the 7-day critical window.
	expiry := time.Now().Add(5 * 24 * time.Hour)
	alertDays := []int{30, 7}

	status := computeStatus(expiry, alertDays)
	if status != domain.DocumentStatusCritical {
		t.Errorf("expected %q, got %q", domain.DocumentStatusCritical, status)
	}
}

func TestComputeStatus_Expired(t *testing.T) {
	t.Parallel()

	// Expiry was yesterday.
	expiry := time.Now().Add(-2 * 24 * time.Hour)
	alertDays := []int{30, 7}

	status := computeStatus(expiry, alertDays)
	if status != domain.DocumentStatusExpired {
		t.Errorf("expected %q, got %q", domain.DocumentStatusExpired, status)
	}
}

func TestComputeStatus_NoAlertDays(t *testing.T) {
	t.Parallel()

	// With no alert days configured, only expired or OK.
	expiry := time.Now().Add(5 * 24 * time.Hour)
	var alertDays []int

	status := computeStatus(expiry, alertDays)
	if status != domain.DocumentStatusOK {
		t.Errorf("expected %q with no alert days, got %q", domain.DocumentStatusOK, status)
	}
}

func TestComputeStatus_OnlyWarningDays(t *testing.T) {
	t.Parallel()

	// Alert days with only warning thresholds (>7), no critical.
	expiry := time.Now().Add(5 * 24 * time.Hour)
	alertDays := []int{30}

	status := computeStatus(expiry, alertDays)
	// 30 is a warning threshold (>7), and 5 days left is within 30.
	if status != domain.DocumentStatusWarning {
		t.Errorf("expected %q, got %q", domain.DocumentStatusWarning, status)
	}
}

func TestComputeStatus_OnlyCriticalDays(t *testing.T) {
	t.Parallel()

	// Alert days with only critical thresholds (<=7).
	expiry := time.Now().Add(5 * 24 * time.Hour)
	alertDays := []int{7}

	status := computeStatus(expiry, alertDays)
	if status != domain.DocumentStatusCritical {
		t.Errorf("expected %q, got %q", domain.DocumentStatusCritical, status)
	}
}

func TestComputeStatus_BoundaryExactlyOnWarningDay(t *testing.T) {
	t.Parallel()

	// Expiry exactly 30 days from now. daysUntilExpiry will be ~29 or 30
	// depending on time-of-day. Use 30.5 days to be safe.
	expiry := time.Now().Add(30*24*time.Hour + 12*time.Hour)
	alertDays := []int{30, 7}

	status := computeStatus(expiry, alertDays)
	if status != domain.DocumentStatusWarning {
		t.Errorf("expected %q at boundary, got %q", domain.DocumentStatusWarning, status)
	}
}

func (m *mockDocumentRepo) GetByIDUnscoped(_ context.Context, id string) (*domain.Document, error) {
	return m.GetByID(context.Background(), "", id)
}
