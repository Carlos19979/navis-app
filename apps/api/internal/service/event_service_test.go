package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// --- mock EventRepository ---

type mockEventRepo struct {
	getByIDFn      func(ctx context.Context, id string) (*domain.Event, error)
	listFn         func(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error)
	listUpcomingFn func(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error)
	nearLocationFn func(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Event, string, error)
}

func (m *mockEventRepo) GetByID(ctx context.Context, id string) (*domain.Event, error) {
	return m.getByIDFn(ctx, id)
}

func (m *mockEventRepo) List(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error) {
	return m.listFn(ctx, cursor, limit)
}

func (m *mockEventRepo) ListUpcoming(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error) {
	return m.listUpcomingFn(ctx, cursor, limit)
}

func (m *mockEventRepo) NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Event, string, error) {
	return m.nearLocationFn(ctx, lat, lon, radiusKM, cursor, limit)
}

// --- mock EventInterestRepository ---

type mockEventInterestRepo struct {
	toggleFn       func(ctx context.Context, userID, eventID string) (bool, error)
	isInterestedFn func(ctx context.Context, userID, eventID string) (bool, error)
}

func (m *mockEventInterestRepo) Toggle(ctx context.Context, userID, eventID string) (bool, error) {
	return m.toggleFn(ctx, userID, eventID)
}

func (m *mockEventInterestRepo) IsInterested(ctx context.Context, userID, eventID string) (bool, error) {
	return m.isInterestedFn(ctx, userID, eventID)
}

// --- helpers ---

func newTestEvent() *domain.Event {
	lat := 39.4699
	lon := -0.3763
	return &domain.Event{
		ID:           "event-1",
		Name:         "Valencia Regatta 2026",
		Organizer:    "Club Nautico Valencia",
		EventType:    domain.EventTypeRegatta,
		LocationName: "Puerto de Valencia",
		Lat:          &lat,
		Lon:          &lon,
		StartDate:    time.Now().Add(30 * 24 * time.Hour),
		IsFeatured:   true,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
}

// --- GetByID tests ---

func TestEventService_GetByID_Success(t *testing.T) {
	t.Parallel()

	event := newTestEvent()
	eventRepo := &mockEventRepo{
		getByIDFn: func(_ context.Context, id string) (*domain.Event, error) {
			if id != "event-1" {
				return nil, domain.ErrEventNotFound
			}
			return event, nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	result, err := svc.GetByID(context.Background(), "event-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "event-1" {
		t.Errorf("expected event ID %q, got %q", "event-1", result.ID)
	}
	if result.Name != "Valencia Regatta 2026" {
		t.Errorf("expected name %q, got %q", "Valencia Regatta 2026", result.Name)
	}
}

func TestEventService_GetByID_NotFound(t *testing.T) {
	t.Parallel()

	eventRepo := &mockEventRepo{
		getByIDFn: func(_ context.Context, _ string) (*domain.Event, error) {
			return nil, domain.ErrEventNotFound
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	_, err := svc.GetByID(context.Background(), "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrEventNotFound) {
		t.Errorf("expected ErrEventNotFound, got %v", err)
	}
}

// --- List tests ---

func TestEventService_List_Success(t *testing.T) {
	t.Parallel()

	events := []domain.Event{*newTestEvent()}
	eventRepo := &mockEventRepo{
		listFn: func(_ context.Context, _ string, _ int) ([]domain.Event, string, error) {
			return events, "next-cursor", nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	result, cursor, err := svc.List(context.Background(), "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 event, got %d", len(result))
	}
	if cursor != "next-cursor" {
		t.Errorf("expected cursor %q, got %q", "next-cursor", cursor)
	}
}

func TestEventService_List_DefaultLimit(t *testing.T) {
	t.Parallel()

	var capturedLimit int
	eventRepo := &mockEventRepo{
		listFn: func(_ context.Context, _ string, limit int) ([]domain.Event, string, error) {
			capturedLimit = limit
			return []domain.Event{}, "", nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	tests := []struct {
		name          string
		inputLimit    int
		expectedLimit int
	}{
		{"zero limit defaults to 20", 0, 20},
		{"negative limit defaults to 20", -1, 20},
		{"over 50 defaults to 20", 51, 20},
		{"valid limit preserved", 25, 25},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, _ = svc.List(context.Background(), "", tt.inputLimit)
			if capturedLimit != tt.expectedLimit {
				t.Errorf("expected limit %d, got %d", tt.expectedLimit, capturedLimit)
			}
		})
	}
}

func TestEventService_List_RepoError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("database error")
	eventRepo := &mockEventRepo{
		listFn: func(_ context.Context, _ string, _ int) ([]domain.Event, string, error) {
			return nil, "", repoErr
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	_, _, err := svc.List(context.Background(), "", 10)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- ListUpcoming tests ---

func TestEventService_ListUpcoming_Success(t *testing.T) {
	t.Parallel()

	events := []domain.Event{*newTestEvent()}
	eventRepo := &mockEventRepo{
		listUpcomingFn: func(_ context.Context, _ string, _ int) ([]domain.Event, string, error) {
			return events, "", nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	result, cursor, err := svc.ListUpcoming(context.Background(), "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 event, got %d", len(result))
	}
	if cursor != "" {
		t.Errorf("expected empty cursor, got %q", cursor)
	}
}

func TestEventService_ListUpcoming_DefaultLimit(t *testing.T) {
	t.Parallel()

	var capturedLimit int
	eventRepo := &mockEventRepo{
		listUpcomingFn: func(_ context.Context, _ string, limit int) ([]domain.Event, string, error) {
			capturedLimit = limit
			return []domain.Event{}, "", nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	_, _, _ = svc.ListUpcoming(context.Background(), "", 0)
	if capturedLimit != 20 {
		t.Errorf("expected default limit 20, got %d", capturedLimit)
	}
}

// --- NearLocation tests ---

func TestEventService_NearLocation_Success(t *testing.T) {
	t.Parallel()

	events := []domain.Event{*newTestEvent()}
	eventRepo := &mockEventRepo{
		nearLocationFn: func(_ context.Context, lat, lon, radiusKM float64, _ string, _ int) ([]domain.Event, string, error) {
			if lat != 39.47 || lon != -0.38 {
				t.Errorf("unexpected coordinates: %.2f, %.2f", lat, lon)
			}
			if radiusKM != 25.0 {
				t.Errorf("expected radius 25.0, got %.1f", radiusKM)
			}
			return events, "", nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	result, _, err := svc.NearLocation(context.Background(), 39.47, -0.38, 25.0, "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 event, got %d", len(result))
	}
}

func TestEventService_NearLocation_DefaultRadius(t *testing.T) {
	t.Parallel()

	var capturedRadius float64
	eventRepo := &mockEventRepo{
		nearLocationFn: func(_ context.Context, _, _, radiusKM float64, _ string, _ int) ([]domain.Event, string, error) {
			capturedRadius = radiusKM
			return []domain.Event{}, "", nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	tests := []struct {
		name           string
		inputRadius    float64
		expectedRadius float64
	}{
		{"zero radius defaults to 50", 0, 50},
		{"negative radius defaults to 50", -10, 50},
		{"valid radius preserved", 25, 25},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, _ = svc.NearLocation(context.Background(), 39.47, -0.38, tt.inputRadius, "", 10)
			if capturedRadius != tt.expectedRadius {
				t.Errorf("expected radius %.1f, got %.1f", tt.expectedRadius, capturedRadius)
			}
		})
	}
}

func TestEventService_NearLocation_DefaultLimit(t *testing.T) {
	t.Parallel()

	var capturedLimit int
	eventRepo := &mockEventRepo{
		nearLocationFn: func(_ context.Context, _, _, _ float64, _ string, limit int) ([]domain.Event, string, error) {
			capturedLimit = limit
			return []domain.Event{}, "", nil
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	_, _, _ = svc.NearLocation(context.Background(), 39.47, -0.38, 25, "", 0)
	if capturedLimit != 20 {
		t.Errorf("expected default limit 20, got %d", capturedLimit)
	}
}

// --- ToggleInterest tests ---

func TestEventService_ToggleInterest_AddInterest(t *testing.T) {
	t.Parallel()

	eventRepo := &mockEventRepo{
		getByIDFn: func(_ context.Context, _ string) (*domain.Event, error) {
			return newTestEvent(), nil
		},
	}
	interestRepo := &mockEventInterestRepo{
		toggleFn: func(_ context.Context, _, _ string) (bool, error) {
			return true, nil // Interest added
		},
	}
	svc := NewEventService(eventRepo, interestRepo)

	interested, err := svc.ToggleInterest(context.Background(), "user-1", "event-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !interested {
		t.Error("expected interested to be true")
	}
}

func TestEventService_ToggleInterest_RemoveInterest(t *testing.T) {
	t.Parallel()

	eventRepo := &mockEventRepo{
		getByIDFn: func(_ context.Context, _ string) (*domain.Event, error) {
			return newTestEvent(), nil
		},
	}
	interestRepo := &mockEventInterestRepo{
		toggleFn: func(_ context.Context, _, _ string) (bool, error) {
			return false, nil // Interest removed
		},
	}
	svc := NewEventService(eventRepo, interestRepo)

	interested, err := svc.ToggleInterest(context.Background(), "user-1", "event-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if interested {
		t.Error("expected interested to be false")
	}
}

func TestEventService_ToggleInterest_EventNotFound(t *testing.T) {
	t.Parallel()

	eventRepo := &mockEventRepo{
		getByIDFn: func(_ context.Context, _ string) (*domain.Event, error) {
			return nil, domain.ErrEventNotFound
		},
	}
	interestRepo := &mockEventInterestRepo{}
	svc := NewEventService(eventRepo, interestRepo)

	_, err := svc.ToggleInterest(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrEventNotFound) {
		t.Errorf("expected ErrEventNotFound, got %v", err)
	}
}

func TestEventService_ToggleInterest_RepoError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("toggle failed")
	eventRepo := &mockEventRepo{
		getByIDFn: func(_ context.Context, _ string) (*domain.Event, error) {
			return newTestEvent(), nil
		},
	}
	interestRepo := &mockEventInterestRepo{
		toggleFn: func(_ context.Context, _, _ string) (bool, error) {
			return false, repoErr
		},
	}
	svc := NewEventService(eventRepo, interestRepo)

	_, err := svc.ToggleInterest(context.Background(), "user-1", "event-1")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- IsInterested tests ---

func TestEventService_IsInterested_True(t *testing.T) {
	t.Parallel()

	eventRepo := &mockEventRepo{}
	interestRepo := &mockEventInterestRepo{
		isInterestedFn: func(_ context.Context, _, _ string) (bool, error) {
			return true, nil
		},
	}
	svc := NewEventService(eventRepo, interestRepo)

	result, err := svc.IsInterested(context.Background(), "user-1", "event-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !result {
		t.Error("expected interested to be true")
	}
}

func TestEventService_IsInterested_False(t *testing.T) {
	t.Parallel()

	eventRepo := &mockEventRepo{}
	interestRepo := &mockEventInterestRepo{
		isInterestedFn: func(_ context.Context, _, _ string) (bool, error) {
			return false, nil
		},
	}
	svc := NewEventService(eventRepo, interestRepo)

	result, err := svc.IsInterested(context.Background(), "user-1", "event-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result {
		t.Error("expected interested to be false")
	}
}

func TestEventService_IsInterested_RepoError(t *testing.T) {
	t.Parallel()

	repoErr := errors.New("query failed")
	eventRepo := &mockEventRepo{}
	interestRepo := &mockEventInterestRepo{
		isInterestedFn: func(_ context.Context, _, _ string) (bool, error) {
			return false, repoErr
		},
	}
	svc := NewEventService(eventRepo, interestRepo)

	_, err := svc.IsInterested(context.Background(), "user-1", "event-1")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

func (m *mockEventRepo) ListStartingBetween(_ context.Context, _, _ time.Time) ([]domain.Event, error) {
	return nil, nil
}

func (m *mockEventInterestRepo) ListInterestedUsers(_ context.Context, _ string) ([]string, error) {
	return nil, nil
}

func (m *mockEventInterestRepo) InterestedIn(_ context.Context, _ string, _ []string) (map[string]bool, error) {
	return map[string]bool{}, nil
}
