package service

import (
	"context"
	"fmt"
	"sort"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

const (
	// costMonths is the length of the legacy trailing series kept for
	// pre-rework clients.
	costMonths = 12
	// costMaxMonths caps the full series so one bad date on an old record cannot
	// make the response unbounded.
	costMaxMonths = 180
	// costMonthLayout is the month key format ("YYYY-MM").
	costMonthLayout = "2006-01"
)

// CostService computes advanced cost intelligence for a boat (Pro only).
type CostService struct {
	exp      port.ExpenseRepository
	maint    port.MaintenanceRepository
	trips    port.TripRepository
	docs     port.DocumentRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
	now      func() time.Time
}

// NewCostService creates a new CostService.
func NewCostService(
	exp port.ExpenseRepository,
	maint port.MaintenanceRepository,
	trips port.TripRepository,
	docs port.DocumentRepository,
	boats port.BoatRepository,
	profiles port.ProfileRepository,
) *CostService {
	return &CostService{
		exp: exp, maint: maint, trips: trips, docs: docs,
		boats: boats, profiles: profiles, now: time.Now,
	}
}

// Get aggregates expenses, maintenance, document renewals and trips into a
// month-by-month cost series. Requires a Pro plan; returns ErrPlanForbidden
// otherwise.
//
// Every figure the app shows is derived from that series, so the period control
// costs no round trip and "total spend" can finally name its own window.
func (s *CostService) Get(ctx context.Context, userID, boatID string) (*domain.CostAnalytics, error) {
	if _, err := s.boats.GetByIDAccessible(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("cost analytics: %w", err)
	}
	if s.profiles != nil {
		profile, err := s.profiles.GetOrCreate(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("cost analytics: %w", err)
		}
		if !profile.Plan.CanUseCostAnalytics() {
			return nil, fmt.Errorf("cost analytics: %w", domain.ErrPlanForbidden)
		}
	}

	expenses, err := s.exp.ListByBoat(ctx, boatID)
	if err != nil {
		return nil, fmt.Errorf("cost analytics: %w", err)
	}
	logs, err := s.maint.ListByBoat(ctx, boatID)
	if err != nil {
		return nil, fmt.Errorf("cost analytics: %w", err)
	}
	trips, err := s.allTrips(ctx, boatID)
	if err != nil {
		return nil, fmt.Errorf("cost analytics: %w", err)
	}
	// A generous single page: boats rarely carry more than a handful of docs.
	docs, _, err := s.docs.ListByBoat(ctx, boatID, "", 200)
	if err != nil {
		return nil, fmt.Errorf("cost analytics: %w", err)
	}

	acc := newCostAccumulator()
	for _, e := range expenses {
		m := acc.month(e.IncurredOn)
		acc.spend(m, e.Category, e.Amount)
		// Blended €/L: only fuel expenses that recorded a quantity.
		if e.Category == domain.ExpenseCategoryFuel && e.Liters != nil && *e.Liters > 0 {
			m.FuelAmount += e.Amount
			m.FuelLiters += *e.Liters
		}
	}
	for _, l := range logs {
		if l.Cost == nil {
			continue
		}
		acc.spend(acc.month(l.PerformedAt), domain.ReadinessCatMaintenance, *l.Cost)
	}
	for _, d := range docs {
		// A renewal is money only once it has both a date to file it under and a
		// price. Either missing and there is nothing to attribute.
		if d.LastRenewalDate == nil || d.LastRenewalCost == nil {
			continue
		}
		acc.spend(
			acc.month(*d.LastRenewalDate),
			domain.ReadinessCatDocuments,
			*d.LastRenewalCost,
		)
	}
	for _, t := range trips {
		if t.Status != domain.TripStatusCompleted {
			continue
		}
		// Trips are filed by departure, matching the logbook statistics screen —
		// not by created_at, which is only how the repo paginates.
		m := acc.month(t.DepartureTime)
		m.Trips++
		if t.DistanceNM != nil {
			m.DistanceNM += *t.DistanceNM
		}
		if t.FuelConsumedL != nil {
			m.FuelL += *t.FuelConsumedL
		}
		if t.EngineHours != nil {
			m.EngineHours += *t.EngineHours
		}
		if t.DurationMinutes != nil {
			m.Hours += float64(*t.DurationMinutes) / 60
		}
	}

	ca := &domain.CostAnalytics{Months: acc.series(s.now())}
	s.fillLegacy(ca)
	return ca, nil
}

// costAccumulator buckets every source into calendar months.
type costAccumulator struct {
	months map[string]*domain.CostMonth
}

func newCostAccumulator() *costAccumulator {
	return &costAccumulator{months: map[string]*domain.CostMonth{}}
}

// month returns the bucket for when, creating it on first use.
func (a *costAccumulator) month(when time.Time) *domain.CostMonth {
	key := when.Format(costMonthLayout)
	m, ok := a.months[key]
	if !ok {
		m = &domain.CostMonth{Month: key, ByCategory: map[string]float64{}}
		a.months[key] = m
	}
	return m
}

// spend files an amount under a category and on the right side of the
// fixed/variable split.
func (a *costAccumulator) spend(m *domain.CostMonth, category string, amount float64) {
	m.ByCategory[category] += amount
	if domain.IsFixedCost(category) {
		m.Fixed += amount
	} else {
		m.Variable += amount
	}
}

// series returns the months in order, zero-filled from the first one with data
// to the current month so the client can walk a continuous timeline. Empty when
// the boat has nothing recorded at all.
func (a *costAccumulator) series(now time.Time) []domain.CostMonth {
	if len(a.months) == 0 {
		return nil
	}
	keys := make([]string, 0, len(a.months))
	for k := range a.months {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	first, err := time.Parse(costMonthLayout, keys[0])
	if err != nil {
		return nil
	}
	last := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	// A record dated in the future (or the very first month of use) must still
	// show up, so let the series run to whichever end is later.
	if newest, err := time.Parse(costMonthLayout, keys[len(keys)-1]); err == nil &&
		newest.After(last) {
		last = newest
	}
	// Honour the cap from the recent end: a stray ancient date must not push the
	// months the owner cares about out of the response.
	if oldest := last.AddDate(0, -(costMaxMonths - 1), 0); oldest.After(first) {
		first = oldest
	}

	out := make([]domain.CostMonth, 0, costMaxMonths)
	for cursor := first; !cursor.After(last); cursor = cursor.AddDate(0, 1, 0) {
		key := cursor.Format(costMonthLayout)
		if m, ok := a.months[key]; ok {
			out = append(out, *m)
			continue
		}
		out = append(out, domain.CostMonth{
			Month:      key,
			ByCategory: map[string]float64{},
		})
	}
	return out
}

// fillLegacy derives the pre-rework fields from the series. Document renewals
// are left out of them: an app already in the wild must not see its totals move.
func (s *CostService) fillLegacy(ca *domain.CostAnalytics) {
	byCategory := map[string]float64{}
	monthly := map[string]float64{}
	var fuelAmount, fuelLiters float64

	for _, m := range ca.Months {
		for key, amount := range m.ByCategory {
			if key == domain.ReadinessCatDocuments {
				continue
			}
			byCategory[key] += amount
			monthly[m.Month] += amount
			if key == domain.ReadinessCatMaintenance {
				ca.MaintenanceSpend += amount
			} else {
				ca.ExpenseSpend += amount
			}
		}
		fuelAmount += m.FuelAmount
		fuelLiters += m.FuelLiters
		ca.CompletedTrips += m.Trips
		ca.TotalDistanceNM += m.DistanceNM
		ca.TotalFuelL += m.FuelL
	}

	ca.TotalSpend = ca.ExpenseSpend + ca.MaintenanceSpend
	ca.ByCategory = sortedBreakdown(byCategory)
	ca.Monthly = s.lastMonths(monthly)

	if ca.TotalDistanceNM > 0 {
		perNM := ca.TotalSpend / ca.TotalDistanceNM
		ca.CostPerNM = &perNM
		fuelPerNM := ca.TotalFuelL / ca.TotalDistanceNM
		ca.FuelPerNM = &fuelPerNM
	}
	if ca.CompletedTrips > 0 {
		perTrip := ca.TotalSpend / float64(ca.CompletedTrips)
		ca.CostPerTrip = &perTrip
	}
	if fuelLiters > 0 {
		ca.FuelLitersPurchased = fuelLiters
		ppl := fuelAmount / fuelLiters
		ca.AvgPricePerLiter = &ppl
	}
}

// allTrips pages through every trip on the boat.
func (s *CostService) allTrips(ctx context.Context, boatID string) ([]domain.Trip, error) {
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

func sortedBreakdown(m map[string]float64) []domain.CostBreakdownItem {
	out := make([]domain.CostBreakdownItem, 0, len(m))
	for k, v := range m {
		out = append(out, domain.CostBreakdownItem{Key: k, Amount: v})
	}
	// Biggest first, then by key so equal amounts keep a stable order instead of
	// shuffling between requests.
	sort.Slice(out, func(i, j int) bool {
		if out[i].Amount != out[j].Amount {
			return out[i].Amount > out[j].Amount
		}
		return out[i].Key < out[j].Key
	})
	return out
}

// lastMonths returns the last costMonths calendar months (chronological),
// zero-filled where there was no spend.
func (s *CostService) lastMonths(m map[string]float64) []domain.CostMonthly {
	now := s.now()
	out := make([]domain.CostMonthly, 0, costMonths)
	for i := costMonths - 1; i >= 0; i-- {
		month := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC).
			AddDate(0, -i, 0).Format(costMonthLayout)
		out = append(out, domain.CostMonthly{Month: month, Amount: m[month]})
	}
	return out
}
