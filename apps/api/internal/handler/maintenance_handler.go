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
	AddTask(ctx context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error)
	ListTasks(ctx context.Context, userID, boatID string) ([]domain.MaintenanceTaskView, error)
	UpdateTask(ctx context.Context, userID string, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error)
	CompleteTask(ctx context.Context, userID, boatID, taskID string, c domain.MaintenanceCompletion) (*domain.MaintenanceTaskView, error)
	DeleteTask(ctx context.Context, userID, boatID, id string) error
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
		TaskID:      req.TaskID,
		Type:        req.Type,
		PerformedAt: performedAt,
		EngineHours: req.EngineHours,
		Cost:        req.Cost,
		Provider:    req.Provider,
		Notes:       req.Notes,
		InvoiceURL:  req.InvoiceURL,
		PhotoURLs:   req.PhotoURLs,
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
		TaskID:      req.TaskID,
		Type:        req.Type,
		PerformedAt: performedAt,
		EngineHours: req.EngineHours,
		Cost:        req.Cost,
		Provider:    req.Provider,
		Notes:       req.Notes,
		InvoiceURL:  req.InvoiceURL,
		PhotoURLs:   req.PhotoURLs,
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

// ListTasks handles GET /boats/{boatId}/maintenance/tasks.
func (h *MaintenanceHandler) ListTasks(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	views, err := h.svc.ListTasks(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.MaintenanceTaskListFromDomain(views))
}

// taskFromRequest builds the domain task from a create/update payload. The
// service fills in whichever limit the payload left out.
func taskFromRequest(r *http.Request, userID string, req dto.CreateMaintenanceTaskRequest) (*domain.MaintenanceTask, error) {
	task := &domain.MaintenanceTask{
		BoatID:         chi.URLParam(r, "id"),
		UserID:         userID,
		Name:           req.Name,
		Kind:           req.TaskKind(),
		IntervalMonths: req.IntervalMonths,
		IntervalHours:  req.IntervalHours,
		NextDueHours:   req.NextDueHours,
	}
	if req.NextDueDate != nil {
		due, err := dto.ParseDate(*req.NextDueDate)
		if err != nil {
			return nil, err
		}
		task.NextDueDate = &due
	}
	return task, nil
}

// CreateTask handles POST /boats/{boatId}/maintenance/tasks.
func (h *MaintenanceHandler) CreateTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.CreateMaintenanceTaskRequest](w, r)
	if !ok {
		return
	}
	task, err := taskFromRequest(r, userID, req)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid next_due_date", "BAD_REQUEST")
		return
	}
	created, err := h.svc.AddTask(r.Context(), task)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusCreated, dto.MaintenanceTaskResponseFromDomain(newTaskView(created)))
}

// UpdateTask handles PUT /boats/{boatId}/maintenance/tasks/{taskId}.
func (h *MaintenanceHandler) UpdateTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.CreateMaintenanceTaskRequest](w, r)
	if !ok {
		return
	}
	task, err := taskFromRequest(r, userID, req)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid next_due_date", "BAD_REQUEST")
		return
	}
	task.ID = chi.URLParam(r, "taskId")
	updated, err := h.svc.UpdateTask(r.Context(), userID, task)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.MaintenanceTaskResponseFromDomain(newTaskView(updated)))
}

// newTaskView wraps a just-written task with the state its stored limits imply.
// The client refetches the list right after mutating, so this only has to be
// coherent, not complete (no history is read here, hence no times-done count).
func newTaskView(t *domain.MaintenanceTask) *domain.MaintenanceTaskView {
	view := &domain.MaintenanceTaskView{Task: *t, Status: domain.MaintenanceUnscheduled}
	if t.Periodic() {
		view.Status = domain.MaintenanceOK
	}
	return view
}

// CompleteTask handles POST /boats/{boatId}/maintenance/tasks/{taskId}/complete:
// the task was carried out. Writes the history entry and rolls a periodic task's
// due date forward, which is how the owner "resets" an expired task.
func (h *MaintenanceHandler) CompleteTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.CompleteMaintenanceTaskRequest](w, r)
	if !ok {
		return
	}
	completion := domain.MaintenanceCompletion{
		EngineHours: req.EngineHours,
		Cost:        req.Cost,
		Provider:    req.Provider,
		Notes:       req.Notes,
		InvoiceURL:  req.InvoiceURL,
		PhotoURLs:   req.PhotoURLs,
	}
	if req.PerformedAt != nil {
		performedAt, err := dto.ParseDate(*req.PerformedAt)
		if err != nil {
			Error(w, http.StatusBadRequest, "invalid performed_at date", "BAD_REQUEST")
			return
		}
		completion.PerformedAt = performedAt
	}
	view, err := h.svc.CompleteTask(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "taskId"), completion)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusCreated, dto.MaintenanceTaskResponseFromDomain(view))
}

// DeleteTask handles DELETE /boats/{boatId}/maintenance/tasks/{taskId}.
func (h *MaintenanceHandler) DeleteTask(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	if err := h.svc.DeleteTask(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "taskId")); err != nil {
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
		Liters:     req.Liters,
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
		Liters:     req.Liters,
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
