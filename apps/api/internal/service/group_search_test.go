package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// stubBlockRepo reports a fixed block list; only ListBlockedIDs is exercised by
// discovery.
type stubBlockRepo struct {
	blocked []string
	err     error
}

func (r *stubBlockRepo) Block(_ context.Context, _, _ string) error   { return nil }
func (r *stubBlockRepo) Unblock(_ context.Context, _, _ string) error { return nil }
func (r *stubBlockRepo) ListBlockedIDs(_ context.Context, _ string) ([]string, error) {
	return r.blocked, r.err
}

func publicGroup(id, name, ownerID string) domain.Group {
	return domain.Group{
		ID:                 id,
		OwnerID:            ownerID,
		Name:               name,
		Visibility:         domain.GroupVisibilityPublic,
		MyMembershipStatus: "none",
		CreatedAt:          time.Now(),
		UpdatedAt:          time.Now(),
	}
}

func TestGroupService_SearchPublic_TrimsAndClamps(t *testing.T) {
	t.Parallel()

	var (
		gotQuery  string
		gotLimit  int
		gotCursor string
	)
	groupRepo := &mockGroupRepo{
		searchPublicFn: func(_ context.Context, _, query, cursor string, limit int) ([]domain.Group, string, error) {
			gotQuery, gotCursor, gotLimit = query, cursor, limit
			return []domain.Group{publicGroup("group-1", "Club Nautico", "owner-1")}, "next", nil
		},
	}
	svc := NewGroupService(groupRepo, nil, nil, nil, nil, nil)

	groups, next, err := svc.SearchPublic(context.Background(), "user-1", "  Club  ", "opaque-cursor", 500)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if gotQuery != "Club" {
		t.Errorf("query = %q, want trimmed Club", gotQuery)
	}
	if gotLimit != 50 {
		t.Errorf("limit = %d, want 50 (clamped)", gotLimit)
	}
	if gotCursor != "opaque-cursor" {
		t.Errorf("cursor = %q, want it passed through untouched", gotCursor)
	}
	if len(groups) != 1 {
		t.Errorf("groups = %d, want 1", len(groups))
	}
	if next != "next" {
		t.Errorf("next cursor = %q, want next", next)
	}
}

func TestGroupService_SearchPublic_TooShort(t *testing.T) {
	t.Parallel()

	groupRepo := &mockGroupRepo{
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			t.Helper()
			t.Fatal("repo must not be queried for a query below the minimum length")
			return nil, "", nil
		},
	}
	svc := NewGroupService(groupRepo, nil, nil, nil, nil, nil)

	cases := map[string]string{
		"single_char":     "a",
		"blank":           "   ",
		"empty":           "",
		"padded_one_char": "  a  ",
	}

	for name, query := range cases {
		query := query
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			_, _, err := svc.SearchPublic(context.Background(), "user-1", query, "", 20)
			if !errors.Is(err, domain.ErrValidation) {
				t.Errorf("err = %v, want ErrValidation", err)
			}
			var ve *domain.ValidationError
			if errors.As(err, &ve) && ve.Field != "q" {
				t.Errorf("field = %q, want q", ve.Field)
			}
		})
	}
}

func TestGroupService_SearchPublic_TwoCharsAccepted(t *testing.T) {
	t.Parallel()

	called := false
	groupRepo := &mockGroupRepo{
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			called = true
			return nil, "", nil
		},
	}
	svc := NewGroupService(groupRepo, nil, nil, nil, nil, nil)

	if _, _, err := svc.SearchPublic(context.Background(), "user-1", "cn", "", 20); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !called {
		t.Error("repo not queried: the minimum length is 2, not 3")
	}
}

func TestGroupService_SearchPublic_HidesBlockedOwners(t *testing.T) {
	t.Parallel()

	groupRepo := &mockGroupRepo{
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			return []domain.Group{
				publicGroup("group-1", "Club Nautico", "owner-1"),
				publicGroup("group-2", "Club Nautico Sur", "blocked-owner"),
			}, "", nil
		},
	}
	blocks := &stubBlockRepo{blocked: []string{"blocked-owner"}}
	svc := NewGroupService(groupRepo, nil, nil, blocks, nil, nil)

	groups, _, err := svc.SearchPublic(context.Background(), "user-1", "Club", "", 20)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(groups) != 1 {
		t.Fatalf("groups = %d, want 1 (the blocked owner's group filtered out)", len(groups))
	}
	if groups[0].ID != "group-1" {
		t.Errorf("group = %q, want group-1", groups[0].ID)
	}
}

func TestGroupService_SearchPublic_BlockLookupFailureStillSearches(t *testing.T) {
	t.Parallel()

	groupRepo := &mockGroupRepo{
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			return []domain.Group{publicGroup("group-1", "Club Nautico", "owner-1")}, "", nil
		},
	}
	blocks := &stubBlockRepo{err: errors.New("block query failed")}
	svc := NewGroupService(groupRepo, nil, nil, blocks, nil, nil)

	// Same trade-off as ListPublic: search keeps working unfiltered rather than
	// failing the whole Discover tab.
	groups, _, err := svc.SearchPublic(context.Background(), "user-1", "Club", "", 20)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(groups) != 1 {
		t.Errorf("groups = %d, want 1", len(groups))
	}
}

func TestGroupService_SearchPublic_RepoError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("database timeout")
	groupRepo := &mockGroupRepo{
		searchPublicFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Group, string, error) {
			return nil, "", repoErr
		},
	}
	svc := NewGroupService(groupRepo, nil, nil, nil, nil, nil)

	if _, _, err := svc.SearchPublic(context.Background(), "user-1", "Club", "", 20); !errors.Is(err, repoErr) {
		t.Errorf("err = %v, want the underlying repo error", err)
	}
}
