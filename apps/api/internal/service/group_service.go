package service

import (
	"context"
	"crypto/rand"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// GroupService implements business logic for groups (clubs/crews) and membership.
type GroupService struct {
	groupRepo  port.GroupRepository
	memberRepo port.GroupMemberRepository
}

// NewGroupService creates a new GroupService.
func NewGroupService(groupRepo port.GroupRepository, memberRepo port.GroupMemberRepository) *GroupService {
	return &GroupService{groupRepo: groupRepo, memberRepo: memberRepo}
}

// inviteCodeAlphabet excludes ambiguous characters (0/O, 1/I/L) for readability.
const inviteCodeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

// generateInviteCode returns a random 8-character invite code.
func generateInviteCode() (string, error) {
	const n = 8
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generating invite code: %w", err)
	}
	for i := range buf {
		buf[i] = inviteCodeAlphabet[int(buf[i])%len(inviteCodeAlphabet)]
	}
	return string(buf), nil
}

// Create persists a new group and registers the owner as an active member.
func (s *GroupService) Create(ctx context.Context, group *domain.Group) (*domain.Group, error) {
	if group.Name == "" {
		return nil, &domain.ValidationError{Field: "name", Message: "name is required"}
	}
	if group.OwnerID == "" {
		return nil, fmt.Errorf("creating group: %w", domain.ErrUnauthorized)
	}

	// Private groups are joined with an invite code; public groups are join-by-request.
	if group.Visibility == domain.GroupVisibilityPrivate {
		code, err := generateInviteCode()
		if err != nil {
			return nil, fmt.Errorf("creating group: %w", err)
		}
		group.InviteCode = &code
	}

	created, err := s.groupRepo.Create(ctx, group)
	if err != nil {
		return nil, fmt.Errorf("creating group: %w", err)
	}

	if err := s.memberRepo.Add(ctx, created.ID, created.OwnerID,
		domain.GroupRoleOwner, domain.GroupMemberStatusActive); err != nil {
		return nil, fmt.Errorf("adding group owner %s: %w", created.OwnerID, err)
	}

	// Re-read so derived fields (member count, my role/status) are populated.
	return s.groupRepo.GetByID(ctx, created.OwnerID, created.ID)
}

// GetByID returns a group visible to the user (public, owned, or a member).
func (s *GroupService) GetByID(ctx context.Context, userID, id string) (*domain.Group, error) {
	group, err := s.groupRepo.GetByID(ctx, userID, id)
	if err != nil {
		return nil, fmt.Errorf("getting group %s: %w", id, err)
	}
	return group, nil
}

// List returns groups the user is an active member of.
func (s *GroupService) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	groups, next, err := s.groupRepo.List(ctx, userID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing groups: %w", err)
	}
	return groups, next, nil
}

// ListPublic returns discoverable public groups the user has not yet joined.
func (s *GroupService) ListPublic(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	groups, next, err := s.groupRepo.ListPublic(ctx, userID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing public groups: %w", err)
	}
	return groups, next, nil
}

// Update modifies a group owned by the user.
func (s *GroupService) Update(ctx context.Context, userID string, group *domain.Group) (*domain.Group, error) {
	if group.ID == "" {
		return nil, &domain.ValidationError{Field: "id", Message: "id is required"}
	}
	if _, err := s.groupRepo.Update(ctx, userID, group); err != nil {
		return nil, fmt.Errorf("updating group %s: %w", group.ID, err)
	}
	// Re-read so derived fields (member count, my role/status) are populated.
	return s.groupRepo.GetByID(ctx, userID, group.ID)
}

// Delete removes a group owned by the user.
func (s *GroupService) Delete(ctx context.Context, userID, id string) error {
	if err := s.groupRepo.Delete(ctx, userID, id); err != nil {
		return fmt.Errorf("deleting group %s: %w", id, err)
	}
	return nil
}

// RequestJoin creates a pending membership request for a public group.
func (s *GroupService) RequestJoin(ctx context.Context, userID, groupID string) (*domain.Group, error) {
	group, err := s.groupRepo.GetByID(ctx, userID, groupID)
	if err != nil {
		return nil, fmt.Errorf("requesting to join group %s: %w", groupID, err)
	}
	if group.Visibility != domain.GroupVisibilityPublic {
		return nil, fmt.Errorf("requesting to join group %s: %w", groupID, domain.ErrForbidden)
	}
	if group.MyMembershipStatus == string(domain.GroupMemberStatusActive) {
		return nil, fmt.Errorf("requesting to join group %s: %w", groupID, domain.ErrConflict)
	}

	if err := s.memberRepo.Add(ctx, groupID, userID,
		domain.GroupRoleMember, domain.GroupMemberStatusPending); err != nil {
		return nil, fmt.Errorf("requesting to join group %s: %w", groupID, err)
	}
	return s.groupRepo.GetByID(ctx, userID, groupID)
}

// JoinByCode joins a private group directly using its invite code.
func (s *GroupService) JoinByCode(ctx context.Context, userID, code string) (*domain.Group, error) {
	group, err := s.groupRepo.GetByInviteCode(ctx, userID, code)
	if err != nil {
		return nil, fmt.Errorf("joining by code: %w", err)
	}
	if group.MyMembershipStatus == string(domain.GroupMemberStatusActive) {
		return group, nil // already a member — idempotent
	}

	if err := s.memberRepo.Add(ctx, group.ID, userID,
		domain.GroupRoleMember, domain.GroupMemberStatusActive); err != nil {
		return nil, fmt.Errorf("joining group %s by code: %w", group.ID, err)
	}
	return s.groupRepo.GetByID(ctx, userID, group.ID)
}

// ListMembers returns the active members of a group the user can see.
func (s *GroupService) ListMembers(ctx context.Context, userID, groupID string) ([]domain.GroupMember, error) {
	if _, err := s.groupRepo.GetByID(ctx, userID, groupID); err != nil {
		return nil, fmt.Errorf("listing members of group %s: %w", groupID, err)
	}
	members, err := s.memberRepo.ListMembers(ctx, groupID)
	if err != nil {
		return nil, fmt.Errorf("listing members of group %s: %w", groupID, err)
	}
	return members, nil
}

// Leave removes the user's own membership. The owner cannot leave their own group.
func (s *GroupService) Leave(ctx context.Context, userID, groupID string) error {
	group, err := s.groupRepo.GetByID(ctx, userID, groupID)
	if err != nil {
		return fmt.Errorf("leaving group %s: %w", groupID, err)
	}
	if group.OwnerID == userID {
		return fmt.Errorf("owner cannot leave their own group %s: %w", groupID, domain.ErrConflict)
	}
	if err := s.memberRepo.Remove(ctx, groupID, userID); err != nil {
		return fmt.Errorf("leaving group %s: %w", groupID, err)
	}
	return nil
}

// ListPendingRequests returns pending join requests; only the owner may view them.
func (s *GroupService) ListPendingRequests(ctx context.Context, ownerID, groupID string) ([]domain.GroupMember, error) {
	if err := s.assertOwner(ctx, ownerID, groupID); err != nil {
		return nil, err
	}
	pending, err := s.memberRepo.ListPending(ctx, groupID)
	if err != nil {
		return nil, fmt.Errorf("listing pending requests for group %s: %w", groupID, err)
	}
	return pending, nil
}

// ApproveRequest promotes a pending membership to active; only the owner may approve.
func (s *GroupService) ApproveRequest(ctx context.Context, ownerID, groupID, targetUserID string) error {
	if err := s.assertOwner(ctx, ownerID, groupID); err != nil {
		return err
	}
	member, err := s.memberRepo.Get(ctx, groupID, targetUserID)
	if err != nil {
		return fmt.Errorf("approving request in group %s: %w", groupID, err)
	}
	if member.Status != domain.GroupMemberStatusPending {
		return fmt.Errorf("approving request in group %s: %w", groupID, domain.ErrConflict)
	}
	if err := s.memberRepo.SetStatus(ctx, groupID, targetUserID, domain.GroupMemberStatusActive); err != nil {
		return fmt.Errorf("approving request in group %s: %w", groupID, err)
	}
	return nil
}

// RejectRequest removes a pending membership; only the owner may reject.
func (s *GroupService) RejectRequest(ctx context.Context, ownerID, groupID, targetUserID string) error {
	if err := s.assertOwner(ctx, ownerID, groupID); err != nil {
		return err
	}
	if err := s.memberRepo.Remove(ctx, groupID, targetUserID); err != nil {
		return fmt.Errorf("rejecting request in group %s: %w", groupID, err)
	}
	return nil
}

// RemoveMember removes a member from the group; only the owner may remove others.
func (s *GroupService) RemoveMember(ctx context.Context, ownerID, groupID, targetUserID string) error {
	if err := s.assertOwner(ctx, ownerID, groupID); err != nil {
		return err
	}
	if targetUserID == ownerID {
		return fmt.Errorf("owner cannot remove themselves from group %s: %w", groupID, domain.ErrConflict)
	}
	if err := s.memberRepo.Remove(ctx, groupID, targetUserID); err != nil {
		return fmt.Errorf("removing member from group %s: %w", groupID, err)
	}
	return nil
}

// assertOwner returns ErrForbidden unless the user owns the group.
func (s *GroupService) assertOwner(ctx context.Context, userID, groupID string) error {
	group, err := s.groupRepo.GetByID(ctx, userID, groupID)
	if err != nil {
		return fmt.Errorf("checking group ownership %s: %w", groupID, err)
	}
	if group.OwnerID != userID {
		return fmt.Errorf("group %s: %w", groupID, domain.ErrForbidden)
	}
	return nil
}
