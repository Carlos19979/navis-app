package service

import (
	"context"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

// mockMaintenanceRepo is a minimal port.MaintenanceRepository. Created entries
// join the list it serves, so a completed task's own history is observable.
type mockMaintenanceRepo struct {
	logs    []domain.MaintenanceLog
	created []domain.MaintenanceLog
	err     error
}

func (m *mockMaintenanceRepo) Create(_ context.Context, l *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	m.created = append(m.created, *l)
	m.logs = append(m.logs, *l)
	return l, nil
}

func (m *mockMaintenanceRepo) Update(_ context.Context, l *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	return l, nil
}

func (m *mockMaintenanceRepo) Delete(_ context.Context, _, _ string) error { return nil }

func (m *mockMaintenanceRepo) ListByBoat(_ context.Context, _ string) ([]domain.MaintenanceLog, error) {
	return m.logs, m.err
}

// mockMaintenanceTaskRepo is a minimal port.MaintenanceTaskRepository.
type mockMaintenanceTaskRepo struct {
	tasks []domain.MaintenanceTask
	err   error
}

func (m *mockMaintenanceTaskRepo) Create(_ context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	return t, nil
}

func (m *mockMaintenanceTaskRepo) Update(_ context.Context, t *domain.MaintenanceTask) (*domain.MaintenanceTask, error) {
	return t, nil
}

func (m *mockMaintenanceTaskRepo) ListByBoat(_ context.Context, _ string) ([]domain.MaintenanceTask, error) {
	return m.tasks, m.err
}

func (m *mockMaintenanceTaskRepo) GetByID(_ context.Context, _, id string) (*domain.MaintenanceTask, error) {
	for i := range m.tasks {
		if m.tasks[i].ID == id {
			return &m.tasks[i], nil
		}
	}
	return nil, domain.ErrNotFound
}

func (m *mockMaintenanceTaskRepo) ListAllWithLatest(_ context.Context) ([]domain.MaintenanceTaskWithLatest, error) {
	out := make([]domain.MaintenanceTaskWithLatest, len(m.tasks))
	for i := range m.tasks {
		out[i] = domain.MaintenanceTaskWithLatest{Task: m.tasks[i]}
	}
	return out, nil
}

func (m *mockMaintenanceTaskRepo) Delete(_ context.Context, _, _ string) error { return nil }

const testTaskID = "task-1"

func daysFromNow(days int) time.Time {
	return time.Now().Add(time.Duration(days) * 24 * time.Hour)
}

// monthsTask is a periodic task on a month interval, due dueInDays from now.
func monthsTask(months, dueInDays int) domain.MaintenanceTask {
	m := months
	due := daysFromNow(dueInDays)
	return domain.MaintenanceTask{
		ID: testTaskID, Name: "Engine oil", Kind: domain.MaintenanceKindPeriodic,
		IntervalMonths: &m, NextDueDate: &due,
	}
}

// hoursTask is a periodic task driven only by engine hours: no due date, so its
// state comes entirely from the boat's reading against dueAtHours.
func hoursTask(interval, dueAtHours float64) domain.MaintenanceTask {
	h, due := interval, dueAtHours
	return domain.MaintenanceTask{
		ID: testTaskID, Name: "Engine oil", Kind: domain.MaintenanceKindPeriodic,
		IntervalHours: &h, NextDueHours: &due,
	}
}

// logFor builds a maintenance log linked to a task.
func logFor(taskID string, performedAt time.Time, hours *float64) domain.MaintenanceLog {
	id := taskID
	return domain.MaintenanceLog{TaskID: &id, PerformedAt: performedAt, EngineHours: hours}
}

func taskRepo(tasks ...domain.MaintenanceTask) *mockMaintenanceTaskRepo {
	return &mockMaintenanceTaskRepo{tasks: tasks}
}

func readinessDocs(docs ...domain.Document) *mockDocumentRepo {
	return &mockDocumentRepo{
		listByBoatFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Document, string, error) {
			return docs, "", nil
		},
	}
}

// plainBoats returns a boat repo whose boat carries the given engine hours.
func plainBoats(engineHours float64) *mockBoatRepo {
	return &mockBoatRepo{
		getAccessibleFn: func(_ context.Context, userID, id string) (*domain.Boat, error) {
			return &domain.Boat{ID: id, UserID: userID, EngineHours: engineHours}, nil
		},
	}
}

func TestReadinessService_Get_ReadyWhenAllValid(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)},
		domain.Document{Type: domain.DocumentTypeFlares, ExpiryDate: daysFromNow(200)},
	)
	// A 12-month task serviced 30 days ago: green.
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{logFor(testTaskID, daysFromNow(-30), nil)}}
	svc := NewReadinessService(docs, maint, taskRepo(monthsTask(12, 335)), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessReady {
		t.Errorf("status = %q, want ready", r.Status)
	}
	if r.Score != 100 {
		t.Errorf("score = %d, want 100", r.Score)
	}
	if !r.Full {
		t.Error("Full = false, want true for Pro")
	}
	if len(r.Attention) != 0 {
		t.Errorf("attention = %d items, want 0", len(r.Attention))
	}
}

func TestReadinessService_Get_MaintenanceOverdueByHours(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)},
	)
	lastHours := 120.0
	// Task due at 220 h; boat now at 230 h → past its hours limit.
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{
		logFor(testTaskID, daysFromNow(-30), &lastHours),
	}}
	svc := NewReadinessService(docs, maint, taskRepo(hoursTask(100, 220)), plainBoats(230), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessNotReady {
		t.Errorf("status = %q, want not_ready (maintenance overdue by hours)", r.Status)
	}
	var found bool
	for _, it := range r.Attention {
		if it.Ref == "engine_service" && it.Reason == "overdue" && it.Label == "Engine oil" {
			found = true
		}
	}
	if !found {
		t.Errorf("attention = %+v, want an overdue engine_service item labelled Engine oil", r.Attention)
	}
}

func TestReadinessService_Get_MaintenanceCriticalWhenDueSoon(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)})
	// A task due in 20 days, never serviced. What used to be a dateless
	// "pending" nudge is now a real date, so it flags on the same 30-day
	// threshold as a document about to expire.
	maint := &mockMaintenanceRepo{}
	svc := NewReadinessService(docs, maint, taskRepo(monthsTask(12, 20)), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessAttention {
		t.Errorf("status = %q, want attention (task due in 20 days)", r.Status)
	}
	var found bool
	for _, it := range r.Attention {
		if it.Ref == "engine_service" && it.Reason == "due_soon" {
			found = true
		}
	}
	if !found {
		t.Errorf("attention = %+v, want a due_soon engine_service item", r.Attention)
	}
}

// 90 days out costs a little score and nothing else — exactly what a document
// three months from expiry does, so maintenance reads the same as paperwork.
func TestReadinessService_Get_MaintenanceWarningCostsScoreWithoutAnItem(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)})
	maint := &mockMaintenanceRepo{}
	svc := NewReadinessService(docs, maint, taskRepo(monthsTask(12, 60)), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Score != 96 {
		t.Errorf("score = %d, want 96 (a warning costs 4)", r.Score)
	}
	if len(r.Attention) != 0 {
		t.Errorf("attention = %+v, want 0 (a warning is not a finding)", r.Attention)
	}
}

// A boat with no maintenance plan must not be penalized: defining a schedule is
// opt-in, and the old "set a plan" nudge cost 10 points, so every new boat
// opened on "needs attention · 90" with nothing the owner had done wrong.
func TestReadinessService_Get_NoMaintenancePlanIsReadyAndUnpenalized(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)})
	maint := &mockMaintenanceRepo{}
	svc := NewReadinessService(docs, maint, taskRepo(), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Score != 100 {
		t.Errorf("score = %d, want 100 (an empty plan costs nothing)", r.Score)
	}
	if r.Status != domain.ReadinessReady {
		t.Errorf("status = %q, want ready", r.Status)
	}
	if len(r.Attention) != 0 {
		t.Errorf("attention = %+v, want 0 (no plan is not a finding)", r.Attention)
	}
	var maintCat *domain.ReadinessCategory
	for i := range r.Categories {
		if r.Categories[i].Key == domain.ReadinessCatMaintenance {
			maintCat = &r.Categories[i]
		}
	}
	if maintCat == nil {
		t.Fatalf("categories = %+v, want a maintenance category", r.Categories)
	}
	// 0/0, so the breakdown reads "nothing scheduled" instead of "1 critical".
	if maintCat.Total != 0 || maintCat.OK != 0 || maintCat.Critical != 0 {
		t.Errorf("maintenance = %+v, want an empty 0/0 category", *maintCat)
	}
	if maintCat.Status != domain.ReadinessReady {
		t.Errorf("maintenance status = %q, want ready", maintCat.Status)
	}
}

func TestReadinessService_Get_OneOffTaskIsIgnored(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)})
	// A one-off job has a history and no calendar: nothing to be late for.
	maint := &mockMaintenanceRepo{}
	historyTask := domain.MaintenanceTask{
		ID: testTaskID, Name: "Hull repair", Kind: domain.MaintenanceKindOneOff,
	}
	svc := NewReadinessService(docs, maint, taskRepo(historyTask), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessReady {
		t.Errorf("status = %q, want ready", r.Status)
	}
	if len(r.Attention) != 0 {
		t.Errorf("attention = %+v, want 0 (one-off task)", r.Attention)
	}
	if r.Score != 100 {
		t.Errorf("score = %d, want 100 (a one-off task costs nothing)", r.Score)
	}
}

func TestReadinessService_Get_NotReadyWhenGearExpired(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeExtinguisher, ExpiryDate: daysFromNow(-5)},
	)
	// A green maintenance task so only the extinguisher flags.
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{logFor(testTaskID, daysFromNow(-30), nil)}}
	svc := NewReadinessService(docs, maint, taskRepo(monthsTask(12, 335)), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessNotReady {
		t.Errorf("status = %q, want not_ready", r.Status)
	}
	if len(r.Attention) != 1 || r.Attention[0].Ref != string(domain.DocumentTypeExtinguisher) {
		t.Errorf("attention = %+v, want one extinguisher item", r.Attention)
	}
}

func TestReadinessService_Get_FreePlanIsDocumentsOnly(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)},
	)
	// Free must not include the maintenance category at all.
	maint := &mockMaintenanceRepo{}
	svc := NewReadinessService(docs, maint, taskRepo(), &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanFree})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Full {
		t.Error("Full = true, want false for Free")
	}
	for _, c := range r.Categories {
		if c.Key == domain.ReadinessCatMaintenance {
			t.Error("Free plan must not include the maintenance category")
		}
	}
}
