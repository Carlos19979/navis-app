package service

import (
	"context"
	"errors"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

func completedTrip(id string, fuel, dist float64) domain.Trip {
	return domain.Trip{
		ID:            id,
		Status:        domain.TripStatusCompleted,
		FuelConsumedL: &fuel,
		DistanceNM:    &dist,
	}
}

func anomalyTrips(trips ...domain.Trip) *mockTripRepo {
	return &mockTripRepo{
		listByBoatAllFn: func(_ context.Context, _, _ string, _ int) ([]domain.Trip, string, error) {
			return trips, "", nil
		},
	}
}

func TestAnomalyService_FlagsHighFuelTrip(t *testing.T) {
	t.Parallel()
	trips := anomalyTrips(
		completedTrip("a", 40, 100), // 0.40 L/NM
		completedTrip("b", 40, 100),
		completedTrip("c", 40, 100),
		completedTrip("d", 60, 100), // 0.60 L/NM — anomalous
	)
	svc := NewAnomalyService(trips, &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	out, err := svc.ForBoat(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(out) != 1 || out[0].TripID != "d" {
		t.Fatalf("anomalies = %+v, want one for trip d", out)
	}
	if out[0].DeviationPct <= 0 {
		t.Errorf("deviation = %v, want > 0", out[0].DeviationPct)
	}
}

func TestAnomalyService_NoBaselineBelowSample(t *testing.T) {
	t.Parallel()
	trips := anomalyTrips(
		completedTrip("a", 40, 100),
		completedTrip("d", 90, 100), // would be anomalous, but sample < 3
	)
	svc := NewAnomalyService(trips, &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	out, err := svc.ForBoat(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(out) != 0 {
		t.Errorf("anomalies = %+v, want none (insufficient sample)", out)
	}
}

func TestAnomalyService_ForbiddenOnFree(t *testing.T) {
	t.Parallel()
	svc := NewAnomalyService(&mockTripRepo{}, &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanFree})
	_, err := svc.ForBoat(context.Background(), "user-1", "boat-1")
	if !errors.Is(err, domain.ErrPlanForbidden) {
		t.Errorf("err = %v, want ErrPlanForbidden", err)
	}
}
