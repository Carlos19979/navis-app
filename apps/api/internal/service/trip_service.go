package service

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// TripService implements business logic for trip operations.
type TripService struct {
	tripRepo  port.TripRepository
	trackRepo port.TripTrackRepository
}

// NewTripService creates a new TripService.
func NewTripService(tripRepo port.TripRepository, trackRepo port.TripTrackRepository) *TripService {
	return &TripService{
		tripRepo:  tripRepo,
		trackRepo: trackRepo,
	}
}

// Create persists a new trip in recording status.
func (s *TripService) Create(ctx context.Context, trip *domain.Trip) (*domain.Trip, error) {
	if trip.UserID == "" {
		return nil, fmt.Errorf("creating trip: %w", domain.ErrUnauthorized)
	}
	if trip.DeparturePort == "" {
		return nil, &domain.ValidationError{Field: "departure_port", Message: "departure port is required"}
	}

	trip.Status = domain.TripStatusRecording

	created, err := s.tripRepo.Create(ctx, trip)
	if err != nil {
		return nil, fmt.Errorf("creating trip: %w", err)
	}
	return created, nil
}

// GetByID retrieves a single trip owned by the given user.
func (s *TripService) GetByID(ctx context.Context, userID, id string) (*domain.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, userID, id)
	if err != nil {
		return nil, fmt.Errorf("getting trip %s: %w", id, err)
	}
	return trip, nil
}

// List returns a paginated list of trips for a user.
func (s *TripService) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Trip, string, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	trips, nextCursor, err := s.tripRepo.List(ctx, userID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing trips: %w", err)
	}
	return trips, nextCursor, nil
}

// Update modifies an existing trip that is still recording.
func (s *TripService) Update(ctx context.Context, userID string, trip *domain.Trip) (*domain.Trip, error) {
	if trip.ID == "" {
		return nil, &domain.ValidationError{Field: "id", Message: "id is required"}
	}

	existing, err := s.tripRepo.GetByID(ctx, userID, trip.ID)
	if err != nil {
		return nil, fmt.Errorf("updating trip %s: %w", trip.ID, err)
	}
	if existing.Status == domain.TripStatusCompleted {
		return nil, fmt.Errorf("updating trip %s: %w: trip is already completed", trip.ID, domain.ErrConflict)
	}

	updated, err := s.tripRepo.Update(ctx, userID, trip)
	if err != nil {
		return nil, fmt.Errorf("updating trip %s: %w", trip.ID, err)
	}
	return updated, nil
}

// Complete marks a trip as completed, calculates duration and stats from
// track points, and records the arrival time.
func (s *TripService) Complete(ctx context.Context, userID, id string, arrivalPort *string, distanceNM, engineHours, fuelConsumedL *float64) (*domain.Trip, error) {
	trip, err := s.tripRepo.GetByID(ctx, userID, id)
	if err != nil {
		return nil, fmt.Errorf("completing trip %s: %w", id, err)
	}
	if trip.Status == domain.TripStatusCompleted {
		return nil, fmt.Errorf("completing trip %s: %w: already completed", id, domain.ErrConflict)
	}

	now := time.Now().UTC()
	trip.ArrivalTime = &now
	trip.Status = domain.TripStatusCompleted

	if arrivalPort != nil {
		trip.ArrivalPort = arrivalPort
	}
	if engineHours != nil {
		trip.EngineHours = engineHours
	}
	if fuelConsumedL != nil {
		trip.FuelConsumedL = fuelConsumedL
	}

	durationMin := int(now.Sub(trip.DepartureTime).Minutes())
	trip.DurationMinutes = &durationMin

	// Compute distance and speed stats from track points.
	tracks, _ := s.trackRepo.ListByTrip(ctx, id)
	if len(tracks) >= 2 {
		dist, maxSpd, avgSpd := computeTrackStats(tracks)
		trip.DistanceNM = &dist
		trip.MaxSpeedKnots = &maxSpd
		trip.AvgSpeedKnots = &avgSpd
	} else if distanceNM != nil {
		trip.DistanceNM = distanceNM
	}

	updated, err := s.tripRepo.Update(ctx, userID, trip)
	if err != nil {
		return nil, fmt.Errorf("completing trip %s: %w", id, err)
	}
	return updated, nil
}

// computeTrackStats calculates total distance (NM), max speed, and average
// speed from an ordered list of track points using the haversine formula.
func computeTrackStats(tracks []domain.TripTrack) (distNM, maxSpeed, avgSpeed float64) {
	var totalDist float64
	var maxSpd float64
	var speedSum float64
	var speedCount int

	for i := 1; i < len(tracks); i++ {
		d := haversineNM(tracks[i-1].Lat, tracks[i-1].Lon, tracks[i].Lat, tracks[i].Lon)
		totalDist += d

		if tracks[i].SpeedKnots != nil {
			spd := *tracks[i].SpeedKnots
			speedSum += spd
			speedCount++
			if spd > maxSpd {
				maxSpd = spd
			}
		}
	}

	if speedCount > 0 {
		avgSpeed = speedSum / float64(speedCount)
	}
	return totalDist, maxSpd, avgSpeed
}

func haversineNM(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusNM = 3440.065
	dLat := (lat2 - lat1) * math.Pi / 180
	dLon := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusNM * c
}

// Delete removes a trip if owned by the user.
func (s *TripService) Delete(ctx context.Context, userID, id string) error {
	if err := s.tripRepo.Delete(ctx, userID, id); err != nil {
		return fmt.Errorf("deleting trip %s: %w", id, err)
	}
	return nil
}

// AddTrackPoints persists a batch of GPS track points for a trip.
func (s *TripService) AddTrackPoints(ctx context.Context, userID string, tracks []domain.TripTrack) error {
	if len(tracks) == 0 {
		return nil
	}

	// Verify trip ownership via the first track's trip ID.
	tripID := tracks[0].TripID
	if _, err := s.tripRepo.GetByID(ctx, userID, tripID); err != nil {
		return fmt.Errorf("adding track points to trip %s: %w", tripID, err)
	}

	if err := s.trackRepo.BatchCreate(ctx, tracks); err != nil {
		return fmt.Errorf("adding track points to trip %s: %w", tripID, err)
	}
	return nil
}

// GetTrackPoints returns all GPS track points for a trip.
func (s *TripService) GetTrackPoints(ctx context.Context, userID, tripID string) ([]domain.TripTrack, error) {
	// Verify trip ownership.
	if _, err := s.tripRepo.GetByID(ctx, userID, tripID); err != nil {
		return nil, fmt.Errorf("getting track points for trip %s: %w", tripID, err)
	}

	points, err := s.trackRepo.ListByTrip(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("getting track points for trip %s: %w", tripID, err)
	}
	return points, nil
}
