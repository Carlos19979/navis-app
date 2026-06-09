package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
)

// MaintenanceHandler handles maintenance log and expense endpoints.
type MaintenanceHandler struct {
	svc *service.MaintenanceService
}

// NewMaintenanceHandler creates a new MaintenanceHandler.
func NewMaintenanceHandler(svc *service.MaintenanceService) *MaintenanceHandler {
	return &MaintenanceHandler{svc: svc}
}

// ListLogs handles GET /boats/{boatId}/maintenance.
func (h *MaintenanceHandler) ListLogs(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}
	boatID := chi.URLParam(r, "id")

	var req dto.CreateMaintenanceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}
	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}
	var req dto.CreateMaintenanceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}
	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}
	boatID := chi.URLParam(r, "id")

	var req dto.CreateExpenseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}
	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}
	var req dto.CreateExpenseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}
	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
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
