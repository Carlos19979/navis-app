package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// --- mock TripParticipantRepository ---

type mockTripParticipantRepo struct {
	setRSVPFn    func(ctx context.Context, tripID, userID string, rsvp domain.RSVP) error
	removeFn     func(ctx context.Context, tripID, userID string) error
	listByTripFn func(ctx context.Context, tripID string) ([]domain.TripParticipant, error)
}

func (m *mockTripParticipantRepo) SetRSVP(ctx context.Context, tripID, userID string, rsvp domain.RSVP) error {
	if m.setRSVPFn == nil {
		return nil
	}
	return m.setRSVPFn(ctx, tripID, userID, rsvp)
}

func (m *mockTripParticipantRepo) Remove(ctx context.Context, tripID, userID string) error {
	return m.removeFn(ctx, tripID, userID)
}

func (m *mockTripParticipantRepo) ListByTrip(ctx context.Context, tripID string) ([]domain.TripParticipant, error) {
	return m.listByTripFn(ctx, tripID)
}

// --- mock TripChecklistRepository ---

type mockTripChecklistRepo struct {
	copyDefaultsFn func(ctx context.Context, tripID string) error
	countFn        func(ctx context.Context, tripID string) (int, error)
	listByTripFn   func(ctx context.Context, tripID string) ([]domain.ChecklistItem, error)
	addItemFn      func(ctx context.Context, tripID, label string, position int) (*domain.ChecklistItem, error)
	setCheckedFn   func(ctx context.Context, tripID, itemID string, checked bool) (*domain.ChecklistItem, error)
	removeItemFn   func(ctx context.Context, tripID, itemID string) error
}

func (m *mockTripChecklistRepo) CopyDefaults(ctx context.Context, tripID string) error {
	if m.copyDefaultsFn == nil {
		return nil
	}
	return m.copyDefaultsFn(ctx, tripID)
}

func (m *mockTripChecklistRepo) Count(ctx context.Context, tripID string) (int, error) {
	return m.countFn(ctx, tripID)
}

func (m *mockTripChecklistRepo) ListByTrip(ctx context.Context, tripID string) ([]domain.ChecklistItem, error) {
	return m.listByTripFn(ctx, tripID)
}

func (m *mockTripChecklistRepo) AddItem(ctx context.Context, tripID, label string, position int) (*domain.ChecklistItem, error) {
	return m.addItemFn(ctx, tripID, label, position)
}

func (m *mockTripChecklistRepo) SetChecked(ctx context.Context, tripID, itemID string, checked bool) (*domain.ChecklistItem, error) {
	return m.setCheckedFn(ctx, tripID, itemID, checked)
}

func (m *mockTripChecklistRepo) RemoveItem(ctx context.Context, tripID, itemID string) error {
	return m.removeItemFn(ctx, tripID, itemID)
}

// --- helpers ---

func activeMemberRepo() *mockGroupMemberRepo {
	return &mockGroupMemberRepo{
		getFn: func(_ context.Context, _, _ string) (*domain.GroupMember, error) {
			return &domain.GroupMember{Status: domain.GroupMemberStatusActive}, nil
		},
	}
}

// --- Schedule tests ---

func TestRegattaService_Schedule_Success(t *testing.T) {
	t.Parallel()

	var created *domain.Trip
	tripRepo := &mockTripRepo{
		createFn: func(_ context.Context, trip *domain.Trip) (*domain.Trip, error) {
			trip.ID = "trip-1"
			created = trip
			return trip, nil
		},
	}
	svc := NewRegattaService(tripRepo, &mockTripParticipantRepo{}, &mockTripChecklistRepo{}, activeMemberRepo(), nil)

	when := time.Now().Add(48 * time.Hour)
	in := &domain.Trip{BoatID: "boat-1", DeparturePort: "Palma", ScheduledAt: &when}
	out, err := svc.Schedule(context.Background(), "user-1", "group-1", in)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if out.Kind != domain.TripKindRegatta {
		t.Errorf("expected kind regatta, got %q", out.Kind)
	}
	if out.Status != domain.TripStatusPlanned {
		t.Errorf("expected status planned, got %q", out.Status)
	}
	if created.GroupID == nil || *created.GroupID != "group-1" {
		t.Errorf("expected group_id group-1, got %v", created.GroupID)
	}
	if !created.DepartureTime.Equal(when) {
		t.Errorf("expected departure_time to equal scheduled_at")
	}
}

func TestRegattaService_Schedule_NotMemberForbidden(t *testing.T) {
	t.Parallel()

	memberRepo := &mockGroupMemberRepo{
		getFn: func(_ context.Context, _, _ string) (*domain.GroupMember, error) {
			return nil, domain.ErrMembershipNotFound
		},
	}
	svc := NewRegattaService(&mockTripRepo{}, &mockTripParticipantRepo{}, &mockTripChecklistRepo{}, memberRepo, nil)

	_, err := svc.Schedule(context.Background(), "user-2", "group-1",
		&domain.Trip{BoatID: "boat-1", DeparturePort: "Palma"})
	if !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden, got %v", err)
	}
}

// --- Start gate tests ---

func TestRegattaService_Start_RequiresChecklist(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return &domain.Trip{ID: "trip-1", Status: domain.TripStatusPlanned, ChecklistCompletedAt: nil}, nil
		},
	}
	svc := NewRegattaService(tripRepo, &mockTripParticipantRepo{}, &mockTripChecklistRepo{}, activeMemberRepo(), nil)

	_, err := svc.Start(context.Background(), "user-1", "trip-1")
	if !errors.Is(err, domain.ErrConflict) {
		t.Errorf("expected ErrConflict (checklist gate), got %v", err)
	}
}

func TestRegattaService_Start_Success(t *testing.T) {
	t.Parallel()

	done := time.Now()
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return &domain.Trip{ID: "trip-1", Status: domain.TripStatusPlanned, ChecklistCompletedAt: &done}, nil
		},
		updateFn: func(_ context.Context, _ string, trip *domain.Trip) (*domain.Trip, error) {
			return trip, nil
		},
	}
	svc := NewRegattaService(tripRepo, &mockTripParticipantRepo{}, &mockTripChecklistRepo{}, activeMemberRepo(), nil)

	out, err := svc.Start(context.Background(), "user-1", "trip-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if out.Status != domain.TripStatusRecording {
		t.Errorf("expected status recording, got %q", out.Status)
	}
}

func TestRegattaService_Start_NotPlannedConflict(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return &domain.Trip{ID: "trip-1", Status: domain.TripStatusRecording}, nil
		},
	}
	svc := NewRegattaService(tripRepo, &mockTripParticipantRepo{}, &mockTripChecklistRepo{}, activeMemberRepo(), nil)

	_, err := svc.Start(context.Background(), "user-1", "trip-1")
	if !errors.Is(err, domain.ErrConflict) {
		t.Errorf("expected ErrConflict, got %v", err)
	}
}

// --- CompleteChecklist ---

func TestRegattaService_CompleteChecklist_SetsTimestamp(t *testing.T) {
	t.Parallel()

	var saved *domain.Trip
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return &domain.Trip{ID: "trip-1", Status: domain.TripStatusPlanned}, nil
		},
		updateFn: func(_ context.Context, _ string, trip *domain.Trip) (*domain.Trip, error) {
			saved = trip
			return trip, nil
		},
	}
	svc := NewRegattaService(tripRepo, &mockTripParticipantRepo{}, &mockTripChecklistRepo{}, activeMemberRepo(), nil)

	if _, err := svc.CompleteChecklist(context.Background(), "user-1", "trip-1"); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if saved.ChecklistCompletedAt == nil {
		t.Error("expected checklist_completed_at to be set")
	}
}

// --- RSVP visibility ---

func TestRegattaService_SetRSVP_NonMemberForbidden(t *testing.T) {
	t.Parallel()

	gid := "group-1"
	tripRepo := &mockTripRepo{
		getByIDUnscopedFn: func(_ context.Context, _ string) (*domain.Trip, error) {
			return &domain.Trip{ID: "trip-1", GroupID: &gid}, nil
		},
	}
	memberRepo := &mockGroupMemberRepo{
		getFn: func(_ context.Context, _, _ string) (*domain.GroupMember, error) {
			return nil, domain.ErrMembershipNotFound
		},
	}
	svc := NewRegattaService(tripRepo, &mockTripParticipantRepo{}, &mockTripChecklistRepo{}, memberRepo, nil)

	err := svc.SetRSVP(context.Background(), "outsider", "trip-1", domain.RSVPGoing)
	if !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("expected ErrForbidden, got %v", err)
	}
}

// --- GetChecklist seeds defaults ---

func TestRegattaService_GetChecklist_SeedsDefaults(t *testing.T) {
	t.Parallel()

	copied := false
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return &domain.Trip{ID: "trip-1"}, nil
		},
	}
	checklistRepo := &mockTripChecklistRepo{
		copyDefaultsFn: func(_ context.Context, _ string) error {
			copied = true
			return nil
		},
		listByTripFn: func(_ context.Context, _ string) ([]domain.ChecklistItem, error) {
			return []domain.ChecklistItem{{ID: "i1", Label: "Chalecos"}}, nil
		},
	}
	svc := NewRegattaService(tripRepo, &mockTripParticipantRepo{}, checklistRepo, activeMemberRepo(), nil)

	items, err := svc.GetChecklist(context.Background(), "user-1", "trip-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !copied {
		t.Error("expected default checklist items to be copied")
	}
	if len(items) != 1 {
		t.Errorf("expected 1 checklist item, got %d", len(items))
	}
}
