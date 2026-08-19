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

func intPtr(v int) *int { return &v }

func timePtr(v time.Time) *time.Time { return &v }

func day(year int, month time.Month, d int) time.Time {
	return time.Date(year, month, d, 12, 0, 0, 0, time.UTC)
}

// costOpts is what a cost test varies; the zero value is an empty boat.
type costOpts struct {
	expenses []domain.Expense
	logs     []domain.MaintenanceLog
	trips    []domain.Trip
	docs     []domain.Document
	plan     domain.Plan
	// now pins the end of the month series. Zero means "leave time.Now".
	now time.Time
}

func newCostSvc(o costOpts) *CostService {
	plan := o.plan
	if plan == "" {
		plan = domain.PlanPro
	}
	trips := &mockTripRepo{
		listByBoatAllFn: func(_ context.Context, _, _ string, _ int) ([]domain.Trip, string, error) {
			return o.trips, "", nil
		},
	}
	svc := NewCostService(
		&mockExpenseRepo{expenses: o.expenses},
		&mockMaintenanceRepo{logs: o.logs},
		trips,
		readinessDocs(o.docs...),
		&mockBoatRepo{},
		&testutil.FakeProfileRepo{Plan: plan},
	)
	if !o.now.IsZero() {
		now := o.now
		svc.now = func() time.Time { return now }
	}
	return svc
}

// getCost runs the service and fails the test on error.
func getCost(t *testing.T, o costOpts) *domain.CostAnalytics {
	t.Helper()
	ca, err := newCostSvc(o).Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	return ca
}

// monthOf returns the series entry for key, or fails.
func monthOf(t *testing.T, ca *domain.CostAnalytics, key string) domain.CostMonth {
	t.Helper()
	for _, m := range ca.Months {
		if m.Month == key {
			return m
		}
	}
	t.Fatalf("month %q missing from series %v", key, monthKeys(ca))
	return domain.CostMonth{}
}

func monthKeys(ca *domain.CostAnalytics) []string {
	out := make([]string, len(ca.Months))
	for i, m := range ca.Months {
		out[i] = m.Month
	}
	return out
}

func TestCostService_Get_AggregatesAndDerives(t *testing.T) {
	t.Parallel()
	ca := getCost(t, costOpts{
		expenses: []domain.Expense{
			{Category: domain.ExpenseCategoryFuel, Amount: 100, IncurredOn: day(2026, time.March, 4)},
			{Category: domain.ExpenseCategoryMooring, Amount: 50, IncurredOn: day(2026, time.March, 9)},
		},
		logs: []domain.MaintenanceLog{{Cost: f64(50), PerformedAt: day(2026, time.March, 20)}},
		trips: []domain.Trip{
			{
				Status: domain.TripStatusCompleted, DepartureTime: day(2026, time.March, 12),
				DistanceNM: f64(100), FuelConsumedL: f64(40),
			},
			// Still recording: no distance, no trip count, no ratios.
			{
				Status: domain.TripStatusRecording, DepartureTime: day(2026, time.March, 15),
				DistanceNM: f64(999),
			},
		},
		now: day(2026, time.March, 31),
	})

	if ca.TotalSpend != 200 {
		t.Errorf("total spend = %v, want 200", ca.TotalSpend)
	}
	if ca.CompletedTrips != 1 || ca.TotalDistanceNM != 100 {
		t.Errorf("trips=%d distance=%v, want 1 / 100", ca.CompletedTrips, ca.TotalDistanceNM)
	}
	if ca.CostPerNM == nil || *ca.CostPerNM != 2 {
		t.Errorf("costPerNM = %v, want 2", ca.CostPerNM)
	}
	if ca.CostPerTrip == nil || *ca.CostPerTrip != 200 {
		t.Errorf("costPerTrip = %v, want 200", ca.CostPerTrip)
	}
	if ca.FuelPerNM == nil || *ca.FuelPerNM != 0.4 {
		t.Errorf("fuelPerNM = %v, want 0.4", ca.FuelPerNM)
	}
	if len(ca.Monthly) != costMonths {
		t.Errorf("monthly len = %d, want %d", len(ca.Monthly), costMonths)
	}

	// Biggest category first, and maintenance under its own synthetic key.
	want := []domain.CostBreakdownItem{
		{Key: domain.ExpenseCategoryFuel, Amount: 100},
		{Key: domain.ExpenseCategoryMooring, Amount: 50},
		{Key: domain.ReadinessCatMaintenance, Amount: 50},
	}
	if len(ca.ByCategory) != len(want) {
		t.Fatalf("byCategory = %v, want %v", ca.ByCategory, want)
	}
	for i, w := range want {
		if ca.ByCategory[i] != w {
			t.Errorf("byCategory[%d] = %v, want %v", i, ca.ByCategory[i], w)
		}
	}

	march := monthOf(t, ca, "2026-03")
	if march.Total() != 200 {
		t.Errorf("march total = %v, want 200", march.Total())
	}
	if march.Trips != 1 || march.DistanceNM != 100 || march.FuelL != 40 {
		t.Errorf("march use = %+v, want 1 trip / 100 NM / 40 L", march)
	}
}

func TestCostService_Get_MonthSeriesIsZeroFilledToNow(t *testing.T) {
	t.Parallel()
	ca := getCost(t, costOpts{
		expenses: []domain.Expense{
			{Category: domain.ExpenseCategoryMooring, Amount: 120, IncurredOn: day(2026, time.January, 15)},
			{Category: domain.ExpenseCategoryFuel, Amount: 80, IncurredOn: day(2026, time.April, 2)},
		},
		now: day(2026, time.May, 20),
	})

	want := []string{"2026-01", "2026-02", "2026-03", "2026-04", "2026-05"}
	got := monthKeys(ca)
	if len(got) != len(want) {
		t.Fatalf("series = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("series = %v, want %v", got, want)
		}
	}
	// The filled months are real zeroes, not gaps the client has to guess.
	for _, key := range []string{"2026-02", "2026-03", "2026-05"} {
		if m := monthOf(t, ca, key); m.Total() != 0 || len(m.ByCategory) != 0 {
			t.Errorf("%s = %+v, want an empty month", key, m)
		}
	}
	if m := monthOf(t, ca, "2026-01"); m.Total() != 120 {
		t.Errorf("january = %v, want 120", m.Total())
	}
	if m := monthOf(t, ca, "2026-04"); m.Total() != 80 {
		t.Errorf("april = %v, want 80", m.Total())
	}
}

func TestCostService_Get_FilesEachSourceUnderItsOwnDate(t *testing.T) {
	t.Parallel()
	ca := getCost(t, costOpts{
		expenses: []domain.Expense{
			{Category: domain.ExpenseCategoryFuel, Amount: 10, IncurredOn: day(2026, time.February, 3)},
		},
		logs: []domain.MaintenanceLog{{Cost: f64(20), PerformedAt: day(2026, time.March, 3)}},
		docs: []domain.Document{{
			LastRenewalDate: timePtr(day(2026, time.April, 3)),
			LastRenewalCost: f64(30),
		}},
		trips: []domain.Trip{{
			// Created much later than it departed: the series must follow the
			// departure, which is how the logbook groups trips.
			Status: domain.TripStatusCompleted, DepartureTime: day(2026, time.January, 3),
			CreatedAt: day(2026, time.May, 3), DistanceNM: f64(40),
		}},
		now: day(2026, time.April, 30),
	})

	for _, tc := range []struct {
		month string
		total float64
	}{
		{"2026-01", 0}, {"2026-02", 10}, {"2026-03", 20}, {"2026-04", 30},
	} {
		if got := monthOf(t, ca, tc.month).Total(); got != tc.total {
			t.Errorf("%s total = %v, want %v", tc.month, got, tc.total)
		}
	}
	if m := monthOf(t, ca, "2026-01"); m.DistanceNM != 40 || m.Trips != 1 {
		t.Errorf("january use = %+v, want 1 trip / 40 NM", m)
	}
	// The series stops at now, even though a trip was created in May.
	for _, key := range monthKeys(ca) {
		if key == "2026-05" {
			t.Errorf("series ran past now: %v", monthKeys(ca))
		}
	}
}

func TestCostService_Get_SkipsIncompleteDocumentRenewals(t *testing.T) {
	t.Parallel()
	ca := getCost(t, costOpts{
		docs: []domain.Document{
			{LastRenewalDate: timePtr(day(2026, time.February, 1)), LastRenewalCost: f64(200)},
			// A price with no date has no month to live in.
			{LastRenewalCost: f64(999)},
			// A date with no price is not money.
			{LastRenewalDate: timePtr(day(2026, time.February, 1))},
		},
		now: day(2026, time.February, 20),
	})

	feb := monthOf(t, ca, "2026-02")
	if feb.Total() != 200 {
		t.Errorf("february total = %v, want 200", feb.Total())
	}
	if got := feb.ByCategory[domain.ReadinessCatDocuments]; got != 200 {
		t.Errorf("documents = %v, want 200", got)
	}
}

func TestCostService_Get_SplitsFixedFromVariable(t *testing.T) {
	t.Parallel()
	on := day(2026, time.June, 10)
	ca := getCost(t, costOpts{
		expenses: []domain.Expense{
			{Category: domain.ExpenseCategoryMooring, Amount: 300, IncurredOn: on},
			{Category: domain.ExpenseCategoryInsurance, Amount: 200, IncurredOn: on},
			{Category: domain.ExpenseCategoryFuel, Amount: 100, IncurredOn: on},
			{Category: domain.ExpenseCategoryRepair, Amount: 40, IncurredOn: on},
			{Category: domain.ExpenseCategoryCleaning, Amount: 30, IncurredOn: on},
			// A category the owner invented counts as variable.
			{Category: "vela nueva", Amount: 20, IncurredOn: on},
		},
		logs: []domain.MaintenanceLog{{Cost: f64(10), PerformedAt: on}},
		docs: []domain.Document{{
			LastRenewalDate: timePtr(on), LastRenewalCost: f64(50),
		}},
		now: day(2026, time.June, 30),
	})

	june := monthOf(t, ca, "2026-06")
	// Berth + insurance + the paperwork renewal.
	if june.Fixed != 550 {
		t.Errorf("fixed = %v, want 550", june.Fixed)
	}
	// Fuel + repair + cleaning + custom + maintenance.
	if june.Variable != 200 {
		t.Errorf("variable = %v, want 200", june.Variable)
	}
	if june.Total() != 750 {
		t.Errorf("total = %v, want 750", june.Total())
	}
}

func TestCostService_Get_CarriesTripUseMetrics(t *testing.T) {
	t.Parallel()
	ca := getCost(t, costOpts{
		trips: []domain.Trip{{
			Status: domain.TripStatusCompleted, DepartureTime: day(2026, time.July, 5),
			DistanceNM: f64(60), FuelConsumedL: f64(24),
			EngineHours: f64(7.5), DurationMinutes: intPtr(150),
		}},
		now: day(2026, time.July, 31),
	})

	july := monthOf(t, ca, "2026-07")
	if july.EngineHours != 7.5 {
		t.Errorf("engine hours = %v, want 7.5", july.EngineHours)
	}
	if july.Hours != 2.5 {
		t.Errorf("hours = %v, want 2.5", july.Hours)
	}
}

func TestCostService_Get_LegacyFieldsIgnoreDocumentRenewals(t *testing.T) {
	t.Parallel()
	on := day(2026, time.August, 1)
	ca := getCost(t, costOpts{
		expenses: []domain.Expense{
			{Category: domain.ExpenseCategoryFuel, Amount: 100, IncurredOn: on},
		},
		logs: []domain.MaintenanceLog{{Cost: f64(60), PerformedAt: on}},
		docs: []domain.Document{{
			LastRenewalDate: timePtr(on), LastRenewalCost: f64(450),
		}},
		now: on,
	})

	// Pre-rework clients must not see their total move; the series carries the
	// renewal, the legacy fields do not.
	if ca.TotalSpend != 160 {
		t.Errorf("legacy total = %v, want 160 (renewal excluded)", ca.TotalSpend)
	}
	if ca.ExpenseSpend != 100 || ca.MaintenanceSpend != 60 {
		t.Errorf("expense=%v maintenance=%v, want 100 / 60", ca.ExpenseSpend, ca.MaintenanceSpend)
	}
	for _, item := range ca.ByCategory {
		if item.Key == domain.ReadinessCatDocuments {
			t.Errorf("legacy byCategory leaked %q", item.Key)
		}
	}
	if got := ca.Monthly[len(ca.Monthly)-1].Amount; got != 160 {
		t.Errorf("legacy monthly = %v, want 160", got)
	}
	if got := monthOf(t, ca, "2026-08").Total(); got != 610 {
		t.Errorf("series total = %v, want 610 (renewal included)", got)
	}
}

func TestCostService_Get_EmptyBoatHasNoSeries(t *testing.T) {
	t.Parallel()
	ca := getCost(t, costOpts{now: day(2026, time.May, 1)})

	if len(ca.Months) != 0 {
		t.Errorf("series = %v, want empty", monthKeys(ca))
	}
	if ca.TotalSpend != 0 || ca.CostPerNM != nil || ca.CostPerTrip != nil {
		t.Errorf("empty boat should have no totals or ratios, got %+v", ca)
	}
}

func TestCostService_Get_AvgPricePerLiter(t *testing.T) {
	t.Parallel()
	on := day(2026, time.September, 2)
	ca := getCost(t, costOpts{expenses: []domain.Expense{
		{Category: domain.ExpenseCategoryFuel, Amount: 100, Liters: f64(50), IncurredOn: on},
		{Category: domain.ExpenseCategoryFuel, Amount: 60, Liters: f64(40), IncurredOn: on},
		// No litres → ignored for €/L.
		{Category: domain.ExpenseCategoryFuel, Amount: 30, IncurredOn: on},
		// Non-fuel → ignored.
		{Category: domain.ExpenseCategoryMooring, Amount: 200, Liters: f64(999), IncurredOn: on},
	}, now: on})

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
	// Same pair on the month, so the client can price any window.
	sept := monthOf(t, ca, "2026-09")
	if sept.FuelLiters != 90 || sept.FuelAmount != 160 {
		t.Errorf("month fuel = %v L / %v €, want 90 / 160", sept.FuelLiters, sept.FuelAmount)
	}
}

func TestCostService_Get_NoLitersNoPricePerLiter(t *testing.T) {
	t.Parallel()
	ca := getCost(t, costOpts{expenses: []domain.Expense{
		{Category: domain.ExpenseCategoryFuel, Amount: 80, IncurredOn: day(2026, time.October, 1)},
	}})

	if ca.AvgPricePerLiter != nil {
		t.Errorf("avg €/L = %v, want nil (no litres recorded)", *ca.AvgPricePerLiter)
	}
}

func TestCostService_Get_ForbiddenOnFree(t *testing.T) {
	t.Parallel()
	_, err := newCostSvc(costOpts{plan: domain.PlanFree}).
		Get(context.Background(), "user-1", "boat-1")
	if !errors.Is(err, domain.ErrPlanForbidden) {
		t.Errorf("err = %v, want ErrPlanForbidden", err)
	}
}
