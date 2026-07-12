package dto

import "github.com/Carlos19979/navis-app/apps/api/internal/domain"

// CostBreakdownItemResponse mirrors domain.CostBreakdownItem.
type CostBreakdownItemResponse struct {
	Key    string  `json:"key"`
	Amount float64 `json:"amount"`
}

// CostMonthlyResponse mirrors domain.CostMonthly.
type CostMonthlyResponse struct {
	Month  string  `json:"month"`
	Amount float64 `json:"amount"`
}

// CostAnalyticsResponse is the cost-intelligence payload.
type CostAnalyticsResponse struct {
	TotalSpend       float64                     `json:"total_spend"`
	ExpenseSpend     float64                     `json:"expense_spend"`
	MaintenanceSpend float64                     `json:"maintenance_spend"`
	ByCategory       []CostBreakdownItemResponse `json:"by_category"`
	Monthly          []CostMonthlyResponse       `json:"monthly"`
	TotalDistanceNM  float64                     `json:"total_distance_nm"`
	CompletedTrips   int                         `json:"completed_trips"`
	TotalFuelL       float64                     `json:"total_fuel_l"`
	CostPerNM        *float64                    `json:"cost_per_nm"`
	CostPerTrip      *float64                    `json:"cost_per_trip"`
	FuelPerNM        *float64                    `json:"fuel_per_nm"`
}

// CostAnalyticsResponseFromDomain converts domain.CostAnalytics to a response.
func CostAnalyticsResponseFromDomain(c *domain.CostAnalytics) CostAnalyticsResponse {
	cats := make([]CostBreakdownItemResponse, len(c.ByCategory))
	for i, b := range c.ByCategory {
		cats[i] = CostBreakdownItemResponse{Key: b.Key, Amount: b.Amount}
	}
	months := make([]CostMonthlyResponse, len(c.Monthly))
	for i, m := range c.Monthly {
		months[i] = CostMonthlyResponse{Month: m.Month, Amount: m.Amount}
	}
	return CostAnalyticsResponse{
		TotalSpend:       c.TotalSpend,
		ExpenseSpend:     c.ExpenseSpend,
		MaintenanceSpend: c.MaintenanceSpend,
		ByCategory:       cats,
		Monthly:          months,
		TotalDistanceNM:  c.TotalDistanceNM,
		CompletedTrips:   c.CompletedTrips,
		TotalFuelL:       c.TotalFuelL,
		CostPerNM:        c.CostPerNM,
		CostPerTrip:      c.CostPerTrip,
		FuelPerNM:        c.FuelPerNM,
	}
}
