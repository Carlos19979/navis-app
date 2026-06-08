package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// ProfileService exposes the current user's plan and derived limits.
type ProfileService struct {
	profiles port.ProfileRepository
	boats    port.BoatRepository
}

// NewProfileService creates a new ProfileService.
func NewProfileService(profiles port.ProfileRepository, boats port.BoatRepository) *ProfileService {
	return &ProfileService{profiles: profiles, boats: boats}
}

// Me returns the user's profile along with their current boat count.
func (s *ProfileService) Me(ctx context.Context, userID string) (*domain.Profile, int, error) {
	profile, err := s.profiles.GetOrCreate(ctx, userID)
	if err != nil {
		return nil, 0, fmt.Errorf("loading profile: %w", err)
	}
	count, err := s.boats.Count(ctx, userID)
	if err != nil {
		return nil, 0, fmt.Errorf("counting boats: %w", err)
	}
	return profile, count, nil
}

// SetPlan changes the user's plan (used by the dev plan switcher / future
// payment webhook).
func (s *ProfileService) SetPlan(ctx context.Context, userID string, plan domain.Plan) (*domain.Profile, error) {
	if !plan.Valid() {
		return nil, &domain.ValidationError{Field: "plan", Message: "invalid plan"}
	}
	return s.profiles.SetPlan(ctx, userID, plan)
}
