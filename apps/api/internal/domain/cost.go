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

// CostAnalytics is the advanced cost intelligence for a boat (Pro).
type CostAnalytics struct {
	TotalSpend       float64
	ExpenseSpend     float64
	MaintenanceSpend float64
	ByCategory       []CostBreakdownItem
	Monthly          []CostMonthly // last 12 months, chronological
	TotalDistanceNM  float64
	CompletedTrips   int
	TotalFuelL       float64
	// Derived ratios are nil when the denominator is zero.
	CostPerNM   *float64
	CostPerTrip *float64
	FuelPerNM   *float64
}
