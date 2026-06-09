package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// --- mock BoatRepository ---

type mockBoatRepo struct {
	createFn         func(ctx context.Context, boat *domain.Boat) (*domain.Boat, error)
	getByIDFn        func(ctx context.Context, userID, id string) (*domain.Boat, error)
	listFn           func(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error)
	updateFn         func(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error)
	deleteFn         func(ctx context.Context, userID, id string) error
	getPermissionsFn func(ctx context.Context, userID, boatID string) (domain.BoatPermissions, bool, error)
}

func (m *mockBoatRepo) Create(ctx context.Context, boat *domain.Boat) (*domain.Boat, error) {
	return m.createFn(ctx, boat)
}

func (m *mockBoatRepo) GetByID(ctx context.Context, userID, id string) (*domain.Boat, error) {
	return m.getByIDFn(ctx, userID, id)
}

func (m *mockBoatRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error) {
	return m.listFn(ctx, userID, cursor, limit)
}

func (m *mockBoatRepo) Update(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error) {
	return m.updateFn(ctx, userID, boat)
}

func (m *mockBoatRepo) Delete(ctx context.Context, userID, id string) error {
	return m.deleteFn(ctx, userID, id)
}

// --- helpers ---

func newTestBoat() *domain.Boat {
	return &domain.Boat{
		ID:           "boat-1",
		UserID:       "user-1",
		Name:         "Sea Breeze",
		Registration: "ES-1234-AB",
		Type:         domain.BoatTypeSailboat,
		LengthM:      12.5,
		HomePort:     "Valencia",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
}

// --- Create tests ---

func TestBoatService_Create_Success(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	repo := &mockBoatRepo{
		createFn: func(_ context.Context, b *domain.Boat) (*domain.Boat, error) {
			b.ID = "boat-1"
			return b, nil
		},
	}
	svc := NewBoatService(repo, nil)

	result, err := svc.Create(context.Background(), boat)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "boat-1" {
		t.Errorf("expected boat ID %q, got %q", "boat-1", result.ID)
	}
	if result.Name != "Sea Breeze" {
		t.Errorf("expected boat name %q, got %q", "Sea Breeze", result.Name)
	}
}

func TestBoatService_Create_EmptyName(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	boat.Name = ""
	repo := &mockBoatRepo{}
	svc := NewBoatService(repo, nil)

	_, err := svc.Create(context.Background(), boat)
	if err == nil {
		t.Fatal("expected error, got nil")
	}

	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
	if ve.Field != "name" {
		t.Errorf("expected field %q, got %q", "name", ve.Field)
	}
}

func TestBoatService_Create_EmptyUserID(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	boat.UserID = ""
	repo := &mockBoatRepo{}
	svc := NewBoatService(repo, nil)

	_, err := svc.Create(context.Background(), boat)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrUnauthorized) {
		t.Errorf("expected ErrUnauthorized, got %v", err)
	}
}

func TestBoatService_Create_DuplicateRegistration(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	repo := &mockBoatRepo{
		createFn: func(_ context.Context, _ *domain.Boat) (*domain.Boat, error) {
			return nil, domain.ErrDuplicateRegistration
		},
	}
	svc := NewBoatService(repo, nil)

	_, err := svc.Create(context.Background(), boat)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrDuplicateRegistration) {
		t.Errorf("expected ErrDuplicateRegistration, got %v", err)
	}
}

func TestBoatService_Create_RepoError(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	repoErr := errors.New("connection refused")
	repo := &mockBoatRepo{
		createFn: func(_ context.Context, _ *domain.Boat) (*domain.Boat, error) {
			return nil, repoErr
		},
	}
	svc := NewBoatService(repo, nil)

	_, err := svc.Create(context.Background(), boat)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- GetByID tests ---

func TestBoatService_GetByID_Success(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	repo := &mockBoatRepo{
		getByIDFn: func(_ context.Context, userID, id string) (*domain.Boat, error) {
			if userID != "user-1" || id != "boat-1" {
				return nil, domain.ErrBoatNotFound
			}
			return boat, nil
		},
	}
	svc := NewBoatService(repo, nil)

	result, err := svc.GetByID(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "boat-1" {
		t.Errorf("expected boat ID %q, got %q", "boat-1", result.ID)
	}
}

func TestBoatService_GetByID_NotFound(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Boat, error) {
			return nil, domain.ErrBoatNotFound
		},
	}
	svc := NewBoatService(repo, nil)

	_, err := svc.GetByID(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("expected ErrBoatNotFound, got %v", err)
	}
}

func TestBoatService_GetByID_WrongUser(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		getByIDFn: func(_ context.Context, userID, _ string) (*domain.Boat, error) {
			if userID != "user-1" {
				return nil, domain.ErrBoatNotFound
			}
			return newTestBoat(), nil
		},
	}
	svc := NewBoatService(repo, nil)

	_, err := svc.GetByID(context.Background(), "other-user", "boat-1")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("expected ErrBoatNotFound, got %v", err)
	}
}

// --- List tests ---

func TestBoatService_List_Success(t *testing.T) {
	t.Parallel()

	boats := []domain.Boat{*newTestBoat()}
	repo := &mockBoatRepo{
		listFn: func(_ context.Context, _ string, _ string, _ int) ([]domain.Boat, string, error) {
			return boats, "next-cursor", nil
		},
	}
	svc := NewBoatService(repo, nil)

	result, cursor, err := svc.List(context.Background(), "user-1", "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 boat, got %d", len(result))
	}
	if cursor != "next-cursor" {
		t.Errorf("expected cursor %q, got %q", "next-cursor", cursor)
	}
}

func TestBoatService_List_EmptyResult(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		listFn: func(_ context.Context, _ string, _ string, _ int) ([]domain.Boat, string, error) {
			return []domain.Boat{}, "", nil
		},
	}
	svc := NewBoatService(repo, nil)

	result, cursor, err := svc.List(context.Background(), "user-1", "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 0 {
		t.Errorf("expected 0 boats, got %d", len(result))
	}
	if cursor != "" {
		t.Errorf("expected empty cursor, got %q", cursor)
	}
}

func TestBoatService_List_DefaultLimit(t *testing.T) {
	t.Parallel()

	var capturedLimit int
	repo := &mockBoatRepo{
		listFn: func(_ context.Context, _ string, _ string, limit int) ([]domain.Boat, string, error) {
			capturedLimit = limit
			return []domain.Boat{}, "", nil
		},
	}
	svc := NewBoatService(repo, nil)

	tests := []struct {
		name          string
		inputLimit    int
		expectedLimit int
	}{
		{"zero limit defaults to 20", 0, 20},
		{"negative limit defaults to 20", -5, 20},
		{"over 50 defaults to 20", 100, 20},
		{"valid limit preserved", 15, 15},
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

func TestBoatService_List_RepoError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("database timeout")
	repo := &mockBoatRepo{
		listFn: func(_ context.Context, _ string, _ string, _ int) ([]domain.Boat, string, error) {
			return nil, "", repoErr
		},
	}
	svc := NewBoatService(repo, nil)

	_, _, err := svc.List(context.Background(), "user-1", "", 10)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- Update tests ---

func TestBoatService_Update_Success(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	boat.Name = "Updated Name"
	repo := &mockBoatRepo{
		updateFn: func(_ context.Context, _ string, b *domain.Boat) (*domain.Boat, error) {
			return b, nil
		},
	}
	svc := NewBoatService(repo, nil)

	result, err := svc.Update(context.Background(), "user-1", boat)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.Name != "Updated Name" {
		t.Errorf("expected name %q, got %q", "Updated Name", result.Name)
	}
}

func TestBoatService_Update_EmptyID(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	boat.ID = ""
	repo := &mockBoatRepo{}
	svc := NewBoatService(repo, nil)

	_, err := svc.Update(context.Background(), "user-1", boat)
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

func TestBoatService_Update_NotFound(t *testing.T) {
	t.Parallel()

	boat := newTestBoat()
	repo := &mockBoatRepo{
		updateFn: func(_ context.Context, _ string, _ *domain.Boat) (*domain.Boat, error) {
			return nil, domain.ErrBoatNotFound
		},
	}
	svc := NewBoatService(repo, nil)

	_, err := svc.Update(context.Background(), "user-1", boat)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("expected ErrBoatNotFound, got %v", err)
	}
}

// --- Delete tests ---

func TestBoatService_Delete_Success(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return nil
		},
	}
	svc := NewBoatService(repo, nil)

	err := svc.Delete(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestBoatService_Delete_NotFound(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return domain.ErrBoatNotFound
		},
	}
	svc := NewBoatService(repo, nil)

	err := svc.Delete(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("expected ErrBoatNotFound, got %v", err)
	}
}

func (m *mockBoatRepo) Count(_ context.Context, _ string) (int, error) {
	return 0, nil
}

func (m *mockBoatRepo) GetByIDAccessible(_ context.Context, userID, id string) (*domain.Boat, error) {
	return &domain.Boat{ID: id, UserID: userID}, nil
}
func (m *mockBoatRepo) HasAccess(_ context.Context, _, _ string) (bool, error) {
	return true, nil
}
func (m *mockBoatRepo) ListShared(_ context.Context, _ string) ([]domain.Boat, error) {
	return nil, nil
}
func (m *mockBoatRepo) EnsureShareCode(_ context.Context, _, _, candidate string) (string, error) {
	return candidate, nil
}
func (m *mockBoatRepo) GetIDByShareCode(_ context.Context, _ string) (string, string, error) {
	return "", "", domain.ErrBoatNotFound
}
func (m *mockBoatRepo) AddMember(_ context.Context, _, _, _ string) error { return nil }
func (m *mockBoatRepo) ListMembers(_ context.Context, _ string) ([]domain.BoatMember, error) {
	return nil, nil
}
func (m *mockBoatRepo) RemoveMember(_ context.Context, _, _, _ string) error { return nil }
func (m *mockBoatRepo) Leave(_ context.Context, _, _ string) error           { return nil }

func (m *mockBoatRepo) GetPermissions(ctx context.Context, userID, boatID string) (domain.BoatPermissions, bool, error) {
	if m.getPermissionsFn != nil {
		return m.getPermissionsFn(ctx, userID, boatID)
	}
	return domain.OwnerPermissions(), true, nil
}
func (m *mockBoatRepo) SetPermissions(_ context.Context, _, _, _ string, _ domain.BoatPermissions) error {
	return nil
}
