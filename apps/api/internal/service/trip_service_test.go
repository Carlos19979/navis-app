package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// --- mock TripRepository ---

type mockTripRepo struct {
	createFn          func(ctx context.Context, trip *domain.Trip) (*domain.Trip, error)
	getByIDFn         func(ctx context.Context, userID, id string) (*domain.Trip, error)
	getByIDUnscopedFn func(ctx context.Context, id string) (*domain.Trip, error)
	listFn            func(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Trip, string, error)
	listByGroupFn     func(ctx context.Context, groupID, cursor string, limit int) ([]domain.Trip, string, error)
	updateFn          func(ctx context.Context, userID string, trip *domain.Trip) (*domain.Trip, error)
	deleteFn          func(ctx context.Context, userID, id string) error
}

func (m *mockTripRepo) Create(ctx context.Context, trip *domain.Trip) (*domain.Trip, error) {
	return m.createFn(ctx, trip)
}

func (m *mockTripRepo) GetByID(ctx context.Context, userID, id string) (*domain.Trip, error) {
	return m.getByIDFn(ctx, userID, id)
}

func (m *mockTripRepo) GetByIDUnscoped(ctx context.Context, id string) (*domain.Trip, error) {
	return m.getByIDUnscopedFn(ctx, id)
}

func (m *mockTripRepo) ListByGroup(ctx context.Context, groupID, cursor string, limit int) ([]domain.Trip, string, error) {
	return m.listByGroupFn(ctx, groupID, cursor, limit)
}

func (m *mockTripRepo) List(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Trip, string, error) {
	return m.listFn(ctx, userID, boatID, cursor, limit)
}

func (m *mockTripRepo) Update(ctx context.Context, userID string, trip *domain.Trip) (*domain.Trip, error) {
	return m.updateFn(ctx, userID, trip)
}

func (m *mockTripRepo) Delete(ctx context.Context, userID, id string) error {
	return m.deleteFn(ctx, userID, id)
}

// --- mock TripTrackRepository ---

type mockTripTrackRepo struct {
	batchCreateFn func(ctx context.Context, tracks []domain.TripTrack) error
	listByTripFn  func(ctx context.Context, tripID string) ([]domain.TripTrack, error)
}

func (m *mockTripTrackRepo) BatchCreate(ctx context.Context, tracks []domain.TripTrack) error {
	return m.batchCreateFn(ctx, tracks)
}

func (m *mockTripTrackRepo) ListByTrip(ctx context.Context, tripID string) ([]domain.TripTrack, error) {
	return m.listByTripFn(ctx, tripID)
}

// --- helpers ---

func newTestTrip() *domain.Trip {
	return &domain.Trip{
		ID:            "trip-1",
		BoatID:        "boat-1",
		UserID:        "user-1",
		DeparturePort: "Valencia",
		DepartureTime: time.Now().Add(-2 * time.Hour),
		Status:        domain.TripStatusRecording,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}
}

// --- Create tests ---

func TestTripService_Create_Success(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	tripRepo := &mockTripRepo{
		createFn: func(_ context.Context, tr *domain.Trip) (*domain.Trip, error) {
			tr.ID = "trip-1"
			return tr, nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	result, err := svc.Create(context.Background(), trip)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "trip-1" {
		t.Errorf("expected trip ID %q, got %q", "trip-1", result.ID)
	}
	if result.Status != domain.TripStatusRecording {
		t.Errorf("expected status %q, got %q", domain.TripStatusRecording, result.Status)
	}
}

func TestTripService_Create_EmptyUserID(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	trip.UserID = ""
	tripRepo := &mockTripRepo{}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Create(context.Background(), trip)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrUnauthorized) {
		t.Errorf("expected ErrUnauthorized, got %v", err)
	}
}

func TestTripService_Create_EmptyDeparturePort(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	trip.DeparturePort = ""
	tripRepo := &mockTripRepo{}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Create(context.Background(), trip)
	if err == nil {
		t.Fatal("expected error, got nil")
	}

	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
	if ve.Field != "departure_port" {
		t.Errorf("expected field %q, got %q", "departure_port", ve.Field)
	}
}

func TestTripService_Create_SetsStatusToRecording(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	trip.Status = domain.TripStatusCompleted // Should be overridden.

	var capturedStatus domain.TripStatus
	tripRepo := &mockTripRepo{
		createFn: func(_ context.Context, tr *domain.Trip) (*domain.Trip, error) {
			capturedStatus = tr.Status
			return tr, nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Create(context.Background(), trip)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if capturedStatus != domain.TripStatusRecording {
		t.Errorf("expected status forced to %q, got %q", domain.TripStatusRecording, capturedStatus)
	}
}

func TestTripService_Create_RepoError(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	repoErr := errors.New("connection lost")
	tripRepo := &mockTripRepo{
		createFn: func(_ context.Context, _ *domain.Trip) (*domain.Trip, error) {
			return nil, repoErr
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Create(context.Background(), trip)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- GetByID tests ---

func TestTripService_GetByID_Success(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return trip, nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	result, err := svc.GetByID(context.Background(), "user-1", "trip-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.ID != "trip-1" {
		t.Errorf("expected trip ID %q, got %q", "trip-1", result.ID)
	}
}

func TestTripService_GetByID_NotFound(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return nil, domain.ErrTripNotFound
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.GetByID(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrTripNotFound) {
		t.Errorf("expected ErrTripNotFound, got %v", err)
	}
}

// --- List tests ---

func TestTripService_List_Success(t *testing.T) {
	t.Parallel()

	trips := []domain.Trip{*newTestTrip()}
	tripRepo := &mockTripRepo{
		listFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Trip, string, error) {
			return trips, "next-cursor", nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	result, cursor, err := svc.List(context.Background(), "user-1", "", "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 trip, got %d", len(result))
	}
	if cursor != "next-cursor" {
		t.Errorf("expected cursor %q, got %q", "next-cursor", cursor)
	}
}

func TestTripService_List_WithBoatIDFilter(t *testing.T) {
	t.Parallel()

	var capturedBoatID string
	tripRepo := &mockTripRepo{
		listFn: func(_ context.Context, _, boatID, _ string, _ int) ([]domain.Trip, string, error) {
			capturedBoatID = boatID
			return []domain.Trip{}, "", nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, _, err := svc.List(context.Background(), "user-1", "boat-42", "", 10)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if capturedBoatID != "boat-42" {
		t.Errorf("expected boatID %q, got %q", "boat-42", capturedBoatID)
	}
}

func TestTripService_List_DefaultLimit(t *testing.T) {
	t.Parallel()

	var capturedLimit int
	tripRepo := &mockTripRepo{
		listFn: func(_ context.Context, _, _, _ string, limit int) ([]domain.Trip, string, error) {
			capturedLimit = limit
			return []domain.Trip{}, "", nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	tests := []struct {
		name          string
		inputLimit    int
		expectedLimit int
	}{
		{"zero limit defaults to 20", 0, 20},
		{"negative limit defaults to 20", -1, 20},
		{"over 50 defaults to 20", 100, 20},
		{"valid limit preserved", 30, 30},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, _ = svc.List(context.Background(), "user-1", "", "", tt.inputLimit)
			if capturedLimit != tt.expectedLimit {
				t.Errorf("expected limit %d, got %d", tt.expectedLimit, capturedLimit)
			}
		})
	}
}

// --- Update tests ---

func TestTripService_Update_Success(t *testing.T) {
	t.Parallel()

	existingTrip := newTestTrip()
	updatedTrip := newTestTrip()
	updatedTrip.DeparturePort = "Barcelona"

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return existingTrip, nil
		},
		updateFn: func(_ context.Context, _ string, tr *domain.Trip) (*domain.Trip, error) {
			return tr, nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	result, err := svc.Update(context.Background(), "user-1", updatedTrip)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.DeparturePort != "Barcelona" {
		t.Errorf("expected departure port %q, got %q", "Barcelona", result.DeparturePort)
	}
}

func TestTripService_Update_EmptyID(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	trip.ID = ""
	tripRepo := &mockTripRepo{}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Update(context.Background(), "user-1", trip)
	if err == nil {
		t.Fatal("expected error, got nil")
	}

	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
}

func TestTripService_Update_NotFound(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return nil, domain.ErrTripNotFound
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Update(context.Background(), "user-1", trip)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrTripNotFound) {
		t.Errorf("expected ErrTripNotFound, got %v", err)
	}
}

func TestTripService_Update_BlocksCompletedTrip(t *testing.T) {
	t.Parallel()

	completedTrip := newTestTrip()
	completedTrip.Status = domain.TripStatusCompleted

	trip := newTestTrip()
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return completedTrip, nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Update(context.Background(), "user-1", trip)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrConflict) {
		t.Errorf("expected ErrConflict, got %v", err)
	}
}

// --- Complete tests ---

func TestTripService_Complete_Success(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return trip, nil
		},
		updateFn: func(_ context.Context, _ string, tr *domain.Trip) (*domain.Trip, error) {
			return tr, nil
		},
	}
	trackRepo := &mockTripTrackRepo{
		listByTripFn: func(_ context.Context, _ string) ([]domain.TripTrack, error) {
			return []domain.TripTrack{}, nil // No tracks
		},
	}
	svc := NewTripService(tripRepo, trackRepo)

	arrivalPort := "Ibiza"
	distNM := 120.5
	result, err := svc.Complete(context.Background(), "user-1", "trip-1", &arrivalPort, &distNM, nil, nil)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.Status != domain.TripStatusCompleted {
		t.Errorf("expected status %q, got %q", domain.TripStatusCompleted, result.Status)
	}
	if result.ArrivalTime == nil {
		t.Error("expected arrival time to be set")
	}
	if result.ArrivalPort == nil || *result.ArrivalPort != "Ibiza" {
		t.Errorf("expected arrival port %q, got %v", "Ibiza", result.ArrivalPort)
	}
	if result.DurationMinutes == nil {
		t.Error("expected duration to be calculated")
	}
	// With <2 track points and distanceNM provided, DistanceNM should be set.
	if result.DistanceNM == nil || *result.DistanceNM != 120.5 {
		t.Errorf("expected distance 120.5, got %v", result.DistanceNM)
	}
}

func TestTripService_Complete_WithTrackPoints(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return trip, nil
		},
		updateFn: func(_ context.Context, _ string, tr *domain.Trip) (*domain.Trip, error) {
			return tr, nil
		},
	}

	spd1 := 5.0
	spd2 := 10.0
	tracks := []domain.TripTrack{
		{ID: "t1", TripID: "trip-1", Lat: 39.4699, Lon: -0.3763, SpeedKnots: &spd1, RecordedAt: time.Now().Add(-1 * time.Hour)},
		{ID: "t2", TripID: "trip-1", Lat: 39.5699, Lon: -0.2763, SpeedKnots: &spd2, RecordedAt: time.Now()},
	}
	trackRepo := &mockTripTrackRepo{
		listByTripFn: func(_ context.Context, _ string) ([]domain.TripTrack, error) {
			return tracks, nil
		},
	}
	svc := NewTripService(tripRepo, trackRepo)

	result, err := svc.Complete(context.Background(), "user-1", "trip-1", nil, nil, nil, nil)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	// With 2+ track points, distance/speed should be computed from tracks.
	if result.DistanceNM == nil {
		t.Error("expected distance to be computed from tracks")
	}
	if result.MaxSpeedKnots == nil || *result.MaxSpeedKnots != 10.0 {
		t.Errorf("expected max speed 10.0, got %v", result.MaxSpeedKnots)
	}
	// computeTrackStats only considers tracks[i] for i>=1, so only
	// the second point's speed (10.0) contributes to the average.
	if result.AvgSpeedKnots == nil || *result.AvgSpeedKnots != 10.0 {
		t.Errorf("expected avg speed 10.0, got %f", *result.AvgSpeedKnots)
	}
}

func TestTripService_Complete_SetsOptionalFields(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return trip, nil
		},
		updateFn: func(_ context.Context, _ string, tr *domain.Trip) (*domain.Trip, error) {
			return tr, nil
		},
	}
	trackRepo := &mockTripTrackRepo{
		listByTripFn: func(_ context.Context, _ string) ([]domain.TripTrack, error) {
			return nil, nil
		},
	}
	svc := NewTripService(tripRepo, trackRepo)

	engineHrs := 3.5
	fuelL := 45.0
	result, err := svc.Complete(context.Background(), "user-1", "trip-1", nil, nil, &engineHrs, &fuelL)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.EngineHours == nil || *result.EngineHours != 3.5 {
		t.Errorf("expected engine hours 3.5, got %v", result.EngineHours)
	}
	if result.FuelConsumedL == nil || *result.FuelConsumedL != 45.0 {
		t.Errorf("expected fuel consumed 45.0, got %v", result.FuelConsumedL)
	}
}

func TestTripService_Complete_NotFound(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return nil, domain.ErrTripNotFound
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Complete(context.Background(), "user-1", "nonexistent", nil, nil, nil, nil)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrTripNotFound) {
		t.Errorf("expected ErrTripNotFound, got %v", err)
	}
}

func TestTripService_Complete_AlreadyCompleted(t *testing.T) {
	t.Parallel()

	completedTrip := newTestTrip()
	completedTrip.Status = domain.TripStatusCompleted

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return completedTrip, nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.Complete(context.Background(), "user-1", "trip-1", nil, nil, nil, nil)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrConflict) {
		t.Errorf("expected ErrConflict, got %v", err)
	}
}

func TestTripService_Complete_CalculatesDuration(t *testing.T) {
	t.Parallel()

	trip := newTestTrip()
	trip.DepartureTime = time.Now().Add(-90 * time.Minute)

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return trip, nil
		},
		updateFn: func(_ context.Context, _ string, tr *domain.Trip) (*domain.Trip, error) {
			return tr, nil
		},
	}
	trackRepo := &mockTripTrackRepo{
		listByTripFn: func(_ context.Context, _ string) ([]domain.TripTrack, error) {
			return nil, nil
		},
	}
	svc := NewTripService(tripRepo, trackRepo)

	result, err := svc.Complete(context.Background(), "user-1", "trip-1", nil, nil, nil, nil)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.DurationMinutes == nil {
		t.Fatal("expected duration to be set")
	}
	// Duration should be approximately 90 minutes (allow some tolerance).
	if *result.DurationMinutes < 89 || *result.DurationMinutes > 91 {
		t.Errorf("expected duration ~90 minutes, got %d", *result.DurationMinutes)
	}
}

// --- Delete tests ---

func TestTripService_Delete_Success(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return nil
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	err := svc.Delete(context.Background(), "user-1", "trip-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestTripService_Delete_NotFound(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{
		deleteFn: func(_ context.Context, _, _ string) error {
			return domain.ErrTripNotFound
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	err := svc.Delete(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrTripNotFound) {
		t.Errorf("expected ErrTripNotFound, got %v", err)
	}
}

// --- AddTrackPoints tests ---

func TestTripService_AddTrackPoints_Success(t *testing.T) {
	t.Parallel()

	tracks := []domain.TripTrack{
		{TripID: "trip-1", Lat: 39.47, Lon: -0.37, RecordedAt: time.Now()},
		{TripID: "trip-1", Lat: 39.48, Lon: -0.36, RecordedAt: time.Now()},
	}
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return newTestTrip(), nil
		},
	}
	trackRepo := &mockTripTrackRepo{
		batchCreateFn: func(_ context.Context, _ []domain.TripTrack) error {
			return nil
		},
	}
	svc := NewTripService(tripRepo, trackRepo)

	err := svc.AddTrackPoints(context.Background(), "user-1", tracks)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestTripService_AddTrackPoints_EmptySlice(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	err := svc.AddTrackPoints(context.Background(), "user-1", []domain.TripTrack{})
	if err != nil {
		t.Fatalf("expected no error for empty tracks, got %v", err)
	}
}

func TestTripService_AddTrackPoints_TripNotFound(t *testing.T) {
	t.Parallel()

	tracks := []domain.TripTrack{
		{TripID: "nonexistent", Lat: 39.47, Lon: -0.37, RecordedAt: time.Now()},
	}
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return nil, domain.ErrTripNotFound
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	err := svc.AddTrackPoints(context.Background(), "user-1", tracks)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrTripNotFound) {
		t.Errorf("expected ErrTripNotFound, got %v", err)
	}
}

func TestTripService_AddTrackPoints_BatchCreateError(t *testing.T) {
	t.Parallel()

	tracks := []domain.TripTrack{
		{TripID: "trip-1", Lat: 39.47, Lon: -0.37, RecordedAt: time.Now()},
	}
	repoErr := errors.New("batch insert failed")
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return newTestTrip(), nil
		},
	}
	trackRepo := &mockTripTrackRepo{
		batchCreateFn: func(_ context.Context, _ []domain.TripTrack) error {
			return repoErr
		},
	}
	svc := NewTripService(tripRepo, trackRepo)

	err := svc.AddTrackPoints(context.Background(), "user-1", tracks)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, repoErr) {
		t.Errorf("expected underlying error %v, got %v", repoErr, err)
	}
}

// --- GetTrackPoints tests ---

func TestTripService_GetTrackPoints_Success(t *testing.T) {
	t.Parallel()

	tracks := []domain.TripTrack{
		{ID: "t1", TripID: "trip-1", Lat: 39.47, Lon: -0.37},
	}
	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return newTestTrip(), nil
		},
	}
	trackRepo := &mockTripTrackRepo{
		listByTripFn: func(_ context.Context, _ string) ([]domain.TripTrack, error) {
			return tracks, nil
		},
	}
	svc := NewTripService(tripRepo, trackRepo)

	result, err := svc.GetTrackPoints(context.Background(), "user-1", "trip-1")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 1 {
		t.Errorf("expected 1 track point, got %d", len(result))
	}
}

func TestTripService_GetTrackPoints_TripNotFound(t *testing.T) {
	t.Parallel()

	tripRepo := &mockTripRepo{
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Trip, error) {
			return nil, domain.ErrTripNotFound
		},
	}
	trackRepo := &mockTripTrackRepo{}
	svc := NewTripService(tripRepo, trackRepo)

	_, err := svc.GetTrackPoints(context.Background(), "user-1", "nonexistent")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, domain.ErrTripNotFound) {
		t.Errorf("expected ErrTripNotFound, got %v", err)
	}
}

// --- computeTrackStats tests ---

func TestComputeTrackStats_TwoPoints(t *testing.T) {
	t.Parallel()

	spd1 := 5.0
	spd2 := 15.0
	spd3 := 10.0
	tracks := []domain.TripTrack{
		{Lat: 39.4699, Lon: -0.3763, SpeedKnots: &spd1},
		{Lat: 39.5699, Lon: -0.2763, SpeedKnots: &spd2},
		{Lat: 39.6699, Lon: -0.1763, SpeedKnots: &spd3},
	}

	dist, maxSpd, avgSpd := computeTrackStats(tracks)
	if dist <= 0 {
		t.Errorf("expected positive distance, got %f", dist)
	}
	// Only tracks[1] and tracks[2] speeds are considered (loop starts at i=1).
	if maxSpd != 15.0 {
		t.Errorf("expected max speed 15.0, got %f", maxSpd)
	}
	// avg = (15.0 + 10.0) / 2 = 12.5
	if avgSpd != 12.5 {
		t.Errorf("expected avg speed 12.5, got %f", avgSpd)
	}
}

func TestComputeTrackStats_NoSpeedData(t *testing.T) {
	t.Parallel()

	tracks := []domain.TripTrack{
		{Lat: 39.0, Lon: -0.3},
		{Lat: 39.1, Lon: -0.2},
	}

	dist, maxSpd, avgSpd := computeTrackStats(tracks)
	if dist <= 0 {
		t.Errorf("expected positive distance, got %f", dist)
	}
	if maxSpd != 0 {
		t.Errorf("expected max speed 0 with no speed data, got %f", maxSpd)
	}
	if avgSpd != 0 {
		t.Errorf("expected avg speed 0 with no speed data, got %f", avgSpd)
	}
}

func TestComputeTrackStats_SinglePoint(t *testing.T) {
	t.Parallel()

	tracks := []domain.TripTrack{
		{Lat: 39.0, Lon: -0.3},
	}

	dist, maxSpd, avgSpd := computeTrackStats(tracks)
	if dist != 0 {
		t.Errorf("expected zero distance for single point, got %f", dist)
	}
	if maxSpd != 0 || avgSpd != 0 {
		t.Errorf("expected zero speeds for single point, got max=%f avg=%f", maxSpd, avgSpd)
	}
}
