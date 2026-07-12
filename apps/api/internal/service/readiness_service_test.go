package service

import (
	"context"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

// mockMaintenanceRepo is a minimal port.MaintenanceRepository for readiness tests.
type mockMaintenanceRepo struct {
	logs []domain.MaintenanceLog
	err  error
}

func (m *mockMaintenanceRepo) Create(_ context.Context, l *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
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

func (m *mockMaintenanceTaskRepo) Delete(_ context.Context, _, _ string) error { return nil }

const testTaskID = "task-1"

func daysFromNow(days int) time.Time {
	return time.Now().Add(time.Duration(days) * 24 * time.Hour)
}

// monthsTask is a 12-month (by default) service task with a fixed id.
func monthsTask(months int) domain.MaintenanceTask {
	m := months
	return domain.MaintenanceTask{ID: testTaskID, Name: "Engine oil", IntervalMonths: &m}
}

func hoursTask(hours float64) domain.MaintenanceTask {
	h := hours
	return domain.MaintenanceTask{ID: testTaskID, Name: "Engine oil", IntervalHours: &h}
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
	svc := NewReadinessService(docs, maint, taskRepo(monthsTask(12)), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

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
	// Task due every 100 h, last serviced at 120 h; boat now at 230 h (>220) → overdue.
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{
		logFor(testTaskID, daysFromNow(-30), &lastHours),
	}}
	svc := NewReadinessService(docs, maint, taskRepo(hoursTask(100)), plainBoats(230), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

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

func TestReadinessService_Get_MaintenancePendingWhenNeverLogged(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)})
	// Task with an interval but no logs → pending nudge (attention, not blocking).
	maint := &mockMaintenanceRepo{}
	svc := NewReadinessService(docs, maint, taskRepo(monthsTask(12)), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessAttention {
		t.Errorf("status = %q, want attention (pending task)", r.Status)
	}
	var found bool
	for _, it := range r.Attention {
		if it.Ref == "engine_service" && it.Reason == "pending" {
			found = true
		}
	}
	if !found {
		t.Errorf("attention = %+v, want a pending engine_service item", r.Attention)
	}
}

func TestReadinessService_Get_MaintenanceNoPlanWhenNoTasks(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)})
	maint := &mockMaintenanceRepo{}
	svc := NewReadinessService(docs, maint, taskRepo(), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var found bool
	for _, it := range r.Attention {
		if it.Ref == "engine_service" && it.Reason == "no_plan" {
			found = true
		}
	}
	if !found {
		t.Errorf("attention = %+v, want a no_plan engine_service item", r.Attention)
	}
}

func TestReadinessService_Get_HistoryOnlyTaskIsIgnored(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)})
	// A task with no interval is history-only: no attention, category stays ready.
	maint := &mockMaintenanceRepo{}
	historyTask := domain.MaintenanceTask{ID: testTaskID, Name: "Hull repair"}
	svc := NewReadinessService(docs, maint, taskRepo(historyTask), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessReady {
		t.Errorf("status = %q, want ready", r.Status)
	}
	if len(r.Attention) != 0 {
		t.Errorf("attention = %+v, want 0 (history-only task)", r.Attention)
	}
}

func TestReadinessService_Get_NotReadyWhenGearExpired(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeExtinguisher, ExpiryDate: daysFromNow(-5)},
	)
	// A green maintenance task so only the extinguisher flags.
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{logFor(testTaskID, daysFromNow(-30), nil)}}
	svc := NewReadinessService(docs, maint, taskRepo(monthsTask(12)), plainBoats(0), &testutil.FakeProfileRepo{Plan: domain.PlanPro})

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
	// No tasks: on Pro this would flag a no_plan nudge, but Free must not even
	// include the maintenance category.
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
