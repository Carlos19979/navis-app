package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// --- mock GroupRepository ---

type mockGroupRepo struct {
	createFn          func(ctx context.Context, g *domain.Group) (*domain.Group, error)
	getByIDFn         func(ctx context.Context, userID, id string) (*domain.Group, error)
	getByInviteCodeFn func(ctx context.Context, userID, code string) (*domain.Group, error)
	listFn            func(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error)
	listPublicFn      func(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error)
	updateFn          func(ctx context.Context, userID string, g *domain.Group) (*domain.Group, error)
	deleteFn          func(ctx context.Context, userID, id string) error
}

func (m *mockGroupRepo) Create(ctx context.Context, g *domain.Group) (*domain.Group, error) {
	return m.createFn(ctx, g)
}

func (m *mockGroupRepo) GetByID(ctx context.Context, userID, id string) (*domain.Group, error) {
	return m.getByIDFn(ctx, userID, id)
}

func (m *mockGroupRepo) GetByInviteCode(ctx context.Context, userID, code string) (*domain.Group, error) {
	return m.getByInviteCodeFn(ctx, userID, code)
}

func (m *mockGroupRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	return m.listFn(ctx, userID, cursor, limit)
}

func (m *mockGroupRepo) ListPublic(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	return m.listPublicFn(ctx, userID, cursor, limit)
}

func (m *mockGroupRepo) Update(ctx context.Context, userID string, g *domain.Group) (*domain.Group, error) {
	return m.updateFn(ctx, userID, g)
}

func (m *mockGroupRepo) Delete(ctx context.Context, userID, id string) error {
	return m.deleteFn(ctx, userID, id)
}

// --- mock GroupMemberRepository ---

type mockGroupMemberRepo struct {
	addFn         func(ctx context.Context, groupID, userID string, role domain.GroupMemberRole, status domain.GroupMemberStatus) error
	getFn         func(ctx context.Context, groupID, userID string) (*domain.GroupMember, error)
	setStatusFn   func(ctx context.Context, groupID, userID string, status domain.GroupMemberStatus) error
	removeFn      func(ctx context.Context, groupID, userID string) error
	listMembersFn func(ctx context.Context, groupID string) ([]domain.GroupMember, error)
	listPendingFn func(ctx context.Context, groupID string) ([]domain.GroupMember, error)
}

func (m *mockGroupMemberRepo) Add(ctx context.Context, groupID, userID string, role domain.GroupMemberRole, status domain.GroupMemberStatus) error {
	return m.addFn(ctx, groupID, userID, role, status)
}

func (m *mockGroupMemberRepo) Get(ctx context.Context, groupID, userID string) (*domain.GroupMember, error) {
	return m.getFn(ctx, groupID, userID)
}

func (m *mockGroupMemberRepo) SetStatus(ctx context.Context, groupID, userID string, status domain.GroupMemberStatus) error {
	return m.setStatusFn(ctx, groupID, userID, status)
}

func (m *mockGroupMemberRepo) Remove(ctx context.Context, groupID, userID string) error {
	return m.removeFn(ctx, groupID, userID)
}

func (m *mockGroupMemberRepo) ListMembers(ctx context.Context, groupID string) ([]domain.GroupMember, error) {
	return m.listMembersFn(ctx, groupID)
}

func (m *mockGroupMemberRepo) ListPending(ctx context.Context, groupID string) ([]domain.GroupMember, error) {
	return m.listPendingFn(ctx, groupID)
}

// --- helpers ---

func newTestGroup(visibility domain.GroupVisibility) *domain.Group {
	return &domain.Group{
		ID:         "group-1",
		OwnerID:    "user-1",
		Name:       "Club Test",
		Visibility: visibility,
		MyRole:     string(domain.GroupRoleOwner),
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}
}

// --- Create tests ---

func TestGroupService_Create_PrivateGeneratesInviteCode(t *testing.T) {
	t.Parallel()

	var addedRole domain.GroupMemberRole
	var addedStatus domain.GroupMemberStatus
	var createdCode *string

	groupRepo := &mockGroupRepo{
		createFn: func(_ context.Context, g *domain.Group) (*domain.Group, error) {
			g.ID = "group-1"
			createdCode = g.InviteCode
			return g, nil
		},
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) {
			return newTestGroup(domain.GroupVisibilityPrivate), nil
		},
	}
	memberRepo := &mockGroupMemberRepo{
		addFn: func(_ context.Context, _, _ string, role domain.GroupMemberRole, status domain.GroupMemberStatus) error {
			addedRole, addedStatus = role, status
			return nil
		},
	}
	svc := NewGroupService(groupRepo, memberRepo)

	g := &domain.Group{OwnerID: "user-1", Name: "Club Test", Visibility: domain.GroupVisibilityPrivate}
	_, err := svc.Create(context.Background(), g)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if createdCode == nil || len(*createdCode) != 8 {
		t.Errorf("expected an 8-char invite code for a private group, got %v", createdCode)
	}
	if addedRole != domain.GroupRoleOwner || addedStatus != domain.GroupMemberStatusActive {
		t.Errorf("expected owner added as active, got role=%q status=%q", addedRole, addedStatus)
	}
}

func TestGroupService_Create_PublicHasNoInviteCode(t *testing.T) {
	t.Parallel()

	var createdCode *string
	groupRepo := &mockGroupRepo{
		createFn: func(_ context.Context, g *domain.Group) (*domain.Group, error) {
			g.ID = "group-1"
			createdCode = g.InviteCode
			return g, nil
		},
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) {
			return newTestGroup(domain.GroupVisibilityPublic), nil
		},
	}
	memberRepo := &mockGroupMemberRepo{
		addFn: func(_ context.Context, _, _ string, _ domain.GroupMemberRole, _ domain.GroupMemberStatus) error {
			return nil
		},
	}
	svc := NewGroupService(groupRepo, memberRepo)

	g := &domain.Group{OwnerID: "user-1", Name: "Club Test", Visibility: domain.GroupVisibilityPublic}
	if _, err := svc.Create(context.Background(), g); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if createdCode != nil {
		t.Errorf("expected no invite code for a public group, got %q", *createdCode)
	}
}

func TestGroupService_Create_EmptyName(t *testing.T) {
	t.Parallel()

	svc := NewGroupService(&mockGroupRepo{}, &mockGroupMemberRepo{})
	_, err := svc.Create(context.Background(), &domain.Group{OwnerID: "user-1", Visibility: domain.GroupVisibilityPublic})

	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
	if ve.Field != "name" {
		t.Errorf("expected field %q, got %q", "name", ve.Field)
	}
}

// --- RequestJoin tests ---

func TestGroupService_RequestJoin_Public(t *testing.T) {
	t.Parallel()

	var addedStatus domain.GroupMemberStatus
	public := newTestGroup(domain.GroupVisibilityPublic)
	public.MyMembershipStatus = domain.MembershipNone
	public.MyRole = ""

	groupRepo := &mockGroupRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) { return public, nil },
	}
	memberRepo := &mockGroupMemberRepo{
		addFn: func(_ context.Context, _, _ string, _ domain.GroupMemberRole, status domain.GroupMemberStatus) error {
			addedStatus = status
			return nil
		},
	}
	svc := NewGroupService(groupRepo, memberRepo)

	if _, err := svc.RequestJoin(context.Background(), "user-2", "group-1"); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if addedStatus != domain.GroupMemberStatusPending {
		t.Errorf("expected pending membership, got %q", addedStatus)
	}
}

func TestGroupService_RequestJoin_PrivateForbidden(t *testing.T) {
	t.Parallel()

	private := newTestGroup(domain.GroupVisibilityPrivate)
	private.MyMembershipStatus = domain.MembershipNone
	groupRepo := &mockGroupRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) { return private, nil },
	}
	svc := NewGroupService(groupRepo, &mockGroupMemberRepo{})

	_, err := svc.RequestJoin(context.Background(), "user-2", "group-1")
	if !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden, got %v", err)
	}
}

func TestGroupService_RequestJoin_AlreadyMemberConflict(t *testing.T) {
	t.Parallel()

	public := newTestGroup(domain.GroupVisibilityPublic)
	public.MyMembershipStatus = string(domain.GroupMemberStatusActive)
	groupRepo := &mockGroupRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) { return public, nil },
	}
	svc := NewGroupService(groupRepo, &mockGroupMemberRepo{})

	_, err := svc.RequestJoin(context.Background(), "user-2", "group-1")
	if !errors.Is(err, domain.ErrConflict) {
		t.Errorf("expected ErrConflict, got %v", err)
	}
}

// --- JoinByCode tests ---

func TestGroupService_JoinByCode_Success(t *testing.T) {
	t.Parallel()

	var addedStatus domain.GroupMemberStatus
	private := newTestGroup(domain.GroupVisibilityPrivate)
	private.MyMembershipStatus = domain.MembershipNone
	groupRepo := &mockGroupRepo{
		getByInviteCodeFn: func(_ context.Context, _, _ string) (*domain.Group, error) { return private, nil },
		getByIDFn:         func(_ context.Context, _, _ string) (*domain.Group, error) { return private, nil },
	}
	memberRepo := &mockGroupMemberRepo{
		addFn: func(_ context.Context, _, _ string, _ domain.GroupMemberRole, status domain.GroupMemberStatus) error {
			addedStatus = status
			return nil
		},
	}
	svc := NewGroupService(groupRepo, memberRepo)

	if _, err := svc.JoinByCode(context.Background(), "user-2", "ABCD2345"); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if addedStatus != domain.GroupMemberStatusActive {
		t.Errorf("expected active membership via code, got %q", addedStatus)
	}
}

func TestGroupService_JoinByCode_Invalid(t *testing.T) {
	t.Parallel()

	groupRepo := &mockGroupRepo{
		getByInviteCodeFn: func(_ context.Context, _, _ string) (*domain.Group, error) {
			return nil, domain.ErrInvalidInviteCode
		},
	}
	svc := NewGroupService(groupRepo, &mockGroupMemberRepo{})

	_, err := svc.JoinByCode(context.Background(), "user-2", "BADCODE1")
	if !errors.Is(err, domain.ErrInvalidInviteCode) {
		t.Errorf("expected ErrInvalidInviteCode, got %v", err)
	}
}

// --- Approve / Reject tests ---

func TestGroupService_ApproveRequest_Success(t *testing.T) {
	t.Parallel()

	var newStatus domain.GroupMemberStatus
	groupRepo := &mockGroupRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) {
			return newTestGroup(domain.GroupVisibilityPublic), nil // owner == user-1
		},
	}
	memberRepo := &mockGroupMemberRepo{
		getFn: func(_ context.Context, _, _ string) (*domain.GroupMember, error) {
			return &domain.GroupMember{Status: domain.GroupMemberStatusPending}, nil
		},
		setStatusFn: func(_ context.Context, _, _ string, status domain.GroupMemberStatus) error {
			newStatus = status
			return nil
		},
	}
	svc := NewGroupService(groupRepo, memberRepo)

	if err := svc.ApproveRequest(context.Background(), "user-1", "group-1", "user-2"); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if newStatus != domain.GroupMemberStatusActive {
		t.Errorf("expected active after approval, got %q", newStatus)
	}
}

func TestGroupService_ApproveRequest_NotOwnerForbidden(t *testing.T) {
	t.Parallel()

	groupRepo := &mockGroupRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) {
			g := newTestGroup(domain.GroupVisibilityPublic)
			g.OwnerID = "someone-else"
			return g, nil
		},
	}
	svc := NewGroupService(groupRepo, &mockGroupMemberRepo{})

	err := svc.ApproveRequest(context.Background(), "user-2", "group-1", "user-3")
	if !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden, got %v", err)
	}
}

// --- Leave tests ---

func TestGroupService_Leave_OwnerCannotLeave(t *testing.T) {
	t.Parallel()

	groupRepo := &mockGroupRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) {
			return newTestGroup(domain.GroupVisibilityPublic), nil // owner == user-1
		},
	}
	svc := NewGroupService(groupRepo, &mockGroupMemberRepo{})

	err := svc.Leave(context.Background(), "user-1", "group-1")
	if !errors.Is(err, domain.ErrConflict) {
		t.Errorf("expected ErrConflict for owner leaving, got %v", err)
	}
}

func TestGroupService_Leave_MemberSuccess(t *testing.T) {
	t.Parallel()

	removed := false
	groupRepo := &mockGroupRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Group, error) {
			return newTestGroup(domain.GroupVisibilityPublic), nil // owner == user-1
		},
	}
	memberRepo := &mockGroupMemberRepo{
		removeFn: func(_ context.Context, _, _ string) error {
			removed = true
			return nil
		},
	}
	svc := NewGroupService(groupRepo, memberRepo)

	if err := svc.Leave(context.Background(), "user-2", "group-1"); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !removed {
		t.Error("expected membership to be removed")
	}
}
