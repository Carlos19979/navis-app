package service

import (
	"context"
	"crypto/rand"
	"fmt"
	"math"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// TripService implements business logic for trip operations.
type TripService struct {
	tripRepo  port.TripRepository
	trackRepo port.TripTrackRepository
	boatRepo  port.BoatRepository
}

// NewTripService creates a new TripService.
func NewTripService(tripRepo port.TripRepository, trackRepo port.TripTrackRepository, boatRepo port.BoatRepository) *TripService {
	return &TripService{
		tripRepo:  tripRepo,
		trackRepo: trackRepo,
		boatRepo:  boatRepo,
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

	// Only users with the "record trips" permission may record on the boat.
	if trip.BoatID != "" {
		perms, ok, err := s.boatRepo.GetPermissions(ctx, trip.UserID, trip.BoatID)
		if err != nil {
			return nil, fmt.Errorf("creating trip: %w", err)
		}
		if !ok || !perms.CanRecordTrips {
			return nil, fmt.Errorf("creating trip: %w", domain.ErrForbidden)
		}
	}

	trip.Status = domain.TripStatusRecording

	created, err := s.tripRepo.Create(ctx, trip)
	if err != nil {
		return nil, fmt.Errorf("creating trip: %w", err)
	}
	return created, nil
}

// GetByID retrieves a single trip the user owns or has shared access to.
func (s *TripService) GetByID(ctx context.Context, userID, id string) (*domain.Trip, error) {
	trip, err := s.tripRepo.GetByIDUnscoped(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting trip %s: %w", id, err)
	}
	access, err := s.boatRepo.HasAccess(ctx, userID, trip.BoatID)
	if err != nil {
		return nil, fmt.Errorf("getting trip %s: %w", id, err)
	}
	if !access {
		return nil, fmt.Errorf("getting trip %s: %w", id, domain.ErrTripNotFound)
	}
	return trip, nil
}

// List returns a paginated list of trips. For a specific boat, members with
// shared access read the boat owner's trips (read-only).
func (s *TripService) List(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Trip, string, error) {
	limit = pagination.ClampLimit(limit)

	// For a specific boat, return the whole shared logbook (every member's
	// trips) after verifying access. Without a boat, return the user's own trips.
	if boatID != "" {
		if _, err := s.boatRepo.GetByIDAccessible(ctx, userID, boatID); err != nil {
			return nil, "", fmt.Errorf("listing trips: %w", err)
		}
		trips, nextCursor, err := s.tripRepo.ListByBoatAll(ctx, boatID, cursor, limit)
		if err != nil {
			return nil, "", fmt.Errorf("listing trips: %w", err)
		}
		return trips, nextCursor, nil
	}

	trips, nextCursor, err := s.tripRepo.List(ctx, userID, boatID, cursor, limit)
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

	for i := range len(tracks) - 1 {
		prev, cur := tracks[i], tracks[i+1]
		d := haversineNM(prev.Lat, prev.Lon, cur.Lat, cur.Lon)
		totalDist += d

		if cur.SpeedKnots != nil {
			spd := *cur.SpeedKnots
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

// GetTrackPoints returns all GPS track points for a trip the user owns or has
// shared access to.
func (s *TripService) GetTrackPoints(ctx context.Context, userID, tripID string) ([]domain.TripTrack, error) {
	trip, err := s.tripRepo.GetByIDUnscoped(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("getting track points for trip %s: %w", tripID, err)
	}
	access, err := s.boatRepo.HasAccess(ctx, userID, trip.BoatID)
	if err != nil {
		return nil, fmt.Errorf("getting track points for trip %s: %w", tripID, err)
	}
	if !access {
		return nil, fmt.Errorf("getting track points for trip %s: %w", tripID, domain.ErrTripNotFound)
	}

	points, err := s.trackRepo.ListByTrip(ctx, tripID)
	if err != nil {
		return nil, fmt.Errorf("getting track points for trip %s: %w", tripID, err)
	}
	return points, nil
}

// shareTokenAlphabet is URL-safe and avoids ambiguous characters.
const shareTokenAlphabet = "abcdefghijkmnpqrstuvwxyz23456789"

func generateShareToken() (string, error) {
	const n = 12
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generating share token: %w", err)
	}
	for i := range buf {
		buf[i] = shareTokenAlphabet[int(buf[i])%len(shareTokenAlphabet)]
	}
	return string(buf), nil
}

// Share makes a trip publicly accessible, returning its share token. If the
// trip is already shared, the existing token is reused (idempotent).
func (s *TripService) Share(ctx context.Context, userID, tripID string) (string, error) {
	trip, err := s.tripRepo.GetByID(ctx, userID, tripID)
	if err != nil {
		return "", fmt.Errorf("share trip: %w", err)
	}
	if trip.ShareToken != nil && *trip.ShareToken != "" {
		return *trip.ShareToken, nil
	}
	token, err := generateShareToken()
	if err != nil {
		return "", err
	}
	if err := s.tripRepo.SetShareToken(ctx, userID, tripID, token); err != nil {
		return "", fmt.Errorf("share trip: %w", err)
	}
	return token, nil
}

// Unshare revokes a trip's public share link.
func (s *TripService) Unshare(ctx context.Context, userID, tripID string) error {
	if err := s.tripRepo.ClearShareToken(ctx, userID, tripID); err != nil {
		return fmt.Errorf("unshare trip: %w", err)
	}
	return nil
}

// PublicByToken returns a shared trip and its track, by public token.
func (s *TripService) PublicByToken(ctx context.Context, token string) (*domain.Trip, []domain.TripTrack, error) {
	trip, err := s.tripRepo.GetByShareToken(ctx, token)
	if err != nil {
		return nil, nil, fmt.Errorf("public trip: %w", err)
	}
	track, err := s.trackRepo.ListByTrip(ctx, trip.ID)
	if err != nil {
		return nil, nil, fmt.Errorf("public trip track: %w", err)
	}
	return trip, track, nil
}
