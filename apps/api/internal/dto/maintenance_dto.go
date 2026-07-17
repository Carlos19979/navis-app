package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// CreateMaintenanceRequest is the payload to log a maintenance entry. TaskID
// optionally links the entry to a recurring task; omit it for a one-off.
type CreateMaintenanceRequest struct {
	TaskID      *string  `json:"task_id" validate:"omitempty,uuid"`
	Type        string   `json:"type" validate:"required,max=80"`
	PerformedAt string   `json:"performed_at" validate:"required"`
	EngineHours *float64 `json:"engine_hours"`
	Cost        *float64 `json:"cost"`
	Provider    *string  `json:"provider"`
	Notes       *string  `json:"notes"`
	InvoiceURL  *string  `json:"invoice_url"`
	PhotoURLs   []string `json:"photo_urls" validate:"omitempty,max=10,dive,url"`
}

// MaintenanceResponse is the API representation of a maintenance log.
type MaintenanceResponse struct {
	ID          string   `json:"id"`
	BoatID      string   `json:"boat_id"`
	TaskID      *string  `json:"task_id"`
	Type        string   `json:"type"`
	PerformedAt string   `json:"performed_at"`
	EngineHours *float64 `json:"engine_hours"`
	Cost        *float64 `json:"cost"`
	Provider    *string  `json:"provider"`
	Notes       *string  `json:"notes"`
	InvoiceURL  *string  `json:"invoice_url"`
	PhotoURLs   []string `json:"photo_urls"`
}

// MaintenanceResponseFromDomain converts a domain log to a response.
func MaintenanceResponseFromDomain(m *domain.MaintenanceLog) MaintenanceResponse {
	return MaintenanceResponse{
		ID:          m.ID,
		BoatID:      m.BoatID,
		TaskID:      m.TaskID,
		Type:        m.Type,
		PerformedAt: m.PerformedAt.Format("2006-01-02"),
		EngineHours: m.EngineHours,
		Cost:        m.Cost,
		Provider:    m.Provider,
		Notes:       m.Notes,
		InvoiceURL:  m.InvoiceURL,
		PhotoURLs:   emptyIfNil(m.PhotoURLs),
	}
}

// emptyIfNil keeps photo arrays serializing as [] instead of null.
func emptyIfNil(urls []string) []string {
	if urls == nil {
		return []string{}
	}
	return urls
}

// MaintenanceListFromDomain converts a slice of logs.
func MaintenanceListFromDomain(logs []domain.MaintenanceLog) []MaintenanceResponse {
	out := make([]MaintenanceResponse, len(logs))
	for i := range logs {
		out[i] = MaintenanceResponseFromDomain(&logs[i])
	}
	return out
}

// CreateMaintenanceTaskRequest is the payload to create/update a recurring task.
type CreateMaintenanceTaskRequest struct {
	Name           string   `json:"name" validate:"required,max=80"`
	IntervalMonths *int     `json:"interval_months" validate:"omitempty,gt=0"`
	IntervalHours  *float64 `json:"interval_hours" validate:"omitempty,gt=0"`
}

// MaintenanceTaskResponse is the API representation of a task plus its derived
// due-state (status, last service, next-due date/hours).
type MaintenanceTaskResponse struct {
	ID              string   `json:"id"`
	BoatID          string   `json:"boat_id"`
	Name            string   `json:"name"`
	IntervalMonths  *int     `json:"interval_months"`
	IntervalHours   *float64 `json:"interval_hours"`
	Status          string   `json:"status"`
	LastPerformedAt *string  `json:"last_performed_at"`
	LastEngineHours *float64 `json:"last_engine_hours"`
	NextDueDate     *string  `json:"next_due_date"`
	NextDueDays     *int     `json:"next_due_days"`
	HoursUntilDue   *float64 `json:"hours_until_due"`
}

// MaintenanceTaskResponseFromDomain converts a task view to a response.
func MaintenanceTaskResponseFromDomain(v *domain.MaintenanceTaskView) MaintenanceTaskResponse {
	resp := MaintenanceTaskResponse{
		ID:              v.Task.ID,
		BoatID:          v.Task.BoatID,
		Name:            v.Task.Name,
		IntervalMonths:  v.Task.IntervalMonths,
		IntervalHours:   v.Task.IntervalHours,
		Status:          string(v.Status),
		LastEngineHours: v.LastEngineHours,
		HoursUntilDue:   v.HoursUntilDue,
	}
	if v.LastPerformedAt != nil {
		s := v.LastPerformedAt.Format("2006-01-02")
		resp.LastPerformedAt = &s
	}
	if v.NextDueDate != nil {
		s := v.NextDueDate.Format("2006-01-02")
		resp.NextDueDate = &s
		d := v.DueDays
		resp.NextDueDays = &d
	}
	return resp
}

// MaintenanceTaskListFromDomain converts a slice of task views.
func MaintenanceTaskListFromDomain(views []domain.MaintenanceTaskView) []MaintenanceTaskResponse {
	out := make([]MaintenanceTaskResponse, len(views))
	for i := range views {
		out[i] = MaintenanceTaskResponseFromDomain(&views[i])
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
