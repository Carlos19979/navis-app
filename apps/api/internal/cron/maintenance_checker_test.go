package cron

import (
	"context"
	"log/slog"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

type mockNoticeLister struct {
	notices []domain.MaintenanceDueNotice
}

func (m *mockNoticeLister) DueNotices(_ context.Context) ([]domain.MaintenanceDueNotice, error) {
	return m.notices, nil
}

type mockMaintNotifLogRepo struct {
	existing map[string]bool // key: taskID|status|dueKey
	created  []string
}

func (m *mockMaintNotifLogRepo) key(taskID, status, dueKey string) string {
	return taskID + "|" + status + "|" + dueKey
}

func (m *mockMaintNotifLogRepo) Exists(_ context.Context, _, taskID, status, dueKey string) (bool, error) {
	return m.existing[m.key(taskID, status, dueKey)], nil
}

func (m *mockMaintNotifLogRepo) Create(_ context.Context, _, taskID, status, dueKey string) error {
	m.created = append(m.created, m.key(taskID, status, dueKey))
	return nil
}

func dueNotice(status domain.MaintenanceTaskStatus) domain.MaintenanceDueNotice {
	due := time.Now().AddDate(0, 0, 10)
	return domain.MaintenanceDueNotice{
		TaskID:      "task-1",
		TaskName:    "Engine oil",
		BoatID:      "boat-1",
		BoatName:    "Aurora",
		OwnerID:     "user-1",
		Status:      status,
		NextDueDate: &due,
		DueDays:     10,
		DueKey:      due.Format("2006-01-02"),
	}
}

func TestMaintenanceChecker_NotifiesProOwner(t *testing.T) {
	t.Parallel()
	notifier := &testutil.FakeNotificationProvider{}
	logs := &mockMaintNotifLogRepo{existing: map[string]bool{}}
	mc := NewMaintenanceChecker(
		&mockNoticeLister{notices: []domain.MaintenanceDueNotice{dueNotice(domain.MaintenanceCritical)}},
		logs,
		&testutil.FakeProfileRepo{Plan: domain.PlanPro},
		notifier,
		slog.Default(),
	)

	mc.check(context.Background())

	if len(notifier.Triggered) != 1 {
		t.Fatalf("triggered = %d, want 1", len(notifier.Triggered))
	}
	tw := notifier.Triggered[0]
	if tw.Payload["type"] != "boat" || tw.Payload["id"] != tw.Payload["boat_id"] {
		t.Errorf("deep link = %v/%v, want boat/%v",
			tw.Payload["type"], tw.Payload["id"], tw.Payload["boat_id"])
	}
	if tw.WorkflowID != "reminders" {
		t.Errorf("workflow = %q, want reminders", tw.WorkflowID)
	}
	if tw.SubscriberID != "user-1" {
		t.Errorf("subscriber = %q, want user-1", tw.SubscriberID)
	}
	if len(logs.created) != 1 {
		t.Errorf("dedup log entries = %d, want 1", len(logs.created))
	}
}

func TestMaintenanceChecker_SkipsFreeOwner(t *testing.T) {
	t.Parallel()
	notifier := &testutil.FakeNotificationProvider{}
	mc := NewMaintenanceChecker(
		&mockNoticeLister{notices: []domain.MaintenanceDueNotice{dueNotice(domain.MaintenanceExpired)}},
		&mockMaintNotifLogRepo{existing: map[string]bool{}},
		&testutil.FakeProfileRepo{Plan: domain.PlanFree},
		notifier,
		slog.Default(),
	)

	mc.check(context.Background())

	if len(notifier.Triggered) != 0 {
		t.Errorf("triggered = %d, want 0 (Free owners are skipped)", len(notifier.Triggered))
	}
}

func TestMaintenanceChecker_DedupsSameOccurrence(t *testing.T) {
	t.Parallel()
	n := dueNotice(domain.MaintenanceCritical)
	notifier := &testutil.FakeNotificationProvider{}
	logs := &mockMaintNotifLogRepo{existing: map[string]bool{
		"task-1|critical|" + n.DueKey: true,
	}}
	mc := NewMaintenanceChecker(
		&mockNoticeLister{notices: []domain.MaintenanceDueNotice{n}},
		logs,
		&testutil.FakeProfileRepo{Plan: domain.PlanPro},
		notifier,
		slog.Default(),
	)

	mc.check(context.Background())

	if len(notifier.Triggered) != 0 {
		t.Errorf("triggered = %d, want 0 (already sent for this occurrence)", len(notifier.Triggered))
	}
}

func TestBuildMaintenanceMessage_Variants(t *testing.T) {
	t.Parallel()
	n := dueNotice(domain.MaintenanceCritical)
	title, body := buildMaintenanceMessage(n)
	if title != "Mantenimiento proximo: Engine oil" {
		t.Errorf("title = %q", title)
	}
	if body == "" {
		t.Error("body empty")
	}

	n.Status = domain.MaintenanceExpired
	n.DueDays = -5
	title, _ = buildMaintenanceMessage(n)
	if title != "Mantenimiento vencido: Engine oil" {
		t.Errorf("overdue title = %q", title)
	}
}
