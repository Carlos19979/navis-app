package domain

// CostBreakdownItem is spend attributed to one category (or "maintenance").
type CostBreakdownItem struct {
	Key    string
	Amount float64
}

// CostMonthly is total spend in a calendar month (Month = "YYYY-MM").
type CostMonthly struct {
	Month  string
	Amount float64
}

// CostMonth is everything spent and sailed in one calendar month — the unit the
// cost screen slices to build any period the owner picks.
//
// Money and use travel together on purpose: with both on the same row the
// client can derive every ratio (€/NM, €/trip, €/engine hour, L/NM, €/L) for an
// arbitrary window without another round trip. Before this the API answered
// only with all-time totals, so "total spend" could not say *of what period* and
// €/NM divided a lifetime of spend by a lifetime of miles.
type CostMonth struct {
	Month string // "YYYY-MM"
	// ByCategory holds expense categories plus the synthetic
	// ReadinessCatMaintenance and ReadinessCatDocuments keys.
	ByCategory map[string]float64
	// Fixed is spend owed whether or not the boat leaves the dock; Variable is
	// the rest. See IsFixedCost.
	Fixed    float64
	Variable float64
	// FuelAmount and FuelLiters cover only fuel expenses that recorded a
	// quantity — the pair that yields a real blended €/L.
	FuelAmount float64
	FuelLiters float64
	// Trips, DistanceNM, FuelL, EngineHours and Hours come from completed trips
	// departing in the month.
	Trips       int
	DistanceNM  float64
	FuelL       float64 // litres burned per the logbook
	EngineHours float64
	Hours       float64 // underway hours, from duration_minutes
}

// Total is everything the month cost, across all sources.
func (m CostMonth) Total() float64 {
	return m.Fixed + m.Variable
}

// CostAnalytics is the advanced cost intelligence for a boat (Pro).
type CostAnalytics struct {
	// Months is the full history, chronological and zero-filled from the first
	// dated record to the current month. This is what the app reads.
	Months []CostMonth

	// Everything below is kept for pre-rework clients, which read all-time
	// totals and a trailing 12-month series. They are derived from Months and
	// deliberately exclude ReadinessCatDocuments, so an app in the wild does not
	// see its numbers move under it.
	TotalSpend       float64
	ExpenseSpend     float64
	MaintenanceSpend float64
	ByCategory       []CostBreakdownItem
	Monthly          []CostMonthly // last 12 months, chronological
	TotalDistanceNM  float64
	CompletedTrips   int
	TotalFuelL       float64
	// FuelLitersPurchased is the sum of litres across fuel expenses that
	// recorded a quantity (independent of trip fuel).
	FuelLitersPurchased float64
	// Derived ratios are nil when the denominator is zero.
	CostPerNM   *float64
	CostPerTrip *float64
	FuelPerNM   *float64
	// AvgPricePerLiter is the blended €/L across fuel expenses with litres.
	AvgPricePerLiter *float64
}

// IsFixedCost reports whether a category is owed whether or not the boat leaves
// the dock: the berth, the insurance and the paperwork renewals. Everything
// else — fuel, repairs, maintenance, and any category the owner invented —
// scales with use.
func IsFixedCost(category string) bool {
	switch category {
	case ExpenseCategoryMooring, ExpenseCategoryInsurance, ReadinessCatDocuments:
		return true
	default:
		return false
	}
}
