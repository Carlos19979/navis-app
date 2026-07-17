package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// BoatService implements business logic for boat operations.
type BoatService struct {
	repo     port.BoatRepository
	profiles port.ProfileRepository
}

// NewBoatService creates a new BoatService.
func NewBoatService(repo port.BoatRepository, profiles port.ProfileRepository) *BoatService {
	return &BoatService{repo: repo, profiles: profiles}
}

// Create persists a new boat after basic validation and plan-limit checks.
func (s *BoatService) Create(ctx context.Context, boat *domain.Boat) (*domain.Boat, error) {
	if boat.Name == "" {
		return nil, &domain.ValidationError{Field: "name", Message: "name is required"}
	}
	if boat.UserID == "" {
		return nil, fmt.Errorf("creating boat: %w", domain.ErrUnauthorized)
	}

	// Enforce the per-plan boat quota.
	if s.profiles != nil {
		profile, err := s.profiles.GetOrCreate(ctx, boat.UserID)
		if err != nil {
			return nil, fmt.Errorf("creating boat: %w", err)
		}
		count, err := s.repo.Count(ctx, boat.UserID)
		if err != nil {
			return nil, fmt.Errorf("creating boat: %w", err)
		}
		if count >= profile.Plan.MaxBoats() {
			return nil, fmt.Errorf("creating boat: %w", domain.ErrPlanLimit)
		}
	}
	if err := s.checkGallery(ctx, boat); err != nil {
		return nil, fmt.Errorf("creating boat: %w", err)
	}

	created, err := s.repo.Create(ctx, boat)
	if err != nil {
		return nil, fmt.Errorf("creating boat: %w", err)
	}
	return created, nil
}

// GetByID retrieves a single boat owned by the given user.
func (s *BoatService) GetByID(ctx context.Context, userID, id string) (*domain.Boat, error) {
	boat, err := s.repo.GetByID(ctx, userID, id)
	if err != nil {
		return nil, fmt.Errorf("getting boat %s: %w", id, err)
	}
	return boat, nil
}

// List returns a paginated list of boats for a user.
func (s *BoatService) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error) {
	limit = pagination.ClampLimit(limit)

	boats, nextCursor, err := s.repo.List(ctx, userID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing boats: %w", err)
	}
	return boats, nextCursor, nil
}

// maxBoatPhotos is the hard cap of gallery photos per boat (any plan).
const maxBoatPhotos = 10

// checkGallery normalizes the gallery list and enforces the per-plan photo
// quota. GalleryLimit counts the photo_url cover, so the extras in PhotoURLs
// may use the remaining slots (Free = cover only, Pro = 10 in total).
func (s *BoatService) checkGallery(ctx context.Context, boat *domain.Boat) error {
	if boat.PhotoURLs == nil {
		boat.PhotoURLs = []string{}
	}
	if len(boat.PhotoURLs) > maxBoatPhotos {
		return &domain.ValidationError{Field: "photo_urls", Message: "at most 10 gallery photos"}
	}
	if s.profiles == nil || len(boat.PhotoURLs) == 0 {
		return nil
	}
	profile, err := s.profiles.GetOrCreate(ctx, boat.UserID)
	if err != nil {
		return err
	}
	if len(boat.PhotoURLs) > profile.Plan.GalleryLimit()-1 {
		return domain.ErrPlanLimit
	}
	return nil
}

// Update modifies an existing boat.
func (s *BoatService) Update(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error) {
	if boat.ID == "" {
		return nil, &domain.ValidationError{Field: "id", Message: "id is required"}
	}
	if err := s.checkGallery(ctx, boat); err != nil {
		return nil, fmt.Errorf("updating boat %s: %w", boat.ID, err)
	}

	updated, err := s.repo.Update(ctx, userID, boat)
	if err != nil {
		return nil, fmt.Errorf("updating boat %s: %w", boat.ID, err)
	}
	return updated, nil
}

// Delete removes a boat if owned by the user.
func (s *BoatService) Delete(ctx context.Context, userID, id string) error {
	if err := s.repo.Delete(ctx, userID, id); err != nil {
		return fmt.Errorf("deleting boat %s: %w", id, err)
	}
	return nil
}

// GetAccessible returns a boat the user owns or is a shared member of. Used by
// the boat-detail read path only; ownership checks elsewhere stay strict.
func (s *BoatService) GetAccessible(ctx context.Context, userID, id string) (*domain.Boat, error) {
	boat, err := s.repo.GetByIDAccessible(ctx, userID, id)
	if err != nil {
		return nil, fmt.Errorf("getting boat %s: %w", id, err)
	}
	return boat, nil
}

// ListShared returns boats shared with the user.
func (s *BoatService) ListShared(ctx context.Context, userID string) ([]domain.Boat, error) {
	return s.repo.ListShared(ctx, userID)
}

// ShareCode returns (creating if needed) the boat's invite code. Owner only.
func (s *BoatService) ShareCode(ctx context.Context, userID, boatID string) (string, error) {
	candidate, err := randomCode(8)
	if err != nil {
		return "", err
	}
	code, err := s.repo.EnsureShareCode(ctx, userID, boatID, candidate)
	if err != nil {
		return "", fmt.Errorf("boat share code: %w", err)
	}
	return code, nil
}

// JoinByCode adds the user as a shared member of the boat for the code.
func (s *BoatService) JoinByCode(ctx context.Context, userID, code string) (*domain.Boat, error) {
	boatID, ownerID, err := s.repo.GetIDByShareCode(ctx, code)
	if err != nil {
		return nil, fmt.Errorf("joining boat: %w", err)
	}
	if ownerID == userID {
		return s.repo.GetByID(ctx, userID, boatID) // already the owner
	}
	if err := s.repo.AddMember(ctx, boatID, userID, "viewer"); err != nil {
		return nil, fmt.Errorf("joining boat: %w", err)
	}
	return s.repo.GetByIDAccessible(ctx, userID, boatID)
}

// ListMembers returns a boat's shared members. Owner only.
func (s *BoatService) ListMembers(ctx context.Context, userID, boatID string) ([]domain.BoatMember, error) {
	if _, err := s.repo.GetByID(ctx, userID, boatID); err != nil { // strict: owner
		return nil, fmt.Errorf("listing boat members: %w", err)
	}
	return s.repo.ListMembers(ctx, boatID)
}

// RemoveMember revokes a member's access. Owner only (enforced in repo).
func (s *BoatService) RemoveMember(ctx context.Context, ownerID, boatID, memberUserID string) error {
	return s.repo.RemoveMember(ctx, ownerID, boatID, memberUserID)
}

// SetMemberPermissions updates a member's granular permission flags. Owner only.
func (s *BoatService) SetMemberPermissions(ctx context.Context, ownerID, boatID, memberUserID string, p domain.BoatPermissions) error {
	return s.repo.SetPermissions(ctx, ownerID, boatID, memberUserID, p)
}

// Permissions resolves a user's permission set for a boat (access=false if none).
func (s *BoatService) Permissions(ctx context.Context, userID, boatID string) (domain.BoatPermissions, bool, error) {
	return s.repo.GetPermissions(ctx, userID, boatID)
}

// Leave removes the user's own membership of a shared boat.
func (s *BoatService) Leave(ctx context.Context, userID, boatID string) error {
	return s.repo.Leave(ctx, userID, boatID)
}
