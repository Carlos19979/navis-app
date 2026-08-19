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

// CostMonthResponse mirrors domain.CostMonth.
type CostMonthResponse struct {
	Month       string             `json:"month"`
	ByCategory  map[string]float64 `json:"by_category"`
	Fixed       float64            `json:"fixed"`
	Variable    float64            `json:"variable"`
	FuelAmount  float64            `json:"fuel_amount"`
	FuelLiters  float64            `json:"fuel_liters"`
	Trips       int                `json:"trips"`
	DistanceNM  float64            `json:"distance_nm"`
	FuelL       float64            `json:"fuel_l"`
	EngineHours float64            `json:"engine_hours"`
	Hours       float64            `json:"hours"`
}

// CostAnalyticsResponse is the cost-intelligence payload. Months is the series
// the app slices; everything after it is kept for pre-rework clients.
type CostAnalyticsResponse struct {
	Months              []CostMonthResponse         `json:"months"`
	TotalSpend          float64                     `json:"total_spend"`
	ExpenseSpend        float64                     `json:"expense_spend"`
	MaintenanceSpend    float64                     `json:"maintenance_spend"`
	ByCategory          []CostBreakdownItemResponse `json:"by_category"`
	Monthly             []CostMonthlyResponse       `json:"monthly"`
	TotalDistanceNM     float64                     `json:"total_distance_nm"`
	CompletedTrips      int                         `json:"completed_trips"`
	TotalFuelL          float64                     `json:"total_fuel_l"`
	CostPerNM           *float64                    `json:"cost_per_nm"`
	CostPerTrip         *float64                    `json:"cost_per_trip"`
	FuelPerNM           *float64                    `json:"fuel_per_nm"`
	FuelLitersPurchased float64                     `json:"fuel_liters_purchased"`
	AvgPricePerLiter    *float64                    `json:"avg_price_per_liter"`
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
	series := make([]CostMonthResponse, len(c.Months))
	for i, m := range c.Months {
		series[i] = CostMonthResponse{
			Month:       m.Month,
			ByCategory:  m.ByCategory,
			Fixed:       m.Fixed,
			Variable:    m.Variable,
			FuelAmount:  m.FuelAmount,
			FuelLiters:  m.FuelLiters,
			Trips:       m.Trips,
			DistanceNM:  m.DistanceNM,
			FuelL:       m.FuelL,
			EngineHours: m.EngineHours,
			Hours:       m.Hours,
		}
	}
	return CostAnalyticsResponse{
		Months:              series,
		TotalSpend:          c.TotalSpend,
		ExpenseSpend:        c.ExpenseSpend,
		MaintenanceSpend:    c.MaintenanceSpend,
		ByCategory:          cats,
		Monthly:             months,
		TotalDistanceNM:     c.TotalDistanceNM,
		CompletedTrips:      c.CompletedTrips,
		TotalFuelL:          c.TotalFuelL,
		CostPerNM:           c.CostPerNM,
		CostPerTrip:         c.CostPerTrip,
		FuelPerNM:           c.FuelPerNM,
		FuelLitersPurchased: c.FuelLitersPurchased,
		AvgPricePerLiter:    c.AvgPricePerLiter,
	}
}
