package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// CreateMaintenanceRequest is the payload to log a maintenance entry.
type CreateMaintenanceRequest struct {
	Type        string   `json:"type" validate:"required,max=80"`
	PerformedAt string   `json:"performed_at" validate:"required"`
	EngineHours *float64 `json:"engine_hours"`
	Cost        *float64 `json:"cost"`
	Provider    *string  `json:"provider"`
	Notes       *string  `json:"notes"`
	InvoiceURL  *string  `json:"invoice_url"`
}

// MaintenanceResponse is the API representation of a maintenance log.
type MaintenanceResponse struct {
	ID          string   `json:"id"`
	BoatID      string   `json:"boat_id"`
	Type        string   `json:"type"`
	PerformedAt string   `json:"performed_at"`
	EngineHours *float64 `json:"engine_hours"`
	Cost        *float64 `json:"cost"`
	Provider    *string  `json:"provider"`
	Notes       *string  `json:"notes"`
	InvoiceURL  *string  `json:"invoice_url"`
}

// MaintenanceResponseFromDomain converts a domain log to a response.
func MaintenanceResponseFromDomain(m *domain.MaintenanceLog) MaintenanceResponse {
	return MaintenanceResponse{
		ID:          m.ID,
		BoatID:      m.BoatID,
		Type:        m.Type,
		PerformedAt: m.PerformedAt.Format("2006-01-02"),
		EngineHours: m.EngineHours,
		Cost:        m.Cost,
		Provider:    m.Provider,
		Notes:       m.Notes,
		InvoiceURL:  m.InvoiceURL,
	}
}

// MaintenanceListFromDomain converts a slice of logs.
func MaintenanceListFromDomain(logs []domain.MaintenanceLog) []MaintenanceResponse {
	out := make([]MaintenanceResponse, len(logs))
	for i := range logs {
		out[i] = MaintenanceResponseFromDomain(&logs[i])
	}
	return out
}

// CreateExpenseRequest is the payload to record an expense.
type CreateExpenseRequest struct {
	Category   string  `json:"category" validate:"required,max=40"`
	Amount     float64 `json:"amount" validate:"required"`
	IncurredOn string  `json:"incurred_on" validate:"required"`
	Notes      *string `json:"notes"`
	InvoiceURL *string `json:"invoice_url"`
}

// ExpenseResponse is the API representation of an expense.
type ExpenseResponse struct {
	ID         string  `json:"id"`
	BoatID     string  `json:"boat_id"`
	Category   string  `json:"category"`
	Amount     float64 `json:"amount"`
	IncurredOn string  `json:"incurred_on"`
	Notes      *string `json:"notes"`
	InvoiceURL *string `json:"invoice_url"`
}

// ExpenseResponseFromDomain converts a domain expense to a response.
func ExpenseResponseFromDomain(e *domain.Expense) ExpenseResponse {
	return ExpenseResponse{
		ID:         e.ID,
		BoatID:     e.BoatID,
		Category:   e.Category,
		Amount:     e.Amount,
		IncurredOn: e.IncurredOn.Format("2006-01-02"),
		Notes:      e.Notes,
		InvoiceURL: e.InvoiceURL,
	}
}

// ExpenseListFromDomain converts a slice of expenses.
func ExpenseListFromDomain(items []domain.Expense) []ExpenseResponse {
	out := make([]ExpenseResponse, len(items))
	for i := range items {
		out[i] = ExpenseResponseFromDomain(&items[i])
	}
	return out
}

// ExpenseSummaryResponse aggregates expenses per category.
type ExpenseSummaryResponse struct {
	Totals map[string]float64 `json:"totals"`
	Total  float64            `json:"total"`
}

// ParseDate parses a YYYY-MM-DD date string.
func ParseDate(s string) (time.Time, error) {
	return time.Parse("2006-01-02", s)
}
