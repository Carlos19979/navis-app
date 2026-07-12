package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

// mockExpenseRepo is a minimal port.ExpenseRepository for cost tests.
type mockExpenseRepo struct {
	expenses []domain.Expense
}

func (m *mockExpenseRepo) Create(_ context.Context, e *domain.Expense) (*domain.Expense, error) {
	return e, nil
}
func (m *mockExpenseRepo) Update(_ context.Context, e *domain.Expense) (*domain.Expense, error) {
	return e, nil
}
func (m *mockExpenseRepo) Delete(_ context.Context, _, _ string) error { return nil }
func (m *mockExpenseRepo) ListByBoat(_ context.Context, _ string) ([]domain.Expense, error) {
	return m.expenses, nil
}
func (m *mockExpenseRepo) TotalsByCategory(_ context.Context, _ string) (map[string]float64, error) {
	return nil, nil
}
func (m *mockExpenseRepo) GetByID(_ context.Context, _, _ string) (*domain.Expense, error) {
	return &domain.Expense{}, nil
}

func f64(v float64) *float64 { return &v }

func TestCostService_Get_AggregatesAndDerives(t *testing.T) {
	t.Parallel()
	exp := &mockExpenseRepo{expenses: []domain.Expense{
		{Category: "combustible", Amount: 100, IncurredOn: time.Now()},
		{Category: "amarre", Amount: 50, IncurredOn: time.Now()},
	}}
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{
		{Cost: f64(50), PerformedAt: time.Now()},
	}}
	trips := &mockTripRepo{
		listByBoatAllFn: func(_ context.Context, _, _ string, _ int) ([]domain.Trip, string, error) {
			return []domain.Trip{
				{Status: domain.TripStatusCompleted, DistanceNM: f64(100), FuelConsumedL: f64(40)},
				{Status: domain.TripStatusRecording, DistanceNM: f64(999)}, // ignored
			}, "", nil
		},
	}
	svc := NewCostService(exp, maint, trips, &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	ca, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ca.TotalSpend != 200 {
		t.Errorf("total spend = %v, want 200", ca.TotalSpend)
	}
	if ca.CompletedTrips != 1 || ca.TotalDistanceNM != 100 {
		t.Errorf("trips=%d distance=%v, want 1 / 100", ca.CompletedTrips, ca.TotalDistanceNM)
	}
	if ca.CostPerNM == nil || *ca.CostPerNM != 2 {
		t.Errorf("costPerNM = %v, want 2", ca.CostPerNM)
	}
	if ca.FuelPerNM == nil || *ca.FuelPerNM != 0.4 {
		t.Errorf("fuelPerNM = %v, want 0.4", ca.FuelPerNM)
	}
	if len(ca.Monthly) != costMonths {
		t.Errorf("monthly len = %d, want %d", len(ca.Monthly), costMonths)
	}
}

func TestCostService_Get_ForbiddenOnFree(t *testing.T) {
	t.Parallel()
	svc := NewCostService(&mockExpenseRepo{}, &mockMaintenanceRepo{}, &mockTripRepo{},
		&mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanFree})

	_, err := svc.Get(context.Background(), "user-1", "boat-1")
	if !errors.Is(err, domain.ErrPlanForbidden) {
		t.Errorf("err = %v, want ErrPlanForbidden", err)
	}
}
