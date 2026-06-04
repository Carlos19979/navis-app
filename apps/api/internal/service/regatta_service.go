package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// RegattaService handles group trips/regattas: scheduling, RSVP, the pre-departure
// safety checklist, and the planned -> recording transition. It reuses the trip
// persistence layer so recorded regattas behave exactly like solo trips.
type RegattaService struct {
	tripRepo        port.TripRepository
	participantRepo port.TripParticipantRepository
	checklistRepo   port.TripChecklistRepository
	memberRepo      port.GroupMemberRepository
}

// NewRegattaService creates a new RegattaService.
func NewRegattaService(
	tripRepo port.TripRepository,
	participantRepo port.TripParticipantRepository,
	checklistRepo port.TripChecklistRepository,
	memberRepo port.GroupMemberRepository,
) *RegattaService {
	return &RegattaService{
		tripRepo:        tripRepo,
		participantRepo: participantRepo,
		checklistRepo:   checklistRepo,
		memberRepo:      memberRepo,
	}
}

// assertActiveMember returns ErrForbidden unless the user is an active group member.
func (s *RegattaService) assertActiveMember(ctx context.Context, groupID, userID string) error {
	member, err := s.memberRepo.Get(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, domain.ErrMembershipNotFound) {
			return fmt.Errorf("group %s: %w", groupID, domain.ErrForbidden)
		}
		return fmt.Errorf("checking membership in group %s: %w", groupID, err)
	}
	if member.Status != domain.GroupMemberStatusActive {
		return fmt.Errorf("group %s: %w", groupID, domain.ErrForbidden)
	}
	return nil
}

// Schedule creates a planned regatta/outing for a group. Only active members may
// schedule. The creator is auto-RSVP'd as going.
func (s *RegattaService) Schedule(ctx context.Context, userID, groupID string, trip *domain.Trip) (*domain.Trip, error) {
	if err := s.assertActiveMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	if trip.DeparturePort == "" {
		return nil, &domain.ValidationError{Field: "departure_port", Message: "departure port is required"}
	}

	gid := groupID
	trip.GroupID = &gid
	trip.UserID = userID
	trip.Kind = domain.TripKindRegatta
	trip.Status = domain.TripStatusPlanned
	if trip.ScheduledAt != nil {
		trip.DepartureTime = *trip.ScheduledAt
	} else {
		trip.DepartureTime = time.Now().UTC()
	}

	created, err := s.tripRepo.Create(ctx, trip)
	if err != nil {
		return nil, fmt.Errorf("scheduling regatta: %w", err)
	}

	// The organiser is going by default; ignore RSVP failure (non-critical).
	_ = s.participantRepo.SetRSVP(ctx, created.ID, userID, domain.RSVPGoing)
	return created, nil
}

// ListByGroup returns a group's trips/regattas. Only active members may view them.
func (s *RegattaService) ListByGroup(ctx context.Context, userID, groupID, cursor string, limit int) ([]domain.Trip, string, error) {
	if err := s.assertActiveMember(ctx, groupID, userID); err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	trips, next, err := s.tripRepo.ListByGroup(ctx, groupID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing group trips: %w", err)
	}
	return trips, next, nil
}

// Cancel marks a planned/recording trip as cancelled. Only the organiser may cancel.
func (s *RegattaService) Cancel(ctx context.Context, userID, tripID string) (*domain.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, userID, tripID)
	if err != nil {
		return nil, fmt.Errorf("cancelling trip %s: %w", tripID, err)
	}
	if trip.Status == domain.TripStatusCompleted {
		return nil, fmt.Errorf("cancelling trip %s: %w: already completed", tripID, domain.ErrConflict)
	}
	trip.Status = domain.TripStatusCancelled
	updated, err := s.tripRepo.Update(ctx, userID, trip)
	if err != nil {
		return nil, fmt.Errorf("cancelling trip %s: %w", tripID, err)
	}
	return updated, nil
}

// Start transitions a planned trip into recording. The safety checklist must be
// completed first (the mandatory pre-departure gate).
func (s *RegattaService) Start(ctx context.Context, userID, tripID string) (*domain.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, userID, tripID)
	if err != nil {
		return nil, fmt.Errorf("starting trip %s: %w", tripID, err)
	}
	if trip.Status != domain.TripStatusPlanned {
		return nil, fmt.Errorf("starting trip %s: %w: trip is not planned", tripID, domain.ErrConflict)
	}
	if trip.ChecklistCompletedAt == nil {
		return nil, fmt.Errorf("starting trip %s: %w: safety checklist not completed", tripID, domain.ErrConflict)
	}

	now := time.Now().UTC()
	trip.Status = domain.TripStatusRecording
	trip.DepartureTime = now
	updated, err := s.tripRepo.Update(ctx, userID, trip)
	if err != nil {
		return nil, fmt.Errorf("starting trip %s: %w", tripID, err)
	}
	return updated, nil
}

// SetRSVP records the user's attendance answer for a group trip they can see.
func (s *RegattaService) SetRSVP(ctx context.Context, userID, tripID string, rsvp domain.RSVP) error {
	if _, err := s.visibleGroupTrip(ctx, userID, tripID); err != nil {
		return err
	}
	if err := s.participantRepo.SetRSVP(ctx, tripID, userID, rsvp); err != nil {
		return fmt.Errorf("setting RSVP for trip %s: %w", tripID, err)
	}
	return nil
}

// ListParticipants returns the RSVPs for a group trip visible to the user.
func (s *RegattaService) ListParticipants(ctx context.Context, userID, tripID string) ([]domain.TripParticipant, error) {
	if _, err := s.visibleGroupTrip(ctx, userID, tripID); err != nil {
		return nil, err
	}
	participants, err := s.participantRepo.ListByTrip(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("listing participants for trip %s: %w", tripID, err)
	}
	return participants, nil
}

// visibleGroupTrip returns a group trip if the user is an active member of its group.
func (s *RegattaService) visibleGroupTrip(ctx context.Context, userID, tripID string) (*domain.Trip, error) {
	trip, err := s.tripRepo.GetByIDUnscoped(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("getting trip %s: %w", tripID, err)
	}
	if trip.GroupID == nil {
		// Solo trips are only visible to their owner.
		if trip.UserID != userID {
			return nil, fmt.Errorf("trip %s: %w", tripID, domain.ErrForbidden)
		}
		return trip, nil
	}
	if err := s.assertActiveMember(ctx, *trip.GroupID, userID); err != nil {
		return nil, err
	}
	return trip, nil
}

// --- Checklist (works for both solo trips and regattas; owner-scoped) ---

// GetChecklist returns a trip's safety checklist, seeding it from the defaults on
// first access.
func (s *RegattaService) GetChecklist(ctx context.Context, userID, tripID string) ([]domain.ChecklistItem, error) {
	if _, err := s.tripRepo.GetByID(ctx, userID, tripID); err != nil {
		return nil, fmt.Errorf("getting checklist for trip %s: %w", tripID, err)
	}
	if err := s.checklistRepo.CopyDefaults(ctx, tripID); err != nil {
		return nil, fmt.Errorf("getting checklist for trip %s: %w", tripID, err)
	}
	items, err := s.checklistRepo.ListByTrip(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("getting checklist for trip %s: %w", tripID, err)
	}
	return items, nil
}

// AddChecklistItem appends a custom item to a trip's checklist.
func (s *RegattaService) AddChecklistItem(ctx context.Context, userID, tripID, label string) (*domain.ChecklistItem, error) {
	if _, err := s.tripRepo.GetByID(ctx, userID, tripID); err != nil {
		return nil, fmt.Errorf("adding checklist item to trip %s: %w", tripID, err)
	}
	if label == "" {
		return nil, &domain.ValidationError{Field: "label", Message: "label is required"}
	}
	count, err := s.checklistRepo.Count(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("adding checklist item to trip %s: %w", tripID, err)
	}
	item, err := s.checklistRepo.AddItem(ctx, tripID, label, count)
	if err != nil {
		return nil, fmt.Errorf("adding checklist item to trip %s: %w", tripID, err)
	}
	return item, nil
}

// SetChecklistItemChecked toggles a checklist item's checked state.
func (s *RegattaService) SetChecklistItemChecked(ctx context.Context, userID, tripID, itemID string, checked bool) (*domain.ChecklistItem, error) {
	if _, err := s.tripRepo.GetByID(ctx, userID, tripID); err != nil {
		return nil, fmt.Errorf("updating checklist item for trip %s: %w", tripID, err)
	}
	item, err := s.checklistRepo.SetChecked(ctx, tripID, itemID, checked)
	if err != nil {
		return nil, fmt.Errorf("updating checklist item for trip %s: %w", tripID, err)
	}
	return item, nil
}

// RemoveChecklistItem deletes a checklist item from a trip.
func (s *RegattaService) RemoveChecklistItem(ctx context.Context, userID, tripID, itemID string) error {
	if _, err := s.tripRepo.GetByID(ctx, userID, tripID); err != nil {
		return fmt.Errorf("removing checklist item from trip %s: %w", tripID, err)
	}
	if err := s.checklistRepo.RemoveItem(ctx, tripID, itemID); err != nil {
		return fmt.Errorf("removing checklist item from trip %s: %w", tripID, err)
	}
	return nil
}

// CompleteChecklist marks the safety checklist as completed (the gate for Start).
func (s *RegattaService) CompleteChecklist(ctx context.Context, userID, tripID string) (*domain.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, userID, tripID)
	if err != nil {
		return nil, fmt.Errorf("completing checklist for trip %s: %w", tripID, err)
	}
	now := time.Now().UTC()
	trip.ChecklistCompletedAt = &now
	updated, err := s.tripRepo.Update(ctx, userID, trip)
	if err != nil {
		return nil, fmt.Errorf("completing checklist for trip %s: %w", tripID, err)
	}
	return updated, nil
}
