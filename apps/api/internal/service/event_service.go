package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// EventService implements business logic for event operations.
// Events are read-only for regular users; they are managed externally.
type EventService struct {
	eventRepo    port.EventRepository
	interestRepo port.EventInterestRepository
}

// NewEventService creates a new EventService.
func NewEventService(eventRepo port.EventRepository, interestRepo port.EventInterestRepository) *EventService {
	return &EventService{
		eventRepo:    eventRepo,
		interestRepo: interestRepo,
	}
}

// GetByID retrieves a single event.
func (s *EventService) GetByID(ctx context.Context, id string) (*domain.Event, error) {
	event, err := s.eventRepo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting event %s: %w", id, err)
	}
	return event, nil
}

// List returns a paginated list of all events.
func (s *EventService) List(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	events, nextCursor, err := s.eventRepo.List(ctx, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing events: %w", err)
	}
	return events, nextCursor, nil
}

// ListUpcoming returns upcoming events in chronological order.
func (s *EventService) ListUpcoming(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	events, nextCursor, err := s.eventRepo.ListUpcoming(ctx, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing upcoming events: %w", err)
	}
	return events, nextCursor, nil
}

// NearLocation returns events within a given radius of coordinates.
func (s *EventService) NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Event, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	if radiusKM <= 0 {
		radiusKM = 50
	}

	events, nextCursor, err := s.eventRepo.NearLocation(ctx, lat, lon, radiusKM, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing events near %.4f,%.4f: %w", lat, lon, err)
	}
	return events, nextCursor, nil
}

// ToggleInterest toggles the current user's interest in an event.
// Returns true if the user is now interested, false if interest was removed.
func (s *EventService) ToggleInterest(ctx context.Context, userID, eventID string) (bool, error) {
	// Verify the event exists.
	if _, err := s.eventRepo.GetByID(ctx, eventID); err != nil {
		return false, fmt.Errorf("toggling interest for event %s: %w", eventID, err)
	}

	interested, err := s.interestRepo.Toggle(ctx, userID, eventID)
	if err != nil {
		return false, fmt.Errorf("toggling interest for event %s: %w", eventID, err)
	}
	return interested, nil
}

// IsInterested checks whether a user has expressed interest in an event.
func (s *EventService) IsInterested(ctx context.Context, userID, eventID string) (bool, error) {
	interested, err := s.interestRepo.IsInterested(ctx, userID, eventID)
	if err != nil {
		return false, fmt.Errorf("checking interest for event %s: %w", eventID, err)
	}
	return interested, nil
}
