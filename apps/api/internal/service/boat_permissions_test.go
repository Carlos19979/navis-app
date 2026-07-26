package service

import (
	"context"
	"errors"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// viewerPerms is a partially-granted member permission set: enough to read
// documents, not enough to record a trip.
func viewerPerms() domain.BoatPermissions {
	return domain.BoatPermissions{CanViewDocuments: true}
}

// --- EffectivePermissions ---

func TestBoatService_EffectivePermissions_Owner(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		getPermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, bool, error) {
			return domain.OwnerPermissions(), true, nil
		},
	}
	svc := NewBoatService(repo, nil, nil)

	perms, err := svc.EffectivePermissions(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if perms != domain.OwnerPermissions() {
		t.Errorf("perms = %+v, want every permission granted", perms)
	}
}

func TestBoatService_EffectivePermissions_MemberFlags(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		getPermissionsFn: func(_ context.Context, userID, boatID string) (domain.BoatPermissions, bool, error) {
			if userID != "member-1" || boatID != "boat-1" {
				t.Errorf("lookup = %q/%q, want member-1/boat-1", userID, boatID)
			}
			return viewerPerms(), true, nil
		},
	}
	svc := NewBoatService(repo, nil, nil)

	perms, err := svc.EffectivePermissions(context.Background(), "member-1", "boat-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !perms.CanViewDocuments {
		t.Error("CanViewDocuments = false, want the granted flag")
	}
	// The point of the endpoint: the client must learn this is denied *before*
	// the user records a trip, not from a 403 on save.
	if perms.CanRecordTrips {
		t.Error("CanRecordTrips = true, want the denied flag")
	}
}

func TestBoatService_EffectivePermissions_NoAccessIsNotFound(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		getPermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, bool, error) {
			return domain.BoatPermissions{}, false, nil
		},
	}
	svc := NewBoatService(repo, nil, nil)

	// A stranger must not be able to tell an existing boat id from a made-up
	// one, so "no access" is reported as not found, never as an empty set.
	_, err := svc.EffectivePermissions(context.Background(), "stranger", "boat-1")
	if !errors.Is(err, domain.ErrBoatNotFound) {
		t.Errorf("err = %v, want ErrBoatNotFound", err)
	}
}

func TestBoatService_EffectivePermissions_RepoError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("connection refused")
	repo := &mockBoatRepo{
		getPermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, bool, error) {
			return domain.BoatPermissions{}, false, repoErr
		},
	}
	svc := NewBoatService(repo, nil, nil)

	// A failed lookup must not be flattened into ErrBoatNotFound (or into an
	// empty permission set): the client would silently disable everything.
	_, err := svc.EffectivePermissions(context.Background(), "user-1", "boat-1")
	if !errors.Is(err, repoErr) {
		t.Errorf("err = %v, want the underlying repo error", err)
	}
	if errors.Is(err, domain.ErrBoatNotFound) {
		t.Error("a repo failure must not be reported as not found")
	}
}

// --- ListShared ---

func TestBoatService_ListShared_AttachesPermissions(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		listSharedFn: func(_ context.Context, _ string) ([]domain.Boat, error) {
			return []domain.Boat{
				{ID: "boat-1", UserID: "owner-1"},
				{ID: "boat-2", UserID: "owner-2"},
			}, nil
		},
		getPermissionsFn: func(_ context.Context, _, boatID string) (domain.BoatPermissions, bool, error) {
			if boatID == "boat-1" {
				return domain.BoatPermissions{CanRecordTrips: true}, true, nil
			}
			return viewerPerms(), true, nil
		},
	}
	svc := NewBoatService(repo, nil, nil)

	shared, err := svc.ListShared(context.Background(), "member-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(shared) != 2 {
		t.Fatalf("shared = %d boats, want 2", len(shared))
	}
	if shared[0].Boat.ID != "boat-1" || !shared[0].Permissions.CanRecordTrips {
		t.Errorf("boat-1 = %+v, want its own CanRecordTrips grant", shared[0])
	}
	if shared[1].Boat.ID != "boat-2" || shared[1].Permissions.CanRecordTrips {
		t.Errorf("boat-2 = %+v, want per-boat permissions, not boat-1's", shared[1])
	}
}

func TestBoatService_ListShared_PermissionLookupError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("permission query failed")
	repo := &mockBoatRepo{
		listSharedFn: func(_ context.Context, _ string) ([]domain.Boat, error) {
			return []domain.Boat{{ID: "boat-1", UserID: "owner-1"}}, nil
		},
		getPermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, bool, error) {
			return domain.BoatPermissions{}, false, repoErr
		},
	}
	svc := NewBoatService(repo, nil, nil)

	if _, err := svc.ListShared(context.Background(), "member-1"); !errors.Is(err, repoErr) {
		t.Errorf("err = %v, want the underlying repo error", err)
	}
}

func TestBoatService_ListShared_Empty(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		listSharedFn: func(_ context.Context, _ string) ([]domain.Boat, error) {
			return nil, nil
		},
	}
	svc := NewBoatService(repo, nil, nil)

	shared, err := svc.ListShared(context.Background(), "member-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if shared == nil {
		t.Error("shared = nil, want an empty slice (serializes as [])")
	}
	if len(shared) != 0 {
		t.Errorf("shared = %d boats, want 0", len(shared))
	}
}

// --- JoinByCode ---

func TestBoatService_JoinByCode_ReturnsMemberPermissions(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		shareCodeFn: func(_ context.Context, _ string) (string, string, error) {
			return "boat-1", "owner-1", nil
		},
		getAccessibleFn: func(_ context.Context, _, _ string) (*domain.Boat, error) {
			return &domain.Boat{ID: "boat-1", UserID: "owner-1"}, nil
		},
		getPermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, bool, error) {
			return viewerPerms(), true, nil
		},
	}
	svc := NewBoatService(repo, nil, nil)

	joined, err := svc.JoinByCode(context.Background(), "member-1", "SHARE123")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if joined.Boat.ID != "boat-1" {
		t.Errorf("boat = %q, want boat-1", joined.Boat.ID)
	}
	// Joining grants the viewer role, so the app can say up front that
	// recording trips needs the owner to grant it.
	if joined.Permissions.CanRecordTrips {
		t.Error("CanRecordTrips = true, want false for a fresh viewer membership")
	}
	if !joined.Permissions.CanViewDocuments {
		t.Error("CanViewDocuments = false, want the granted flag")
	}
}

func TestBoatService_JoinByCode_OwnerGetsOwnerPermissions(t *testing.T) {
	t.Parallel()

	repo := &mockBoatRepo{
		shareCodeFn: func(_ context.Context, _ string) (string, string, error) {
			return "boat-1", "owner-1", nil
		},
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Boat, error) {
			return &domain.Boat{ID: "boat-1", UserID: "owner-1"}, nil
		},
		getPermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, bool, error) {
			t.Helper()
			t.Error("the owner path must not need a permission lookup")
			return domain.BoatPermissions{}, false, nil
		},
	}
	svc := NewBoatService(repo, nil, nil)

	joined, err := svc.JoinByCode(context.Background(), "owner-1", "SHARE123")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if joined.Permissions != domain.OwnerPermissions() {
		t.Errorf("perms = %+v, want every permission granted", joined.Permissions)
	}
}
