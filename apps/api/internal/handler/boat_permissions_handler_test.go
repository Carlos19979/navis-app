package handler_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/handler"
)

// mockBoatService satisfies the (unexported) service surface BoatHandler
// consumes. Only the methods a test wires are called; the rest fail loudly.
type mockBoatService struct {
	effectivePermissionsFn func(ctx context.Context, userID, boatID string) (domain.BoatPermissions, error)
	getAccessibleFn        func(ctx context.Context, userID, id string) (*domain.Boat, error)
	joinByCodeFn           func(ctx context.Context, userID, code string) (*domain.SharedBoat, error)
	listSharedFn           func(ctx context.Context, userID string) ([]domain.SharedBoat, error)
}

func (m *mockBoatService) Create(_ context.Context, _ *domain.Boat) (*domain.Boat, error) {
	return nil, errors.New("not wired")
}

func (m *mockBoatService) GetByID(_ context.Context, _, _ string) (*domain.Boat, error) {
	return nil, errors.New("not wired")
}

func (m *mockBoatService) GetAccessible(ctx context.Context, userID, id string) (*domain.Boat, error) {
	if m.getAccessibleFn != nil {
		return m.getAccessibleFn(ctx, userID, id)
	}
	return nil, errors.New("not wired")
}

func (m *mockBoatService) List(_ context.Context, _, _ string, _ int) ([]domain.Boat, string, error) {
	return nil, "", errors.New("not wired")
}

func (m *mockBoatService) Update(_ context.Context, _ string, _ *domain.Boat) (*domain.Boat, error) {
	return nil, errors.New("not wired")
}

func (m *mockBoatService) Delete(_ context.Context, _, _ string) error {
	return errors.New("not wired")
}

func (m *mockBoatService) EffectivePermissions(ctx context.Context, userID, boatID string) (domain.BoatPermissions, error) {
	if m.effectivePermissionsFn != nil {
		return m.effectivePermissionsFn(ctx, userID, boatID)
	}
	return domain.BoatPermissions{}, errors.New("not wired")
}

func (m *mockBoatService) ShareCode(_ context.Context, _, _ string) (string, error) {
	return "", errors.New("not wired")
}

func (m *mockBoatService) JoinByCode(ctx context.Context, userID, code string) (*domain.SharedBoat, error) {
	if m.joinByCodeFn != nil {
		return m.joinByCodeFn(ctx, userID, code)
	}
	return nil, errors.New("not wired")
}

func (m *mockBoatService) ListShared(ctx context.Context, userID string) ([]domain.SharedBoat, error) {
	if m.listSharedFn != nil {
		return m.listSharedFn(ctx, userID)
	}
	return nil, errors.New("not wired")
}

func (m *mockBoatService) ListMembers(_ context.Context, _, _ string) ([]domain.BoatMember, error) {
	return nil, errors.New("not wired")
}

func (m *mockBoatService) RemoveMember(_ context.Context, _, _, _ string) error {
	return errors.New("not wired")
}

func (m *mockBoatService) SetMemberPermissions(_ context.Context, _, _, _ string, _ domain.BoatPermissions) error {
	return errors.New("not wired")
}

func (m *mockBoatService) Leave(_ context.Context, _, _ string) error {
	return errors.New("not wired")
}

// decodeData unwraps the {"data": ...} envelope into T.
func decodeData[T any](t *testing.T, body []byte) T {
	t.Helper()
	var env struct {
		Data T `json:"data"`
	}
	if err := json.Unmarshal(body, &env); err != nil {
		t.Fatalf("invalid JSON response: %v (%s)", err, body)
	}
	return env.Data
}

// --- GET /boats/{id}/permissions ---

func TestBoatHandler_Permissions_Success(t *testing.T) {
	t.Parallel()

	var gotUserID, gotBoatID string
	h := handler.NewBoatHandler(&mockBoatService{
		effectivePermissionsFn: func(_ context.Context, userID, boatID string) (domain.BoatPermissions, error) {
			gotUserID, gotBoatID = userID, boatID
			return domain.BoatPermissions{CanViewDocuments: true, CanManageExpenses: true}, nil
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/boats/boat-1/permissions", "", "member-1")
	r = withChiParam(r, "id", "boat-1")
	h.Permissions(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if gotUserID != "member-1" || gotBoatID != "boat-1" {
		t.Errorf("lookup = %q/%q, want member-1/boat-1", gotUserID, gotBoatID)
	}

	got := decodeData[dto.BoatEffectivePermissionsResponse](t, w.Body.Bytes())
	if got.BoatID != "boat-1" {
		t.Errorf("boat_id = %q, want boat-1", got.BoatID)
	}
	if !got.Permissions.CanViewDocuments || !got.Permissions.CanManageExpenses {
		t.Errorf("granted flags missing: %+v", got.Permissions)
	}
	if got.Permissions.CanRecordTrips || got.Permissions.CanManageDocuments || got.Permissions.CanManageMaintenance {
		t.Errorf("denied flags reported as granted: %+v", got.Permissions)
	}
}

func TestBoatHandler_Permissions_NoAccessIs404(t *testing.T) {
	t.Parallel()

	h := handler.NewBoatHandler(&mockBoatService{
		effectivePermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, error) {
			return domain.BoatPermissions{}, domain.ErrBoatNotFound
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/boats/boat-1/permissions", "", "stranger")
	r = withChiParam(r, "id", "boat-1")
	h.Permissions(w, r)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d: %s", w.Code, w.Body.String())
	}
}

func TestBoatHandler_Permissions_Unauthenticated(t *testing.T) {
	t.Parallel()

	h := handler.NewBoatHandler(&mockBoatService{
		effectivePermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, error) {
			t.Helper()
			t.Error("service must not be called without an authenticated user")
			return domain.BoatPermissions{}, nil
		},
	})

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/api/v1/boats/boat-1/permissions", nil)
	r = withChiParam(r, "id", "boat-1")
	h.Permissions(w, r)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

// --- GET /boats/{id} ---

func TestBoatHandler_GetByID_CarriesPermissions(t *testing.T) {
	t.Parallel()

	h := handler.NewBoatHandler(&mockBoatService{
		getAccessibleFn: func(_ context.Context, _, id string) (*domain.Boat, error) {
			return &domain.Boat{ID: id, UserID: "owner-1", Name: "Sea Breeze"}, nil
		},
		effectivePermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, error) {
			return domain.BoatPermissions{CanViewDocuments: true}, nil
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/boats/boat-1", "", "member-1")
	r = withChiParam(r, "id", "boat-1")
	h.GetByID(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	got := decodeData[dto.BoatResponse](t, w.Body.Bytes())
	if got.IsOwner {
		t.Error("is_owner = true, want false for a member")
	}
	if !got.Permissions.CanViewDocuments || got.Permissions.CanRecordTrips {
		t.Errorf("permissions = %+v, want only can_view_documents", got.Permissions)
	}
}

func TestBoatHandler_GetByID_PermissionLookupFailureIsAnError(t *testing.T) {
	t.Parallel()

	h := handler.NewBoatHandler(&mockBoatService{
		getAccessibleFn: func(_ context.Context, _, id string) (*domain.Boat, error) {
			return &domain.Boat{ID: id, UserID: "owner-1"}, nil
		},
		effectivePermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, error) {
			return domain.BoatPermissions{}, errors.New("connection refused")
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/boats/boat-1", "", "member-1")
	r = withChiParam(r, "id", "boat-1")
	h.GetByID(w, r)

	// Serving the boat with an all-false permission block would tell the client
	// the user may do nothing — worse than an honest failure.
	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d: %s", w.Code, w.Body.String())
	}
}

// --- GET /boats/shared and POST /boats/join ---

func TestBoatHandler_ListShared_CarriesPerBoatPermissions(t *testing.T) {
	t.Parallel()

	h := handler.NewBoatHandler(&mockBoatService{
		listSharedFn: func(_ context.Context, _ string) ([]domain.SharedBoat, error) {
			return []domain.SharedBoat{
				{
					Boat:        domain.Boat{ID: "boat-1", UserID: "owner-1"},
					Permissions: domain.BoatPermissions{CanRecordTrips: true},
				},
				{
					Boat:        domain.Boat{ID: "boat-2", UserID: "owner-2"},
					Permissions: domain.BoatPermissions{CanViewDocuments: true},
				},
			}, nil
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/boats/shared", "", "member-1")
	h.ListShared(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	got := decodeData[[]dto.BoatResponse](t, w.Body.Bytes())
	if len(got) != 2 {
		t.Fatalf("boats = %d, want 2", len(got))
	}
	if !got[0].Permissions.CanRecordTrips || got[0].Permissions.CanViewDocuments {
		t.Errorf("boat-1 permissions = %+v, want only can_record_trips", got[0].Permissions)
	}
	if !got[1].Permissions.CanViewDocuments || got[1].Permissions.CanRecordTrips {
		t.Errorf("boat-2 permissions = %+v, want only can_view_documents", got[1].Permissions)
	}
	for i := range got {
		if got[i].IsOwner {
			t.Errorf("boat %q: is_owner = true, want false on the shared list", got[i].ID)
		}
	}
}

func TestBoatHandler_Join_ReportsWhatTheMemberMayDo(t *testing.T) {
	t.Parallel()

	h := handler.NewBoatHandler(&mockBoatService{
		joinByCodeFn: func(_ context.Context, _, code string) (*domain.SharedBoat, error) {
			if code != "SHARE123" {
				t.Errorf("code = %q, want SHARE123", code)
			}
			return &domain.SharedBoat{
				Boat:        domain.Boat{ID: "boat-1", UserID: "owner-1"},
				Permissions: domain.BoatPermissions{CanViewDocuments: true},
			}, nil
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodPost, "/api/v1/boats/join", `{"code":"SHARE123"}`, "member-1")
	h.Join(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	got := decodeData[dto.BoatResponse](t, w.Body.Bytes())
	// Joining grants the viewer role: the app must be able to say so before the
	// user records a trip it cannot save.
	if got.Permissions.CanRecordTrips {
		t.Error("can_record_trips = true, want false for a fresh viewer membership")
	}
	if !got.Permissions.CanViewDocuments {
		t.Error("can_view_documents = false, want the granted flag")
	}
}
