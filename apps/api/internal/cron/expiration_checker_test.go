package cron

import (
	"context"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
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

// --- Helpers ---

func newTestChecker(
	docs *mockDocRepo,
	notifLogs *mockNotifLogRepo,
	notifier *testutil.FakeNotificationProvider,
) *ExpirationChecker {
	return New(docs, notifLogs, &testutil.FakeProfileRepo{Plan: domain.PlanPro}, notifier, slog.Default())
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

	notifier := &testutil.FakeNotificationProvider{}
	var loggedDocID string
	var loggedAlertDays []int

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
				loggedAlertDays = append(loggedAlertDays, alertDay)
				return nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	// A document 5 days out crossed BOTH alert days, but the message only says
	// "in 5 days": notify once, and log both marks so neither fires it again.
	if len(notifier.Triggered) != 1 {
		t.Fatalf("expected 1 workflow trigger for one document, got %d", len(notifier.Triggered))
	}
	if notifier.Triggered[0].WorkflowID != "reminders" {
		t.Errorf("expected workflow 'reminders', got %s", notifier.Triggered[0].WorkflowID)
	}
	if notifier.Triggered[0].SubscriberID != "user-1" {
		t.Errorf("expected subscriber user-1, got %s", notifier.Triggered[0].SubscriberID)
	}
	// The deep-link pair the app routes on: without it the reminder opens
	// nothing, in the push and in the in-app feed alike.
	payload := notifier.Triggered[0].Payload
	if payload["type"] != "document" || payload["id"] != "doc-1" {
		t.Errorf("deep link = %v/%v, want document/doc-1", payload["type"], payload["id"])
	}
	if loggedDocID != "doc-1" {
		t.Errorf("expected notification log for doc-1, got %s", loggedDocID)
	}
	if len(loggedAlertDays) != 2 {
		t.Errorf("logged alert days = %v, want both 30 and 7", loggedAlertDays)
	}
}

// Muting must not consume the reminder's dedup slots: the user unmuting later
// is exactly when the reminder should finally be delivered.
func TestExpirationChecker_Check_MutedCategoryStaysPending(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{
		TriggerFn: func(_ context.Context, _, _ string, _ map[string]any) error {
			return domain.ErrNotificationMuted
		},
	}
	var logged []int

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
			createFn: func(_ context.Context, _, _ string, alertDay int) error {
				logged = append(logged, alertDay)
				return nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(logged) != 0 {
		t.Errorf("dedup logged %v for a muted reminder; it would never be sent again", logged)
	}
}

func TestExpirationChecker_Check_SkipsAlreadyNotified(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{}

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

	if len(notifier.Triggered) != 0 {
		t.Fatalf("expected 0 triggers (already notified), got %d", len(notifier.Triggered))
	}
}

func TestExpirationChecker_Check_RespectsAlertDays(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{}

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

	if len(notifier.Triggered) != 0 {
		t.Fatalf("expected 0 triggers (60 days > all alert days), got %d", len(notifier.Triggered))
	}
}

func TestExpirationChecker_Check_NoExpiringDocs(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{}

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

	if len(notifier.Triggered) != 0 {
		t.Fatalf("expected 0 triggers, got %d", len(notifier.Triggered))
	}
}

func TestExpirationChecker_Check_ListExpiringError(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{}

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

	if len(notifier.Triggered) != 0 {
		t.Fatalf("expected 0 triggers on error, got %d", len(notifier.Triggered))
	}
}

func TestExpirationChecker_Check_ExpiredDocument(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{}

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

	if len(notifier.Triggered) == 0 {
		t.Fatal("expected workflow trigger for expired document")
	}
	title, _ := notifier.Triggered[0].Payload["title"].(string)
	if title != "Documento caducado" {
		t.Errorf("expected the expired title, got %q", title)
	}
}

func TestExpirationChecker_Check_FreePlanLimitsToNearestDoc(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{}
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
		&testutil.FakeProfileRepo{Plan: domain.PlanFree},
		notifier,
		slog.Default(),
	)

	ec.check(context.Background())

	for _, tw := range notifier.Triggered {
		docID, _ := tw.Payload["document_id"].(string)
		if docID != "doc-near" {
			t.Errorf("free user should only be notified for doc-near, got %q", docID)
		}
	}
	if len(notifier.Triggered) == 0 {
		t.Fatal("expected the nearest document to notify")
	}
}

func TestExpirationChecker_Check_ProPlanNotifiesAllDocs(t *testing.T) {
	t.Parallel()

	notifier := &testutil.FakeNotificationProvider{}
	// Pro user with three expiring documents: no reminder cap, all notify.
	ec := New(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return []domain.Document{
					docExpiringIn("doc-a", "pro-user", 3, []int{7}),
					docExpiringIn("doc-b", "pro-user", 5, []int{7}),
					docExpiringIn("doc-c", "pro-user", 6, []int{7}),
				}, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		&testutil.FakeProfileRepo{Plan: domain.PlanPro},
		notifier,
		slog.Default(),
	)

	ec.check(context.Background())

	if len(notifier.Triggered) != 3 {
		t.Fatalf("expected 3 triggers (one per document), got %d", len(notifier.Triggered))
	}
	seen := make(map[string]bool)
	for _, tw := range notifier.Triggered {
		docID, _ := tw.Payload["document_id"].(string)
		seen[docID] = true
	}
	for _, id := range []string{"doc-a", "doc-b", "doc-c"} {
		if !seen[id] {
			t.Errorf("expected a trigger for %s", id)
		}
	}
}

func TestBuildMessage_Expiring(t *testing.T) {
	t.Parallel()

	expiry := time.Date(2026, 5, 10, 0, 0, 0, 0, time.UTC)
	title, body := buildMessage(domain.DocumentTypeITB, nil, 14, expiry)

	if title != "Documento a punto de caducar" {
		t.Errorf("title = %q", title)
	}
	// The type slug ("itb") must not reach the user: it is now a readable name.
	if body != "Tu certificado ITB caduca en 14 dias (el 10/05/2026)." {
		t.Errorf("unexpected body: %s", body)
	}
}

func TestBuildMessage_ExpiringTomorrow(t *testing.T) {
	t.Parallel()

	expiry := time.Date(2026, 5, 10, 0, 0, 0, 0, time.UTC)
	_, body := buildMessage(domain.DocumentTypeITB, nil, 1, expiry)

	if body != "Tu certificado ITB caduca manana (10/05/2026)." {
		t.Errorf("unexpected body: %s", body)
	}
}

func TestBuildMessage_Expired(t *testing.T) {
	t.Parallel()

	expiry := time.Date(2026, 4, 20, 0, 0, 0, 0, time.UTC)
	title, body := buildMessage(domain.DocumentTypeInsuranceRC, nil, -5, expiry)

	if title != "Documento caducado" {
		t.Errorf("title = %q", title)
	}
	if body != "Tu seguro de responsabilidad civil ha caducado." {
		t.Errorf("unexpected body: %s", body)
	}
}

func TestBuildMessage_CustomName(t *testing.T) {
	t.Parallel()

	name := "Certificado del extintor"
	expiry := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	title, body := buildMessage(domain.DocumentTypeCustom, &name, 30, expiry)

	if title != "Documento a punto de caducar" {
		t.Errorf("title = %q", title)
	}
	if body != "Tu Certificado del extintor caduca en 30 dias (el 01/06/2026)." {
		t.Errorf("unexpected body: %s", body)
	}
}

// Every canonical document type needs a readable name, or a reminder leaks the
// database slug to the user.
func TestDocumentName_CoversEveryType(t *testing.T) {
	t.Parallel()

	types := []domain.DocumentType{
		domain.DocumentTypeITB, domain.DocumentTypeInsuranceRC,
		domain.DocumentTypeInsuranceFull, domain.DocumentTypeLifeRaft,
		domain.DocumentTypeExtinguisher, domain.DocumentTypeFlares,
		domain.DocumentTypeFirstAid, domain.DocumentTypeMedicalCert,
		domain.DocumentTypeRadioCert, domain.DocumentTypeNavigationLicense,
		domain.DocumentTypeCustom,
	}
	for _, docType := range types {
		name := documentName(docType, nil)
		if name == "" || name == string(docType) {
			t.Errorf("document type %q has no readable name (got %q)", docType, name)
		}
	}
}

func (m *mockDocRepo) GetByIDUnscoped(_ context.Context, _ string) (*domain.Document, error) {
	return nil, domain.ErrDocumentNotFound
}
