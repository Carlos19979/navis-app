package service

import (
	"context"
	"fmt"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// MaintenanceService handles boat maintenance logs, tasks and expenses.
type MaintenanceService struct {
	maint port.MaintenanceRepository
	tasks port.MaintenanceTaskRepository
	exp   port.ExpenseRepository
	boats port.BoatRepository
	now   func() time.Time
}

// NewMaintenanceService creates a new MaintenanceService.
func NewMaintenanceService(maint port.MaintenanceRepository, tasks port.MaintenanceTaskRepository, exp port.ExpenseRepository, boats port.BoatRepository) *MaintenanceService {
	return &MaintenanceService{maint: maint, tasks: tasks, exp: exp, boats: boats, now: time.Now}
}

// assertMaintenance verifies the user may manage maintenance on the boat.
func (s *MaintenanceService) assertMaintenance(ctx context.Context, userID, boatID string) error {
	perms, ok, err := s.boats.GetPermissions(ctx, userID, boatID)
	if err != nil {
		return err
	}
	if !ok || !perms.CanManageMaintenance {
		return domain.ErrForbidden
	}
	return nil
}

// assertExpenses verifies the user may manage expenses on the boat.
func (s *MaintenanceService) assertExpenses(ctx context.Context, userID, boatID string) error {
	perms, ok, err := s.boats.GetPermissions(ctx, userID, boatID)
	if err != nil {
		return err
	}
	if !ok || !perms.CanManageExpenses {
		return domain.ErrForbidden
	}
	return nil
}

// assertRead verifies the user owns or has shared access to the boat.
func (s *MaintenanceService) assertRead(ctx context.Context, userID, boatID string) error {
	if _, err := s.boats.GetByIDAccessible(ctx, userID, boatID); err != nil {
		return err
	}
	return nil
}

// AddLog records a maintenance entry (owner or editor member).
func (s *MaintenanceService) AddLog(ctx context.Context, log *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	if log.Type == "" {
		return nil, &domain.ValidationError{Field: "type", Message: "type is required"}
	}
	if err := s.assertMaintenance(ctx, log.UserID, log.BoatID); err != nil {
		return nil, fmt.Errorf("add maintenance: %w", err)
	}
	return s.maint.Create(ctx, log)
}

// ListLogs returns a boat's maintenance logs (owner or any member).
func (s *MaintenanceService) ListLogs(ctx context.Context, userID, boatID string) ([]domain.MaintenanceLog, error) {
	if err := s.assertRead(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("list maintenance: %w", err)
	}
	return s.maint.ListByBoat(ctx, boatID)
}

// UpdateLog edits a maintenance log (owner or editor member).
func (s *MaintenanceService) UpdateLog(ctx context.Context, userID string, log *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	if log.Type == "" {
		return nil, &domain.ValidationError{Field: "type", Message: "type is required"}
	}
	if err := s.assertMaintenance(ctx, userID, log.BoatID); err != nil {
		return nil, fmt.Errorf("update maintenance: %w", err)
	}
	return s.maint.Update(ctx, log)
}

// DeleteLog removes a maintenance log (owner or editor member).
func (s *MaintenanceService) DeleteLog(ctx context.Context, userID, boatID, id string) error {
	if err := s.assertMaintenance(ctx, userID, boatID); err != nil {
		return fmt.Errorf("delete maintenance: %w", err)
	}
	return s.maint.Delete(ctx, boatID, id)
}

// AddTask creates a recurring maintenance task (owner or editor member).
func (s *MaintenanceService) AddTask(ctx context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	if t.Name == "" {
		return nil, &domain.ValidationError{Field: "name", Message: "name is required"}
	}
	if err := s.assertMaintenance(ctx, t.UserID, t.BoatID); err != nil {
		return nil, fmt.Errorf("add maintenance task: %w", err)
	}
	return s.tasks.Create(ctx, t)
}

// ListTasks returns a boat's maintenance tasks with derived due-state (owner or
// any member).
func (s *MaintenanceService) ListTasks(ctx context.Context, userID, boatID string) ([]domain.MaintenanceTaskView, error) {
	boat, err := s.boats.GetByIDAccessible(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("list maintenance tasks: %w", err)
	}
	tasks, err := s.tasks.ListByBoat(ctx, boatID)
	if err != nil {
		return nil, fmt.Errorf("list maintenance tasks: %w", err)
	}
	logs, err := s.maint.ListByBoat(ctx, boatID)
	if err != nil {
		return nil, fmt.Errorf("list maintenance tasks: %w", err)
	}
	now := s.now()
	views := make([]domain.MaintenanceTaskView, len(tasks))
	for i := range tasks {
		ev := evaluateTask(tasks[i], logsForTask(logs, tasks[i].ID), boat.EngineHours, now)
		views[i] = domain.MaintenanceTaskView{
			Task:            tasks[i],
			Status:          ev.Status,
			LastPerformedAt: ev.LastPerformedAt,
			LastEngineHours: ev.LastEngineHours,
			NextDueDate:     ev.NextDueDate,
			DueDays:         ev.DueDays,
			HoursUntilDue:   ev.HoursUntilDue,
		}
	}
	return views, nil
}

// DueNotices evaluates every task across all boats and returns the ones in
// due_soon/overdue state, with the owner/boat context and a DueKey pinning
// the concrete occurrence — the maintenance-due notification cron's input.
func (s *MaintenanceService) DueNotices(ctx context.Context) ([]domain.MaintenanceDueNotice, error) {
	rows, err := s.tasks.ListAllWithLatest(ctx)
	if err != nil {
		return nil, fmt.Errorf("due notices: %w", err)
	}
	now := s.now()
	var out []domain.MaintenanceDueNotice
	for _, r := range rows {
		var logs []domain.MaintenanceLog
		if r.LastPerformedAt != nil {
			logs = []domain.MaintenanceLog{{
				PerformedAt: *r.LastPerformedAt,
				EngineHours: r.LastEngineHours,
			}}
		}
		ev := evaluateTask(r.Task, logs, r.EngineHours, now)
		if ev.Status != domain.MaintenanceDueSoon && ev.Status != domain.MaintenanceOverdue {
			continue
		}
		// DueKey pins the occurrence: after servicing, the next due date /
		// hours threshold changes and the same status notifies again.
		key := "n/a"
		switch {
		case ev.NextDueDate != nil:
			key = ev.NextDueDate.Format("2006-01-02")
		case ev.HoursUntilDue != nil && r.LastEngineHours != nil && r.Task.IntervalHours != nil:
			key = fmt.Sprintf("h%.0f", *r.LastEngineHours+*r.Task.IntervalHours)
		}
		out = append(out, domain.MaintenanceDueNotice{
			TaskID:        r.Task.ID,
			TaskName:      r.Task.Name,
			BoatID:        r.Task.BoatID,
			BoatName:      r.BoatName,
			OwnerID:       r.OwnerID,
			Status:        ev.Status,
			NextDueDate:   ev.NextDueDate,
			DueDays:       ev.DueDays,
			HoursUntilDue: ev.HoursUntilDue,
			DueKey:        key,
		})
	}
	return out, nil
}

// UpdateTask edits a maintenance task (owner or editor member).
func (s *MaintenanceService) UpdateTask(ctx context.Context, userID string, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	if t.Name == "" {
		return nil, &domain.ValidationError{Field: "name", Message: "name is required"}
	}
	if err := s.assertMaintenance(ctx, userID, t.BoatID); err != nil {
		return nil, fmt.Errorf("update maintenance task: %w", err)
	}
	return s.tasks.Update(ctx, t)
}

// DeleteTask removes a maintenance task; its history survives (owner or editor).
func (s *MaintenanceService) DeleteTask(ctx context.Context, userID, boatID, id string) error {
	if err := s.assertMaintenance(ctx, userID, boatID); err != nil {
		return fmt.Errorf("delete maintenance task: %w", err)
	}
	return s.tasks.Delete(ctx, boatID, id)
}

// AddExpense records an expense (owner or editor member).
func (s *MaintenanceService) AddExpense(ctx context.Context, e *domain.Expense) (*domain.Expense, error) {
	if e.Category == "" {
		return nil, &domain.ValidationError{Field: "category", Message: "category is required"}
	}
	if err := s.assertExpenses(ctx, e.UserID, e.BoatID); err != nil {
		return nil, fmt.Errorf("add expense: %w", err)
	}
	return s.exp.Create(ctx, e)
}

// ListExpenses returns a boat's expenses (owner or any member).
func (s *MaintenanceService) ListExpenses(ctx context.Context, userID, boatID string) ([]domain.Expense, error) {
	if err := s.assertRead(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("list expenses: %w", err)
	}
	return s.exp.ListByBoat(ctx, boatID)
}

// UpdateExpense edits an expense (owner or editor member).
func (s *MaintenanceService) UpdateExpense(ctx context.Context, userID string, e *domain.Expense) (*domain.Expense, error) {
	if e.Category == "" {
		return nil, &domain.ValidationError{Field: "category", Message: "category is required"}
	}
	if err := s.assertExpenses(ctx, userID, e.BoatID); err != nil {
		return nil, fmt.Errorf("update expense: %w", err)
	}
	return s.exp.Update(ctx, e)
}

// DeleteExpense removes an expense (owner or editor member).
func (s *MaintenanceService) DeleteExpense(ctx context.Context, userID, boatID, id string) error {
	if err := s.assertExpenses(ctx, userID, boatID); err != nil {
		return fmt.Errorf("delete expense: %w", err)
	}
	return s.exp.Delete(ctx, boatID, id)
}

// ExpenseTotals returns summed expenses per category (owner or any member).
func (s *MaintenanceService) ExpenseTotals(ctx context.Context, userID, boatID string) (map[string]float64, error) {
	if err := s.assertRead(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("expense totals: %w", err)
	}
	return s.exp.TotalsByCategory(ctx, boatID)
}
