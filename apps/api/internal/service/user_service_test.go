package service

import (
	"context"
	"errors"
	"log/slog"
	"testing"
)

// mockSupabaseAdmin records calls and can fail per bucket.
type mockSupabaseAdmin struct {
	filesDeleted    []string // "<bucket>/<userID>" in call order
	authDeleted     []string
	failFilesBucket string
	failAuthDelete  bool
}

func (m *mockSupabaseAdmin) DeleteUserFiles(_ context.Context, bucket, userID string) error {
	if bucket == m.failFilesBucket {
		return errors.New("storage unavailable")
	}
	m.filesDeleted = append(m.filesDeleted, bucket+"/"+userID)
	return nil
}

func (m *mockSupabaseAdmin) DeleteAuthUser(_ context.Context, userID string) error {
	if m.failAuthDelete {
		return errors.New("gotrue unavailable")
	}
	m.authDeleted = append(m.authDeleted, userID)
	return nil
}

func newUserServiceWithAdmin(admin *mockSupabaseAdmin) *UserService {
	return &UserService{admin: admin, logger: slog.New(slog.DiscardHandler)}
}

func TestUserService_DeleteAccount_PurgesFilesThenAuthUser(t *testing.T) {
	t.Parallel()
	admin := &mockSupabaseAdmin{}
	svc := newUserServiceWithAdmin(admin)

	if err := svc.DeleteAccount(context.Background(), "user-1"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	wantFiles := []string{"boats/user-1", "documents/user-1"}
	if len(admin.filesDeleted) != len(wantFiles) {
		t.Fatalf("files deleted = %v, want %v", admin.filesDeleted, wantFiles)
	}
	for i, want := range wantFiles {
		if admin.filesDeleted[i] != want {
			t.Errorf("filesDeleted[%d] = %q, want %q", i, admin.filesDeleted[i], want)
		}
	}
	if len(admin.authDeleted) != 1 || admin.authDeleted[0] != "user-1" {
		t.Fatalf("authDeleted = %v, want [user-1]", admin.authDeleted)
	}
}

func TestUserService_DeleteAccount_StorageFailureAbortsBeforeAuthDeletion(t *testing.T) {
	t.Parallel()
	admin := &mockSupabaseAdmin{failFilesBucket: "documents"}
	svc := newUserServiceWithAdmin(admin)

	err := svc.DeleteAccount(context.Background(), "user-1")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if len(admin.authDeleted) != 0 {
		t.Fatalf("auth user must not be deleted when storage purge fails, got %v", admin.authDeleted)
	}
}

func TestUserService_DeleteAccount_AuthFailurePropagates(t *testing.T) {
	t.Parallel()
	admin := &mockSupabaseAdmin{failAuthDelete: true}
	svc := newUserServiceWithAdmin(admin)

	if err := svc.DeleteAccount(context.Background(), "user-1"); err == nil {
		t.Fatal("expected error, got nil")
	}
}
