package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

func newTestLog(photos []string) *domain.MaintenanceLog {
	return &domain.MaintenanceLog{
		BoatID:      "boat-1",
		UserID:      "user-1",
		Type:        "oil change",
		PerformedAt: time.Now(),
		PhotoURLs:   photos,
	}
}

func newMaintSvc(plan domain.Plan) *MaintenanceService {
	return NewMaintenanceService(
		&mockMaintenanceRepo{},
		&mockMaintenanceTaskRepo{},
		&mockExpenseRepo{},
		&mockBoatRepo{},
		&testutil.FakeProfileRepo{Plan: plan},
		nil,
		nil,
	)
}

// maintSvcWith wires the service over specific maintenance repos so a test can
// inspect what was written.
func maintSvcWith(maint *mockMaintenanceRepo, tasks *mockMaintenanceTaskRepo) *MaintenanceService {
	return NewMaintenanceService(
		maint, tasks, &mockExpenseRepo{},
		plainBoats(150),
		&testutil.FakeProfileRepo{Plan: domain.PlanPro},
		nil, nil,
	)
}

func urls(n int) []string {
	out := make([]string, n)
	for i := range n {
		out[i] = "https://storage.example.com/p.jpg"
	}
	return out
}

func TestMaintenanceService_AddLog_NormalizesNilPhotos(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	created, err := svc.AddLog(context.Background(), newTestLog(nil))
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if created.PhotoURLs == nil {
		t.Error("expected photo urls normalized to an empty slice, got nil")
	}
}

func TestMaintenanceService_AddLog_FreeAllowsOnePhoto(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	created, err := svc.AddLog(context.Background(), newTestLog(urls(1)))
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(created.PhotoURLs) != 1 {
		t.Errorf("expected 1 photo, got %d", len(created.PhotoURLs))
	}
}

func TestMaintenanceService_AddLog_FreeSecondPhotoHitsPlanLimit(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	_, err := svc.AddLog(context.Background(), newTestLog(urls(2)))
	if !errors.Is(err, domain.ErrPlanLimit) {
		t.Fatalf("expected ErrPlanLimit, got %v", err)
	}
}

func TestMaintenanceService_AddLog_ProAllowsManyPhotos(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanPro)
	created, err := svc.AddLog(context.Background(), newTestLog(urls(10)))
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(created.PhotoURLs) != 10 {
		t.Errorf("expected 10 photos, got %d", len(created.PhotoURLs))
	}
}

func TestMaintenanceService_AddLog_HardCapOverflow(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanPro)
	_, err := svc.AddLog(context.Background(), newTestLog(urls(11)))
	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
	if ve.Field != "photo_urls" {
		t.Errorf("expected field %q, got %q", "photo_urls", ve.Field)
	}
}

func TestMaintenanceService_UpdateLog_FreeSecondPhotoHitsPlanLimit(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	log := newTestLog(urls(2))
	log.ID = "log-1"
	_, err := svc.UpdateLog(context.Background(), "user-1", log)
	if !errors.Is(err, domain.ErrPlanLimit) {
		t.Fatalf("expected ErrPlanLimit, got %v", err)
	}
}

func TestMaintenanceService_UpdateLog_ProPhotosOK(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanPro)
	log := newTestLog(urls(4))
	log.ID = "log-1"
	updated, err := svc.UpdateLog(context.Background(), "user-1", log)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(updated.PhotoURLs) != 4 {
		t.Errorf("expected 4 photos, got %d", len(updated.PhotoURLs))
	}
}

// A periodic task must leave the service with a date to expire against: an
// owner who only says "every 12 months" used to get a task that sat silent
// forever, because the due date was derived from a service that never happened.
func TestMaintenanceService_AddTask_SeedsDueDateFromInterval(t *testing.T) {
	t.Parallel()
	months := 12
	svc := maintSvcWith(&mockMaintenanceRepo{}, &mockMaintenanceTaskRepo{})

	created, err := svc.AddTask(context.Background(), &domain.MaintenanceTask{
		BoatID: "boat-1", UserID: "user-1", Name: "Anodes",
		Kind: domain.MaintenanceKindPeriodic, IntervalMonths: &months,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if created.NextDueDate == nil {
		t.Fatal("next due date = nil, want a year from now")
	}
	if got := daysBetween(time.Now(), *created.NextDueDate); got < 364 || got > 366 {
		t.Errorf("due in %d days, want ~365", got)
	}
}

// The engine-hours limit is seeded off the boat's current reading, so a task
// created at 150 h with a 100 h interval is due at 250 h.
func TestMaintenanceService_AddTask_SeedsDueHoursFromBoat(t *testing.T) {
	t.Parallel()
	interval := 100.0
	svc := maintSvcWith(&mockMaintenanceRepo{}, &mockMaintenanceTaskRepo{})

	created, err := svc.AddTask(context.Background(), &domain.MaintenanceTask{
		BoatID: "boat-1", UserID: "user-1", Name: "Engine oil",
		Kind: domain.MaintenanceKindPeriodic, IntervalHours: &interval,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if created.NextDueHours == nil || *created.NextDueHours != 250 {
		t.Errorf("next due hours = %v, want 250", created.NextDueHours)
	}
}

func TestMaintenanceService_AddTask_PeriodicWithoutIntervalIsRejected(t *testing.T) {
	t.Parallel()
	svc := maintSvcWith(&mockMaintenanceRepo{}, &mockMaintenanceTaskRepo{})

	_, err := svc.AddTask(context.Background(), &domain.MaintenanceTask{
		BoatID: "boat-1", UserID: "user-1", Name: "Anodes",
		Kind: domain.MaintenanceKindPeriodic,
	})
	if !errors.Is(err, domain.ErrValidation) {
		t.Errorf("err = %v, want a validation error", err)
	}
}

// A one-off job carries no schedule, whatever the payload claims.
func TestMaintenanceService_AddTask_OneOffDropsSchedule(t *testing.T) {
	t.Parallel()
	months := 12
	due := time.Now()
	svc := maintSvcWith(&mockMaintenanceRepo{}, &mockMaintenanceTaskRepo{})

	created, err := svc.AddTask(context.Background(), &domain.MaintenanceTask{
		BoatID: "boat-1", UserID: "user-1", Name: "Hull repair",
		Kind: domain.MaintenanceKindOneOff, IntervalMonths: &months, NextDueDate: &due,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if created.IntervalMonths != nil || created.NextDueDate != nil {
		t.Errorf("one-off kept a schedule: %+v", created)
	}
}

// The whole point of the rework: marking an expired task done writes its history
// entry AND moves the due date past it, in one call.
func TestMaintenanceService_CompleteTask_WritesHistoryAndRollsDueDate(t *testing.T) {
	t.Parallel()
	months := 6
	overdue := time.Now().AddDate(0, 0, -40)
	maint := &mockMaintenanceRepo{}
	tasks := &mockMaintenanceTaskRepo{tasks: []domain.MaintenanceTask{{
		ID: testTaskID, BoatID: "boat-1", Name: "Anodes",
		Kind: domain.MaintenanceKindPeriodic, IntervalMonths: &months, NextDueDate: &overdue,
	}}}
	svc := maintSvcWith(maint, tasks)
	performed := time.Now()

	view, err := svc.CompleteTask(context.Background(), "user-1", "boat-1", testTaskID,
		domain.MaintenanceCompletion{PerformedAt: performed})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(maint.created) != 1 {
		t.Fatalf("history entries = %d, want 1", len(maint.created))
	}
	entry := maint.created[0]
	if entry.TaskID == nil || *entry.TaskID != testTaskID {
		t.Errorf("history entry task = %v, want %s", entry.TaskID, testTaskID)
	}
	if entry.Type != "Anodes" {
		t.Errorf("history entry type = %q, want the task name", entry.Type)
	}
	want := performed.AddDate(0, months, 0)
	if view.Task.NextDueDate == nil || !view.Task.NextDueDate.Equal(want) {
		t.Errorf("next due = %v, want %v", view.Task.NextDueDate, want)
	}
	if view.Status != domain.MaintenanceOK {
		t.Errorf("status = %q, want ok after servicing", view.Status)
	}
	if view.TimesDone != 1 {
		t.Errorf("times done = %d, want 1", view.TimesDone)
	}
}

// Completing without a date means "done today" — the one-tap path.
func TestMaintenanceService_CompleteTask_DefaultsToToday(t *testing.T) {
	t.Parallel()
	months := 12
	due := time.Now()
	maint := &mockMaintenanceRepo{}
	tasks := &mockMaintenanceTaskRepo{tasks: []domain.MaintenanceTask{{
		ID: testTaskID, BoatID: "boat-1", Name: "Anodes",
		Kind: domain.MaintenanceKindPeriodic, IntervalMonths: &months, NextDueDate: &due,
	}}}
	svc := maintSvcWith(maint, tasks)

	if _, err := svc.CompleteTask(context.Background(), "user-1", "boat-1", testTaskID,
		domain.MaintenanceCompletion{}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(maint.created) != 1 {
		t.Fatalf("history entries = %d, want 1", len(maint.created))
	}
	if got := daysBetween(time.Now(), maint.created[0].PerformedAt); got != 0 {
		t.Errorf("performed %d days from today, want today", got)
	}
}

// A one-off job accumulates history and never grows a due date.
func TestMaintenanceService_CompleteTask_OneOffStaysUnscheduled(t *testing.T) {
	t.Parallel()
	maint := &mockMaintenanceRepo{}
	tasks := &mockMaintenanceTaskRepo{tasks: []domain.MaintenanceTask{{
		ID: testTaskID, BoatID: "boat-1", Name: "Hull repair",
		Kind: domain.MaintenanceKindOneOff,
	}}}
	svc := maintSvcWith(maint, tasks)

	view, err := svc.CompleteTask(context.Background(), "user-1", "boat-1", testTaskID,
		domain.MaintenanceCompletion{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if view.Task.NextDueDate != nil {
		t.Errorf("next due = %v, want none for a one-off", view.Task.NextDueDate)
	}
	if view.Status != domain.MaintenanceUnscheduled {
		t.Errorf("status = %q, want unscheduled", view.Status)
	}
}

// Only tasks within 30 days of their date (or past it) are worth a push.
func TestMaintenanceService_DueNotices_SkipsWhatIsStillFarOff(t *testing.T) {
	t.Parallel()
	months := 12
	soon := time.Now().AddDate(0, 0, 10)
	far := time.Now().AddDate(0, 0, 200)
	tasks := &mockMaintenanceTaskRepo{tasks: []domain.MaintenanceTask{
		{ID: "task-soon", Name: "Anodes", Kind: domain.MaintenanceKindPeriodic, IntervalMonths: &months, NextDueDate: &soon},
		{ID: "task-far", Name: "Antifouling", Kind: domain.MaintenanceKindPeriodic, IntervalMonths: &months, NextDueDate: &far},
	}}
	svc := maintSvcWith(&mockMaintenanceRepo{}, tasks)

	notices, err := svc.DueNotices(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(notices) != 1 || notices[0].TaskID != "task-soon" {
		t.Fatalf("notices = %+v, want only task-soon", notices)
	}
	// The key is the occurrence, so servicing it opens a fresh dedup slot.
	if notices[0].DueKey != soon.Format("2006-01-02") {
		t.Errorf("due key = %q, want the due date", notices[0].DueKey)
	}
}
