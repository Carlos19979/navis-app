package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// BoatService implements business logic for boat operations.
type BoatService struct {
	repo port.BoatRepository
}

// NewBoatService creates a new BoatService.
func NewBoatService(repo port.BoatRepository) *BoatService {
	return &BoatService{repo: repo}
}

// Create persists a new boat after basic validation.
func (s *BoatService) Create(ctx context.Context, boat *domain.Boat) (*domain.Boat, error) {
	if boat.Name == "" {
		return nil, &domain.ValidationError{Field: "name", Message: "name is required"}
	}
	if boat.UserID == "" {
		return nil, fmt.Errorf("creating boat: %w", domain.ErrUnauthorized)
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
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	boats, nextCursor, err := s.repo.List(ctx, userID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing boats: %w", err)
	}
	return boats, nextCursor, nil
}

// Update modifies an existing boat.
func (s *BoatService) Update(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error) {
	if boat.ID == "" {
		return nil, &domain.ValidationError{Field: "id", Message: "id is required"}
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
