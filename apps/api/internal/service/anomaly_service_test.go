package service

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

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

// datedTrip is completedTrip with a departure, for the ordering tests.
func datedTrip(id string, fuel, dist float64, departed time.Time) domain.Trip {
	t := completedTrip(id, fuel, dist)
	t.DepartureTime = departed
	return t
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
	if out[0].DistanceNM != 100 {
		t.Errorf("distance = %v, want 100", out[0].DistanceNM)
	}
	// Baseline 0.45 L/NM over the four trips, so trip d burned 15 L too many.
	if got := out[0].ExcessLiters; got < 14.9 || got > 15.1 {
		t.Errorf("excess litres = %v, want ~15", got)
	}
}

func TestAnomalyService_ReturnsMostRecentFirstAndCaps(t *testing.T) {
	t.Parallel()
	// A long, well-behaved history so the baseline stays honest, plus more
	// anomalies than the cap, handed over in ascending date order so any sorting
	// slip shows. The normal trips have to outnumber the bad ones: the baseline
	// is pooled over every trip, so a fleet that is mostly anomalous has no
	// anomalies at all.
	var trips []domain.Trip
	for i := 1; i <= 200; i++ {
		trips = append(trips, datedTrip(
			fmt.Sprintf("ok-%03d", i), 40, 100, day(2020, time.January, 1).AddDate(0, 0, i),
		))
	}
	for i := 1; i <= anomalyMaxResults+5; i++ {
		trips = append(trips, datedTrip(
			fmt.Sprintf("bad-%02d", i), 80, 100, day(2021, time.January, i),
		))
	}
	svc := NewAnomalyService(anomalyTrips(trips...), &mockBoatRepo{},
		&testutil.FakeProfileRepo{Plan: domain.PlanPro})

	out, err := svc.ForBoat(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(out) != anomalyMaxResults {
		t.Fatalf("anomalies = %d, want the cap of %d", len(out), anomalyMaxResults)
	}
	// Newest first: the last bad trip must lead, and the kept window must be the
	// recent one, not whatever the repo happened to page first.
	if want := fmt.Sprintf("bad-%02d", anomalyMaxResults+5); out[0].TripID != want {
		t.Errorf("first = %q, want %q", out[0].TripID, want)
	}
	for i := 1; i < len(out); i++ {
		if out[i].Date.After(out[i-1].Date) {
			t.Fatalf("anomaly %d (%v) is newer than the one before it (%v)",
				i, out[i].Date, out[i-1].Date)
		}
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
