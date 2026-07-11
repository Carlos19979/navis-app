package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// maintenanceService is the service surface the maintenance handlers consume.
type maintenanceService interface {
	AddLog(ctx context.Context, log *domain.MaintenanceLog) (*domain.MaintenanceLog, error)
	ListLogs(ctx context.Context, userID, boatID string) ([]domain.MaintenanceLog, error)
	UpdateLog(ctx context.Context, userID string, log *domain.MaintenanceLog) (*domain.MaintenanceLog, error)
	DeleteLog(ctx context.Context, userID, boatID, id string) error
	AddExpense(ctx context.Context, e *domain.Expense) (*domain.Expense, error)
	ListExpenses(ctx context.Context, userID, boatID string) ([]domain.Expense, error)
	UpdateExpense(ctx context.Context, userID string, e *domain.Expense) (*domain.Expense, error)
	DeleteExpense(ctx context.Context, userID, boatID, id string) error
	ExpenseTotals(ctx context.Context, userID, boatID string) (map[string]float64, error)
}

// MaintenanceHandler handles maintenance log and expense endpoints.
type MaintenanceHandler struct {
	svc maintenanceService
}

// NewMaintenanceHandler creates a new MaintenanceHandler.
func NewMaintenanceHandler(svc maintenanceService) *MaintenanceHandler {
	return &MaintenanceHandler{svc: svc}
}

// ListLogs handles GET /boats/{boatId}/maintenance.
func (h *MaintenanceHandler) ListLogs(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boatID := chi.URLParam(r, "id")
	logs, err := h.svc.ListLogs(r.Context(), userID, boatID)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.MaintenanceListFromDomain(logs))
}

// CreateLog handles POST /boats/{boatId}/maintenance.
func (h *MaintenanceHandler) CreateLog(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boatID := chi.URLParam(r, "id")

	req, ok := decodeAndValidate[dto.CreateMaintenanceRequest](w, r)
	if !ok {
		return
	}
	performedAt, err := dto.ParseDate(req.PerformedAt)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid performed_at date", "BAD_REQUEST")
		return
	}

	log := &domain.MaintenanceLog{
		BoatID:      boatID,
		UserID:      userID,
		Type:        req.Type,
		PerformedAt: performedAt,
		EngineHours: req.EngineHours,
		Cost:        req.Cost,
		Provider:    req.Provider,
		Notes:       req.Notes,
		InvoiceURL:  req.InvoiceURL,
	}
	created, err := h.svc.AddLog(r.Context(), log)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusCreated, dto.MaintenanceResponseFromDomain(created))
}

// UpdateLog handles PUT /boats/{boatId}/maintenance/{logId}.
func (h *MaintenanceHandler) UpdateLog(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.CreateMaintenanceRequest](w, r)
	if !ok {
		return
	}
	performedAt, err := dto.ParseDate(req.PerformedAt)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid performed_at date", "BAD_REQUEST")
		return
	}
	log := &domain.MaintenanceLog{
		ID:          chi.URLParam(r, "logId"),
		BoatID:      chi.URLParam(r, "id"),
		UserID:      userID,
		Type:        req.Type,
		PerformedAt: performedAt,
		EngineHours: req.EngineHours,
		Cost:        req.Cost,
		Provider:    req.Provider,
		Notes:       req.Notes,
		InvoiceURL:  req.InvoiceURL,
	}
	updated, err := h.svc.UpdateLog(r.Context(), userID, log)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.MaintenanceResponseFromDomain(updated))
}

// DeleteLog handles DELETE /boats/{boatId}/maintenance/{logId}.
func (h *MaintenanceHandler) DeleteLog(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	if err := h.svc.DeleteLog(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "logId")); err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ListExpenses handles GET /boats/{boatId}/expenses.
func (h *MaintenanceHandler) ListExpenses(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boatID := chi.URLParam(r, "id")
	items, err := h.svc.ListExpenses(r.Context(), userID, boatID)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.ExpenseListFromDomain(items))
}

// CreateExpense handles POST /boats/{boatId}/expenses.
func (h *MaintenanceHandler) CreateExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boatID := chi.URLParam(r, "id")

	req, ok := decodeAndValidate[dto.CreateExpenseRequest](w, r)
	if !ok {
		return
	}
	incurredOn, err := dto.ParseDate(req.IncurredOn)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid incurred_on date", "BAD_REQUEST")
		return
	}

	e := &domain.Expense{
		BoatID:     boatID,
		UserID:     userID,
		Category:   req.Category,
		Amount:     req.Amount,
		IncurredOn: incurredOn,
		Notes:      req.Notes,
		InvoiceURL: req.InvoiceURL,
	}
	created, err := h.svc.AddExpense(r.Context(), e)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusCreated, dto.ExpenseResponseFromDomain(created))
}

// UpdateExpense handles PUT /boats/{boatId}/expenses/{expenseId}.
func (h *MaintenanceHandler) UpdateExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.CreateExpenseRequest](w, r)
	if !ok {
		return
	}
	incurredOn, err := dto.ParseDate(req.IncurredOn)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid incurred_on date", "BAD_REQUEST")
		return
	}
	e := &domain.Expense{
		ID:         chi.URLParam(r, "expenseId"),
		BoatID:     chi.URLParam(r, "id"),
		UserID:     userID,
		Category:   req.Category,
		Amount:     req.Amount,
		IncurredOn: incurredOn,
		Notes:      req.Notes,
		InvoiceURL: req.InvoiceURL,
	}
	updated, err := h.svc.UpdateExpense(r.Context(), userID, e)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.ExpenseResponseFromDomain(updated))
}

// DeleteExpense handles DELETE /boats/{boatId}/expenses/{expenseId}.
func (h *MaintenanceHandler) DeleteExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	if err := h.svc.DeleteExpense(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "expenseId")); err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ExpenseSummary handles GET /boats/{boatId}/expenses/summary.
func (h *MaintenanceHandler) ExpenseSummary(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boatID := chi.URLParam(r, "id")
	totals, err := h.svc.ExpenseTotals(r.Context(), userID, boatID)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	var total float64
	for _, v := range totals {
		total += v
	}
	JSON(w, http.StatusOK, dto.ExpenseSummaryResponse{Totals: totals, Total: total})
}
