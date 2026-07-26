package handler_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/handler"
)

// mockGroupService satisfies the (unexported) service surface GroupHandler
// consumes. Only the list/search methods are wired: the rest fail loudly so a
// misrouted call cannot pass silently.
type mockGroupService struct {
	listFn         func(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error)
	listPublicFn   func(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error)
	searchPublicFn func(ctx context.Context, userID, query, cursor string, limit int) ([]domain.Group, string, error)
}

func (m *mockGroupService) Create(_ context.Context, _ *domain.Group) (*domain.Group, error) {
	return nil, errors.New("not wired")
}

func (m *mockGroupService) GetByID(_ context.Context, _, _ string) (*domain.Group, error) {
	return nil, errors.New("not wired")
}

func (m *mockGroupService) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	if m.listFn != nil {
		return m.listFn(ctx, userID, cursor, limit)
	}
	return nil, "", errors.New("not wired")
}

func (m *mockGroupService) ListPublic(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	if m.listPublicFn != nil {
		return m.listPublicFn(ctx, userID, cursor, limit)
	}
	return nil, "", errors.New("not wired")
}

func (m *mockGroupService) SearchPublic(ctx context.Context, userID, query, cursor string, limit int) ([]domain.Group, string, error) {
	if m.searchPublicFn != nil {
		return m.searchPublicFn(ctx, userID, query, cursor, limit)
	}
	return nil, "", errors.New("not wired")
}

func (m *mockGroupService) Update(_ context.Context, _ string, _ *domain.Group) (*domain.Group, error) {
	return nil, errors.New("not wired")
}

func (m *mockGroupService) Delete(_ context.Context, _, _ string) error {
	return errors.New("not wired")
}

func (m *mockGroupService) RequestJoin(_ context.Context, _, _ string) (*domain.Group, error) {
	return nil, errors.New("not wired")
}

func (m *mockGroupService) JoinByCode(_ context.Context, _, _ string) (*domain.Group, error) {
	return nil, errors.New("not wired")
}

func (m *mockGroupService) ListMembers(_ context.Context, _, _ string) ([]domain.GroupMember, error) {
	return nil, errors.New("not wired")
}

func (m *mockGroupService) Leave(_ context.Context, _, _ string) error {
	return errors.New("not wired")
}

func (m *mockGroupService) ListPendingRequests(_ context.Context, _, _ string) ([]domain.GroupMember, error) {
	return nil, errors.New("not wired")
}

func (m *mockGroupService) ApproveRequest(_ context.Context, _, _, _ string) error {
	return errors.New("not wired")
}

func (m *mockGroupService) RejectRequest(_ context.Context, _, _, _ string) error {
	return errors.New("not wired")
}

func (m *mockGroupService) RemoveMember(_ context.Context, _, _, _ string) error {
	return errors.New("not wired")
}

func discoverableGroup(id, name string) domain.Group {
	return domain.Group{
		ID:                 id,
		OwnerID:            "owner-1",
		Name:               name,
		Visibility:         domain.GroupVisibilityPublic,
		MyMembershipStatus: "none",
	}
}

func TestGroupHandler_List_DiscoverWithQuerySearches(t *testing.T) {
	t.Parallel()

	var gotQuery, gotCursor string
	var gotLimit int
	h := handler.NewGroupHandler(&mockGroupService{
		listPublicFn: func(_ context.Context, _, _ string, _ int) ([]domain.Group, string, error) {
			t.Helper()
			t.Error("with ?q= present the handler must search, not list everything")
			return nil, "", nil
		},
		searchPublicFn: func(_ context.Context, _, query, cursor string, limit int) ([]domain.Group, string, error) {
			gotQuery, gotCursor, gotLimit = query, cursor, limit
			return []domain.Group{discoverableGroup("group-1", "Club Nautico")}, "next-cursor", nil
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet,
		"/api/v1/groups?discover=true&q=Club&cursor=opaque&limit=5", "", "user-1")
	h.List(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if gotQuery != "Club" {
		t.Errorf("query = %q, want Club", gotQuery)
	}
	if gotCursor != "opaque" {
		t.Errorf("cursor = %q, want opaque", gotCursor)
	}
	if gotLimit != 5 {
		t.Errorf("limit = %d, want 5", gotLimit)
	}

	groups := decodeData[[]dto.GroupResponse](t, w.Body.Bytes())
	if len(groups) != 1 || groups[0].Name != "Club Nautico" {
		t.Errorf("groups = %+v, want the single match", groups)
	}
}

func TestGroupHandler_List_DiscoverWithoutQueryLists(t *testing.T) {
	t.Parallel()

	called := false
	h := handler.NewGroupHandler(&mockGroupService{
		listPublicFn: func(_ context.Context, _, _ string, _ int) ([]domain.Group, string, error) {
			called = true
			return []domain.Group{discoverableGroup("group-1", "Club Nautico")}, "", nil
		},
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			t.Helper()
			t.Error("without ?q= the handler must list, not search")
			return nil, "", nil
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/groups?discover=true", "", "user-1")
	h.List(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if !called {
		t.Error("ListPublic not called")
	}
}

func TestGroupHandler_List_QueryWithoutDiscoverListsMyGroups(t *testing.T) {
	t.Parallel()

	called := false
	h := handler.NewGroupHandler(&mockGroupService{
		listFn: func(_ context.Context, _, _ string, _ int) ([]domain.Group, string, error) {
			called = true
			return nil, "", nil
		},
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			t.Helper()
			t.Error("q alone must not turn the membership list into public discovery")
			return nil, "", nil
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/groups?q=Club", "", "user-1")
	h.List(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if !called {
		t.Error("List not called")
	}
}

func TestGroupHandler_List_ShortQueryIs422(t *testing.T) {
	t.Parallel()

	h := handler.NewGroupHandler(&mockGroupService{
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			return nil, "", &domain.ValidationError{Field: "q", Message: "search query must be at least 2 characters"}
		},
	})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodGet, "/api/v1/groups?discover=true&q=a", "", "user-1")
	h.List(w, r)

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestGroupHandler_List_Unauthenticated(t *testing.T) {
	t.Parallel()

	h := handler.NewGroupHandler(&mockGroupService{})

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "/api/v1/groups?discover=true&q=Club", nil)
	h.List(w, r)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}
