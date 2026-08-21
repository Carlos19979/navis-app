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
	maint    port.MaintenanceRepository
	tasks    port.MaintenanceTaskRepository
	exp      port.ExpenseRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
	notifier *Notifier
	txm      port.TxManager
	now      func() time.Time
}

// NewMaintenanceService creates a new MaintenanceService.
func NewMaintenanceService(maint port.MaintenanceRepository, tasks port.MaintenanceTaskRepository, exp port.ExpenseRepository, boats port.BoatRepository, profiles port.ProfileRepository, notifier *Notifier, txm port.TxManager) *MaintenanceService {
	return &MaintenanceService{maint: maint, tasks: tasks, exp: exp, boats: boats, profiles: profiles, notifier: notifier, txm: txm, now: time.Now}
}

// withinTx runs fn inside a transaction when a TxManager is configured, and
// plainly otherwise (unit tests wire the service without one).
func (s *MaintenanceService) withinTx(ctx context.Context, fn func(ctx context.Context) error) error {
	if s.txm == nil {
		return fn(ctx)
	}
	return s.txm.WithinTx(ctx, fn)
}

// maxLogPhotos is the hard cap of photos per maintenance log (any plan).
const maxLogPhotos = 10

// checkLogPhotos normalizes the photo list and enforces the per-plan
// attachment quota (Free = 1 photo per log, Pro unlimited up to the cap).
func (s *MaintenanceService) checkLogPhotos(ctx context.Context, log *domain.MaintenanceLog) error {
	if log.PhotoURLs == nil {
		log.PhotoURLs = []string{}
	}
	if len(log.PhotoURLs) > maxLogPhotos {
		return &domain.ValidationError{Field: "photo_urls", Message: "at most 10 photos per log"}
	}
	if s.profiles == nil || len(log.PhotoURLs) == 0 {
		return nil
	}
	profile, err := s.profiles.GetOrCreate(ctx, log.UserID)
	if err != nil {
		return err
	}
	limit := profile.Plan.AttachmentLimit()
	if limit != domain.Unlimited && len(log.PhotoURLs) > limit {
		return domain.ErrPlanLimit
	}
	return nil
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
	if err := s.checkLogPhotos(ctx, log); err != nil {
		return nil, fmt.Errorf("add maintenance: %w", err)
	}
	created, err := s.maint.Create(ctx, log)
	if err != nil {
		return nil, err
	}
	s.notifyMaintenanceLogged(ctx, log.UserID, log.BoatID, log.Type)
	return created, nil
}

// notifyMaintenanceLogged tells the rest of the boat's crew that a job was
// carried out. Fire-and-forget: a notifier hiccup must not fail the record.
func (s *MaintenanceService) notifyMaintenanceLogged(ctx context.Context, userID, boatID, what string) {
	if s.notifier == nil || boatID == "" {
		return
	}
	var ids []string
	if boat, err := s.boats.GetByIDAccessible(ctx, userID, boatID); err == nil {
		ids = append(ids, boat.UserID)
	}
	if members, err := s.boats.ListMembers(ctx, boatID); err == nil {
		for i := range members {
			ids = append(ids, members[i].UserID)
		}
	}
	name := s.notifier.UserName(ctx, userID)
	body := fmt.Sprintf("%s ha registrado un mantenimiento", name)
	if what != "" {
		body = fmt.Sprintf("%s ha registrado: %s", name, what)
	}
	s.notifier.SendMany(ctx, ids, userID, WorkflowMaintenanceLogged,
		"Mantenimiento registrado", body, "boat", boatID)
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
	if err := s.checkLogPhotos(ctx, log); err != nil {
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

// AddTask creates a maintenance task (owner or editor member). A periodic task
// always leaves here with the limits it will be judged by: an owner who only
// said "every 12 months" gets a due date a year out, so the task can warn from
// day one instead of sitting silent until its first service.
func (s *MaintenanceService) AddTask(ctx context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	if err := s.validateTask(t); err != nil {
		return nil, err
	}
	if err := s.assertMaintenance(ctx, t.UserID, t.BoatID); err != nil {
		return nil, fmt.Errorf("add maintenance task: %w", err)
	}
	if err := s.seedTaskLimits(ctx, t); err != nil {
		return nil, fmt.Errorf("add maintenance task: %w", err)
	}
	return s.tasks.Create(ctx, t)
}

// validateTask enforces the invariants the kind implies: a periodic task needs
// at least one interval to roll by, a one-off task carries no schedule at all.
func (s *MaintenanceService) validateTask(t *domain.MaintenanceTask) error {
	if t.Name == "" {
		return &domain.ValidationError{Field: "name", Message: "name is required"}
	}
	switch t.Kind {
	case domain.MaintenanceKindPeriodic:
		if t.IntervalMonths == nil && t.IntervalHours == nil {
			return &domain.ValidationError{
				Field:   "interval_months",
				Message: "a periodic task needs an interval in months or engine hours",
			}
		}
	case domain.MaintenanceKindOneOff:
		t.IntervalMonths, t.IntervalHours = nil, nil
		t.NextDueDate, t.NextDueHours = nil, nil
	default:
		return &domain.ValidationError{Field: "kind", Message: "unknown task kind"}
	}
	return nil
}

// seedTaskLimits fills in whichever limit the caller left out, so a periodic
// task is never stored without something to expire against.
func (s *MaintenanceService) seedTaskLimits(ctx context.Context, t *domain.MaintenanceTask) error {
	if !t.Periodic() {
		return nil
	}
	if t.IntervalMonths != nil && t.NextDueDate == nil {
		due := s.now().AddDate(0, *t.IntervalMonths, 0)
		t.NextDueDate = &due
	}
	if t.IntervalHours != nil && t.NextDueHours == nil {
		boat, err := s.boats.GetByIDAccessible(ctx, t.UserID, t.BoatID)
		if err != nil {
			return err
		}
		next := boat.EngineHours + *t.IntervalHours
		t.NextDueHours = &next
	}
	return nil
}

// ListTasks returns a boat's maintenance tasks with their derived state (owner
// or any member).
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
	views := make([]domain.MaintenanceTaskView, len(tasks))
	for i := range tasks {
		views[i] = s.viewTask(tasks[i], logs, boat.EngineHours)
	}
	return views, nil
}

// viewTask pairs a task with its evaluated state and its own history count.
func (s *MaintenanceService) viewTask(t domain.MaintenanceTask, logs []domain.MaintenanceLog, engineHours float64) domain.MaintenanceTaskView {
	ev := evaluateTask(t, logsForTask(logs, t.ID), engineHours, s.now())
	return domain.MaintenanceTaskView{
		Task:            t,
		Status:          ev.Status,
		LastPerformedAt: ev.LastPerformedAt,
		LastEngineHours: ev.LastEngineHours,
		DueDays:         ev.DueDays,
		HoursUntilDue:   ev.HoursUntilDue,
		TimesDone:       ev.TimesDone,
	}
}

// DueNotices evaluates every task across all boats and returns the ones close to
// or past their due date, with the owner/boat context and a DueKey pinning the
// concrete occurrence — the maintenance-due reminder cron's input.
func (s *MaintenanceService) DueNotices(ctx context.Context) ([]domain.MaintenanceDueNotice, error) {
	rows, err := s.tasks.ListAllWithLatest(ctx)
	if err != nil {
		return nil, fmt.Errorf("due notices: %w", err)
	}
	now := s.now()
	var out []domain.MaintenanceDueNotice
	for _, r := range rows {
		ev := evaluateTask(r.Task, nil, r.EngineHours, now)
		// A reminder 90 days out is noise: notify from the 30-day mark on, the
		// same window the previous "due soon" reminder used.
		if ev.Status != domain.MaintenanceCritical && ev.Status != domain.MaintenanceExpired {
			continue
		}
		// DueKey pins the occurrence: servicing the task moves the due date, so
		// the same status opens a fresh dedup slot and notifies again.
		key := "n/a"
		switch {
		case r.Task.NextDueDate != nil:
			key = r.Task.NextDueDate.Format("2006-01-02")
		case r.Task.NextDueHours != nil:
			key = fmt.Sprintf("h%.0f", *r.Task.NextDueHours)
		}
		out = append(out, domain.MaintenanceDueNotice{
			TaskID:        r.Task.ID,
			TaskName:      r.Task.Name,
			BoatID:        r.Task.BoatID,
			BoatName:      r.BoatName,
			OwnerID:       r.OwnerID,
			Status:        ev.Status,
			NextDueDate:   r.Task.NextDueDate,
			DueDays:       ev.DueDays,
			HoursUntilDue: ev.HoursUntilDue,
			DueKey:        key,
		})
	}
	return out, nil
}

// UpdateTask edits a maintenance task (owner or editor member). The due date is
// part of the payload: correcting "the antifouling is actually due in April" is
// a plain edit, not something to be re-derived from history.
func (s *MaintenanceService) UpdateTask(ctx context.Context, userID string, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	if err := s.validateTask(t); err != nil {
		return nil, err
	}
	if err := s.assertMaintenance(ctx, userID, t.BoatID); err != nil {
		return nil, fmt.Errorf("update maintenance task: %w", err)
	}
	if err := s.seedTaskLimits(ctx, t); err != nil {
		return nil, fmt.Errorf("update maintenance task: %w", err)
	}
	return s.tasks.Update(ctx, t)
}

// CompleteTask records that a task was carried out. One call writes the history
// entry and rolls a periodic task's limits past it, in one transaction — the
// client used to stitch a log and a schedule update together itself and could
// leave one without the other.
func (s *MaintenanceService) CompleteTask(ctx context.Context, userID, boatID, taskID string, c domain.MaintenanceCompletion) (*domain.MaintenanceTaskView, error) {
	if err := s.assertMaintenance(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("complete maintenance task: %w", err)
	}
	boat, err := s.boats.GetByIDAccessible(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("complete maintenance task: %w", err)
	}
	task, err := s.tasks.GetByID(ctx, boatID, taskID)
	if err != nil {
		return nil, fmt.Errorf("complete maintenance task: %w", err)
	}
	if c.PerformedAt.IsZero() {
		c.PerformedAt = s.now()
	}

	entry := &domain.MaintenanceLog{
		BoatID:      boatID,
		UserID:      userID,
		TaskID:      &task.ID,
		Type:        task.Name,
		PerformedAt: c.PerformedAt,
		EngineHours: c.EngineHours,
		Cost:        c.Cost,
		Provider:    c.Provider,
		Notes:       c.Notes,
		InvoiceURL:  c.InvoiceURL,
		PhotoURLs:   c.PhotoURLs,
	}
	if err := s.checkLogPhotos(ctx, entry); err != nil {
		return nil, fmt.Errorf("complete maintenance task: %w", err)
	}

	if err := s.withinTx(ctx, func(ctx context.Context) error {
		if _, err := s.maint.Create(ctx, entry); err != nil {
			return err
		}
		rollTask(task, c, boat.EngineHours)
		if !task.Periodic() {
			return nil
		}
		_, err := s.tasks.Update(ctx, task)
		return err
	}); err != nil {
		return nil, fmt.Errorf("complete maintenance task: %w", err)
	}

	s.notifyMaintenanceLogged(ctx, userID, boatID, task.Name)

	logs, err := s.maint.ListByBoat(ctx, boatID)
	if err != nil {
		return nil, fmt.Errorf("complete maintenance task: %w", err)
	}
	view := s.viewTask(*task, logs, boat.EngineHours)
	return &view, nil
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
