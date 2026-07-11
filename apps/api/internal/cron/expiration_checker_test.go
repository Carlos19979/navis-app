package cron

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// --- Mocks ---

type mockDocRepo struct {
	listExpiringFn func(ctx context.Context, withinDays int) ([]domain.Document, error)
}

func (m *mockDocRepo) Create(ctx context.Context, doc *domain.Document) (*domain.Document, error) {
	return nil, nil
}
func (m *mockDocRepo) GetByID(ctx context.Context, userID, id string) (*domain.Document, error) {
	return nil, nil
}
func (m *mockDocRepo) List(ctx context.Context, userID, cursor string, limit int) ([]domain.Document, string, error) {
	return nil, "", nil
}
func (m *mockDocRepo) ListByBoat(ctx context.Context, boatID, cursor string, limit int) ([]domain.Document, string, error) {
	return nil, "", nil
}
func (m *mockDocRepo) ListExpiring(ctx context.Context, withinDays int) ([]domain.Document, error) {
	return m.listExpiringFn(ctx, withinDays)
}
func (m *mockDocRepo) Update(ctx context.Context, doc *domain.Document) (*domain.Document, error) {
	return nil, nil
}
func (m *mockDocRepo) Delete(ctx context.Context, boatID, id string) error { return nil }

type mockNotifLogRepo struct {
	existsFn func(ctx context.Context, userID, docID string, daysBefore int) (bool, error)
	createFn func(ctx context.Context, userID, docID string, daysBefore int) error
}

func (m *mockNotifLogRepo) Exists(ctx context.Context, userID, docID string, daysBefore int) (bool, error) {
	return m.existsFn(ctx, userID, docID, daysBefore)
}
func (m *mockNotifLogRepo) Create(ctx context.Context, userID, docID string, daysBefore int) error {
	return m.createFn(ctx, userID, docID, daysBefore)
}

type mockNotifier struct {
	triggerFn func(ctx context.Context, workflowID, subscriberID string, payload map[string]any) error
	triggered []triggeredWorkflow
}

type triggeredWorkflow struct {
	WorkflowID   string
	SubscriberID string
	Payload      map[string]any
}

func (m *mockNotifier) TriggerWorkflow(ctx context.Context, workflowID, subscriberID string, payload map[string]any) error {
	m.triggered = append(m.triggered, triggeredWorkflow{workflowID, subscriberID, payload})
	if m.triggerFn != nil {
		return m.triggerFn(ctx, workflowID, subscriberID, payload)
	}
	return nil
}

func (m *mockNotifier) EnsureSubscriber(_ context.Context, _ string) error   { return nil }
func (m *mockNotifier) SetPushToken(_ context.Context, _, _ string) error    { return nil }
func (m *mockNotifier) RemovePushToken(_ context.Context, _, _ string) error { return nil }

// mockProfileRepo returns a fixed plan for every user (default: Pro, so existing
// tests keep notifying every document).
type mockProfileRepo struct {
	plan domain.Plan
}

func (m *mockProfileRepo) GetOrCreate(_ context.Context, userID string) (*domain.Profile, error) {
	plan := m.plan
	if plan == "" {
		plan = domain.PlanPro
	}
	return &domain.Profile{UserID: userID, Plan: plan}, nil
}
func (m *mockProfileRepo) SetPlan(_ context.Context, userID string, plan domain.Plan) (*domain.Profile, error) {
	return &domain.Profile{UserID: userID, Plan: plan}, nil
}

// --- Helpers ---

func newTestChecker(
	docs *mockDocRepo,
	notifLogs *mockNotifLogRepo,
	notifier *mockNotifier,
) *ExpirationChecker {
	return New(docs, notifLogs, &mockProfileRepo{plan: domain.PlanPro}, notifier, slog.Default())
}

func docExpiringIn(id, userID string, days int, alertDays []int) domain.Document {
	return domain.Document{
		ID:         id,
		UserID:     userID,
		BoatID:     "boat-1",
		Type:       domain.DocumentTypeITB,
		ExpiryDate: time.Now().Add(time.Duration(days) * 24 * time.Hour),
		AlertDays:  alertDays,
	}
}

// --- Tests ---

func TestExpirationChecker_Check_TriggersWorkflows(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}
	var loggedDocID string
	var loggedAlertDay int

	ec := newTestChecker(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return []domain.Document{
					docExpiringIn("doc-1", "user-1", 5, []int{30, 7}),
				}, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, docID string, alertDay int) error {
				loggedDocID = docID
				loggedAlertDay = alertDay
				return nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.triggered) != 2 {
		t.Fatalf("expected 2 workflow triggers (2 alert days), got %d", len(notifier.triggered))
	}
	if notifier.triggered[0].WorkflowID != "document-expiry" {
		t.Errorf("expected workflow 'document-expiry', got %s", notifier.triggered[0].WorkflowID)
	}
	if notifier.triggered[0].SubscriberID != "user-1" {
		t.Errorf("expected subscriber user-1, got %s", notifier.triggered[0].SubscriberID)
	}
	if loggedDocID != "doc-1" {
		t.Errorf("expected notification log for doc-1, got %s", loggedDocID)
	}
	if loggedAlertDay != 7 {
		t.Errorf("expected last alert day 7, got %d", loggedAlertDay)
	}
}

func TestExpirationChecker_Check_SkipsAlreadyNotified(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}

	ec := newTestChecker(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return []domain.Document{
					docExpiringIn("doc-1", "user-1", 5, []int{30, 7}),
				}, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return true, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.triggered) != 0 {
		t.Fatalf("expected 0 triggers (already notified), got %d", len(notifier.triggered))
	}
}

func TestExpirationChecker_Check_RespectsAlertDays(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}

	ec := newTestChecker(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return []domain.Document{
					docExpiringIn("doc-1", "user-1", 60, []int{30, 7}),
				}, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.triggered) != 0 {
		t.Fatalf("expected 0 triggers (60 days > all alert days), got %d", len(notifier.triggered))
	}
}

func TestExpirationChecker_Check_NoExpiringDocs(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}

	ec := newTestChecker(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return nil, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.triggered) != 0 {
		t.Fatalf("expected 0 triggers, got %d", len(notifier.triggered))
	}
}

func TestExpirationChecker_Check_ListExpiringError(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}

	ec := newTestChecker(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return nil, errors.New("db connection lost")
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.triggered) != 0 {
		t.Fatalf("expected 0 triggers on error, got %d", len(notifier.triggered))
	}
}

func TestExpirationChecker_Check_ExpiredDocument(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}

	ec := newTestChecker(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return []domain.Document{
					docExpiringIn("doc-1", "user-1", -2, []int{30, 7}),
				}, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.triggered) == 0 {
		t.Fatal("expected workflow trigger for expired document")
	}
	title, _ := notifier.triggered[0].Payload["title"].(string)
	if title != "Document Expired" {
		t.Errorf("expected 'Document Expired' title, got %q", title)
	}
}

func TestExpirationChecker_Check_FreePlanLimitsToNearestDoc(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}
	// Free user with three expiring documents; only the nearest (doc-near, 3d)
	// should notify. A separate Pro user's document still notifies.
	ec := New(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return []domain.Document{
					docExpiringIn("doc-far", "free-user", 40, []int{30, 7}),
					docExpiringIn("doc-near", "free-user", 3, []int{30, 7}),
					docExpiringIn("doc-mid", "free-user", 20, []int{30, 7}),
				}, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		&mockProfileRepo{plan: domain.PlanFree},
		notifier,
		slog.Default(),
	)

	ec.check(context.Background())

	for _, tw := range notifier.triggered {
		docID, _ := tw.Payload["document_id"].(string)
		if docID != "doc-near" {
			t.Errorf("free user should only be notified for doc-near, got %q", docID)
		}
	}
	if len(notifier.triggered) == 0 {
		t.Fatal("expected the nearest document to notify")
	}
}

func TestBuildMessage_Expiring(t *testing.T) {
	t.Parallel()

	expiry := time.Date(2026, 5, 10, 0, 0, 0, 0, time.UTC)
	title, body := buildMessage("itb", nil, 14, expiry)

	if title != "Document Expiring Soon" {
		t.Errorf("expected 'Document Expiring Soon', got %q", title)
	}
	if body != `Your document "itb" expires in 14 days (on 2026-05-10).` {
		t.Errorf("unexpected body: %s", body)
	}
}

func TestBuildMessage_Expired(t *testing.T) {
	t.Parallel()

	expiry := time.Date(2026, 4, 20, 0, 0, 0, 0, time.UTC)
	title, body := buildMessage("insurance_rc", nil, -5, expiry)

	if title != "Document Expired" {
		t.Errorf("expected 'Document Expired', got %q", title)
	}
	if body != `Your document "insurance_rc" has expired.` {
		t.Errorf("unexpected body: %s", body)
	}
}

func TestBuildMessage_CustomName(t *testing.T) {
	t.Parallel()

	name := "Fire Extinguisher Cert"
	expiry := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	title, body := buildMessage("custom", &name, 30, expiry)

	if title != "Document Expiring Soon" {
		t.Errorf("expected 'Document Expiring Soon', got %q", title)
	}
	if body != `Your document "Fire Extinguisher Cert" expires in 30 days (on 2026-06-01).` {
		t.Errorf("unexpected body: %s", body)
	}
}

func (m *mockDocRepo) GetByIDUnscoped(_ context.Context, _ string) (*domain.Document, error) {
	return nil, domain.ErrDocumentNotFound
}
