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

func TestCostService_Get_AvgPricePerLiter(t *testing.T) {
	t.Parallel()
	exp := &mockExpenseRepo{expenses: []domain.Expense{
		{Category: domain.ExpenseCategoryFuel, Amount: 100, Liters: f64(50), IncurredOn: time.Now()},
		{Category: domain.ExpenseCategoryFuel, Amount: 60, Liters: f64(40), IncurredOn: time.Now()},
		{Category: domain.ExpenseCategoryFuel, Amount: 30, IncurredOn: time.Now()},  // no litres → ignored for €/L
		{Category: "amarre", Amount: 200, Liters: f64(999), IncurredOn: time.Now()}, // non-fuel → ignored
	}}
	svc := NewCostService(exp, &mockMaintenanceRepo{}, &mockTripRepo{},
		&mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	ca, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ca.FuelLitersPurchased != 90 {
		t.Errorf("fuel litres = %v, want 90", ca.FuelLitersPurchased)
	}
	// Blended €/L over the two fuel expenses with litres: 160 / 90.
	if ca.AvgPricePerLiter == nil {
		t.Fatal("avg €/L = nil, want ~1.78")
	}
	if got := *ca.AvgPricePerLiter; got < 1.77 || got > 1.78 {
		t.Errorf("avg €/L = %v, want ~1.777", got)
	}
}

func TestCostService_Get_NoLitersNoPricePerLiter(t *testing.T) {
	t.Parallel()
	exp := &mockExpenseRepo{expenses: []domain.Expense{
		{Category: domain.ExpenseCategoryFuel, Amount: 80, IncurredOn: time.Now()},
	}}
	svc := NewCostService(exp, &mockMaintenanceRepo{}, &mockTripRepo{},
		&mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	ca, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if ca.AvgPricePerLiter != nil {
		t.Errorf("avg €/L = %v, want nil (no litres recorded)", *ca.AvgPricePerLiter)
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
