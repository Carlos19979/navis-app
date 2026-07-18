package service

import (
	"context"
	"fmt"
	"sort"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

const costMonths = 12

// CostService computes advanced cost intelligence for a boat (Pro only).
type CostService struct {
	exp      port.ExpenseRepository
	maint    port.MaintenanceRepository
	trips    port.TripRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
	now      func() time.Time
}

// NewCostService creates a new CostService.
func NewCostService(
	exp port.ExpenseRepository,
	maint port.MaintenanceRepository,
	trips port.TripRepository,
	boats port.BoatRepository,
	profiles port.ProfileRepository,
) *CostService {
	return &CostService{exp: exp, maint: maint, trips: trips, boats: boats, profiles: profiles, now: time.Now}
}

// Get aggregates expenses, maintenance and trips into cost metrics. Requires a
// Pro plan; returns ErrPlanForbidden otherwise.
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

	ca := &domain.CostAnalytics{}
	byCategory := map[string]float64{}
	monthly := map[string]float64{}
	var fuelAmount, fuelLiters float64

	for _, e := range expenses {
		ca.ExpenseSpend += e.Amount
		byCategory[e.Category] += e.Amount
		monthly[e.IncurredOn.Format("2006-01")] += e.Amount
		// Blended €/L: only fuel expenses that recorded a quantity.
		if e.Category == domain.ExpenseCategoryFuel && e.Liters != nil && *e.Liters > 0 {
			fuelAmount += e.Amount
			fuelLiters += *e.Liters
		}
	}
	for _, l := range logs {
		if l.Cost == nil {
			continue
		}
		ca.MaintenanceSpend += *l.Cost
		byCategory[domain.ReadinessCatMaintenance] += *l.Cost
		monthly[l.PerformedAt.Format("2006-01")] += *l.Cost
	}
	for _, t := range trips {
		if t.Status != domain.TripStatusCompleted {
			continue
		}
		ca.CompletedTrips++
		if t.DistanceNM != nil {
			ca.TotalDistanceNM += *t.DistanceNM
		}
		if t.FuelConsumedL != nil {
			ca.TotalFuelL += *t.FuelConsumedL
		}
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

	return ca, nil
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
	sort.Slice(out, func(i, j int) bool { return out[i].Amount > out[j].Amount })
	return out
}

// lastMonths returns the last costMonths calendar months (chronological),
// zero-filled where there was no spend.
func (s *CostService) lastMonths(m map[string]float64) []domain.CostMonthly {
	now := s.now()
	out := make([]domain.CostMonthly, 0, costMonths)
	for i := costMonths - 1; i >= 0; i-- {
		month := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC).
			AddDate(0, -i, 0).Format("2006-01")
		out = append(out, domain.CostMonthly{Month: month, Amount: m[month]})
	}
	return out
}
