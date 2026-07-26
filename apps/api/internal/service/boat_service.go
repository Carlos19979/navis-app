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
	notifier *Notifier
}

// NewBoatService creates a new BoatService.
func NewBoatService(repo port.BoatRepository, profiles port.ProfileRepository, notifier *Notifier) *BoatService {
	return &BoatService{repo: repo, profiles: profiles, notifier: notifier}
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

// ListShared returns boats shared with the user, each with the caller's
// effective permissions on it.
//
// Permissions are resolved per boat rather than in the list query: this list is
// the handful of boats a user has been invited to (it is not paginated for that
// reason), and keeping the resolution in GetPermissions means the owner /
// member / no-access rules live in exactly one place.
func (s *BoatService) ListShared(ctx context.Context, userID string) ([]domain.SharedBoat, error) {
	boats, err := s.repo.ListShared(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("listing shared boats: %w", err)
	}

	out := make([]domain.SharedBoat, 0, len(boats))
	for i := range boats {
		perms, _, err := s.repo.GetPermissions(ctx, userID, boats[i].ID)
		if err != nil {
			return nil, fmt.Errorf("listing shared boats: %w", err)
		}
		out = append(out, domain.SharedBoat{Boat: boats[i], Permissions: perms})
	}
	return out, nil
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

// JoinByCode adds the user as a shared member of the boat for the code. It
// returns the boat together with the permissions the new membership carries:
// members join as viewers, so the client can say so straight away instead of
// letting the user record a whole trip and hit a 403 on save.
func (s *BoatService) JoinByCode(ctx context.Context, userID, code string) (*domain.SharedBoat, error) {
	boatID, ownerID, err := s.repo.GetIDByShareCode(ctx, code)
	if err != nil {
		return nil, fmt.Errorf("joining boat: %w", err)
	}
	if ownerID == userID {
		boat, err := s.repo.GetByID(ctx, userID, boatID) // already the owner
		if err != nil {
			return nil, fmt.Errorf("joining boat: %w", err)
		}
		return &domain.SharedBoat{Boat: *boat, Permissions: domain.OwnerPermissions()}, nil
	}
	if err := s.repo.AddMember(ctx, boatID, userID, "viewer"); err != nil {
		return nil, fmt.Errorf("joining boat: %w", err)
	}
	// Notify the boat owner that someone joined their boat.
	if s.notifier != nil {
		name := s.notifier.UserName(ctx, userID)
		s.notifier.Send(ctx, ownerID, WorkflowBoatMemberJoined,
			"Nuevo tripulante",
			fmt.Sprintf("%s se ha unido a tu barco", name),
			"boat", boatID)
	}

	boat, err := s.repo.GetByIDAccessible(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("joining boat: %w", err)
	}
	perms, _, err := s.repo.GetPermissions(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("joining boat: %w", err)
	}
	return &domain.SharedBoat{Boat: *boat, Permissions: perms}, nil
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
	if err := s.repo.RemoveMember(ctx, ownerID, boatID, memberUserID); err != nil {
		return err
	}
	// Notify the member that their access was revoked.
	if s.notifier != nil {
		s.notifier.Send(ctx, memberUserID, WorkflowBoatMemberRemoved,
			"Acceso revocado",
			"Ya no tienes acceso a un barco compartido",
			"boat", boatID)
	}
	return nil
}

// SetMemberPermissions updates a member's granular permission flags. Owner only.
func (s *BoatService) SetMemberPermissions(ctx context.Context, ownerID, boatID, memberUserID string, p domain.BoatPermissions) error {
	return s.repo.SetPermissions(ctx, ownerID, boatID, memberUserID, p)
}

// EffectivePermissions resolves what the user is allowed to do on a boat. It is
// the read side of the flags the write paths enforce (trips, documents,
// maintenance, expenses), so a client can disable a blocked action up front
// instead of letting the user do the work and fail with a 403 on save.
//
// A caller with no access at all gets ErrBoatNotFound rather than an empty
// permission set: this endpoint must not double as a probe for boat ids.
func (s *BoatService) EffectivePermissions(ctx context.Context, userID, boatID string) (domain.BoatPermissions, error) {
	perms, hasAccess, err := s.repo.GetPermissions(ctx, userID, boatID)
	if err != nil {
		return domain.BoatPermissions{}, fmt.Errorf("getting permissions for boat %s: %w", boatID, err)
	}
	if !hasAccess {
		return domain.BoatPermissions{}, fmt.Errorf("getting permissions for boat %s: %w", boatID, domain.ErrBoatNotFound)
	}
	return perms, nil
}

// Leave removes the user's own membership of a shared boat.
func (s *BoatService) Leave(ctx context.Context, userID, boatID string) error {
	return s.repo.Leave(ctx, userID, boatID)
}
