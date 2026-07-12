package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

const (
	// Minimum completed trips with fuel data before a baseline is meaningful.
	anomalyMinSample = 3
	// A trip flags when its fuel/NM exceeds the baseline by this fraction.
	anomalyThreshold = 0.30
	// Ignore very short hops where ratios are noisy.
	anomalyMinDistanceNM = 1.0
)

// AnomalyService detects trips whose fuel efficiency deviates from a boat's
// historical baseline. Pro only.
type AnomalyService struct {
	trips    port.TripRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
}

// NewAnomalyService creates a new AnomalyService.
func NewAnomalyService(trips port.TripRepository, boats port.BoatRepository, profiles port.ProfileRepository) *AnomalyService {
	return &AnomalyService{trips: trips, boats: boats, profiles: profiles}
}

// ForBoat returns fuel-efficiency anomalies across the boat's completed trips.
func (s *AnomalyService) ForBoat(ctx context.Context, userID, boatID string) ([]domain.Anomaly, error) {
	if _, err := s.boats.GetByIDAccessible(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("anomalies: %w", err)
	}
	if s.profiles != nil {
		profile, err := s.profiles.GetOrCreate(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("anomalies: %w", err)
		}
		if !profile.Plan.CanUseAnomalyAlerts() {
			return nil, fmt.Errorf("anomalies: %w", domain.ErrPlanForbidden)
		}
	}

	trips, err := s.allTrips(ctx, boatID)
	if err != nil {
		return nil, fmt.Errorf("anomalies: %w", err)
	}

	// Baseline: aggregate fuel per NM across all qualifying completed trips.
	var totalFuel, totalDist float64
	var sample int
	for _, t := range trips {
		if !qualifies(t) {
			continue
		}
		totalFuel += *t.FuelConsumedL
		totalDist += *t.DistanceNM
		sample++
	}
	if sample < anomalyMinSample || totalDist <= 0 {
		return nil, nil
	}
	baseline := totalFuel / totalDist

	var anomalies []domain.Anomaly
	for _, t := range trips {
		if !qualifies(t) {
			continue
		}
		ratio := *t.FuelConsumedL / *t.DistanceNM
		if baseline > 0 && ratio > baseline*(1+anomalyThreshold) {
			anomalies = append(anomalies, domain.Anomaly{
				TripID:       t.ID,
				Date:         t.DepartureTime,
				Metric:       "fuel_per_nm",
				Value:        ratio,
				Baseline:     baseline,
				DeviationPct: (ratio/baseline - 1) * 100,
			})
		}
	}
	return anomalies, nil
}

func qualifies(t domain.Trip) bool {
	return t.Status == domain.TripStatusCompleted &&
		t.FuelConsumedL != nil && *t.FuelConsumedL > 0 &&
		t.DistanceNM != nil && *t.DistanceNM >= anomalyMinDistanceNM
}

func (s *AnomalyService) allTrips(ctx context.Context, boatID string) ([]domain.Trip, error) {
	var all []domain.Trip
	cursor := ""
	for {
		batch, next, err := s.trips.ListByBoatAll(ctx, boatID, cursor, 100)
		if err != nil {
			return nil, err
		}
		all = append(all, batch...)
		if next == "" {
			return all, nil
		}
		cursor = next
	}
}
