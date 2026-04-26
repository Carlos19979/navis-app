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
func (m *mockDocRepo) ListByBoat(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Document, string, error) {
	return nil, "", nil
}
func (m *mockDocRepo) ListExpiring(ctx context.Context, withinDays int) ([]domain.Document, error) {
	return m.listExpiringFn(ctx, withinDays)
}
func (m *mockDocRepo) Update(ctx context.Context, userID string, doc *domain.Document) (*domain.Document, error) {
	return nil, nil
}
func (m *mockDocRepo) Delete(ctx context.Context, userID, id string) error { return nil }

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

type mockDeviceTokenRepo struct {
	getByUserIDFn func(ctx context.Context, userID string) ([]domain.DeviceToken, error)
}

func (m *mockDeviceTokenRepo) Upsert(ctx context.Context, userID, token string, platform domain.Platform) error {
	return nil
}
func (m *mockDeviceTokenRepo) Delete(ctx context.Context, token string) error { return nil }
func (m *mockDeviceTokenRepo) GetByUserID(ctx context.Context, userID string) ([]domain.DeviceToken, error) {
	return m.getByUserIDFn(ctx, userID)
}

type mockNotifier struct {
	sendFn func(ctx context.Context, deviceToken, title, body string) error
	sent   []sentNotification
}

type sentNotification struct {
	DeviceToken string
	Title       string
	Body        string
}

func (m *mockNotifier) Send(ctx context.Context, deviceToken, title, body string) error {
	m.sent = append(m.sent, sentNotification{deviceToken, title, body})
	if m.sendFn != nil {
		return m.sendFn(ctx, deviceToken, title, body)
	}
	return nil
}

// --- Helpers ---

func newTestChecker(
	docs *mockDocRepo,
	notifLogs *mockNotifLogRepo,
	deviceTokens *mockDeviceTokenRepo,
	notifier *mockNotifier,
) *ExpirationChecker {
	return New(docs, notifLogs, deviceTokens, notifier, slog.Default())
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

func TestExpirationChecker_Check_SendsNotifications(t *testing.T) {
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
		&mockDeviceTokenRepo{
			getByUserIDFn: func(_ context.Context, _ string) ([]domain.DeviceToken, error) {
				return []domain.DeviceToken{
					{Token: "token-ios", Platform: domain.PlatformIOS},
					{Token: "token-android", Platform: domain.PlatformAndroid},
				}, nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	// 2 alert days matched (30 and 7) × 2 devices = 4 notifications
	if len(notifier.sent) != 4 {
		t.Fatalf("expected 4 notifications (2 alerts × 2 devices), got %d", len(notifier.sent))
	}
	if notifier.sent[0].DeviceToken != "token-ios" {
		t.Errorf("expected token-ios, got %s", notifier.sent[0].DeviceToken)
	}
	if notifier.sent[1].DeviceToken != "token-android" {
		t.Errorf("expected token-android, got %s", notifier.sent[1].DeviceToken)
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
		&mockDeviceTokenRepo{
			getByUserIDFn: func(_ context.Context, _ string) ([]domain.DeviceToken, error) {
				return []domain.DeviceToken{{Token: "token-1"}}, nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.sent) != 0 {
		t.Fatalf("expected 0 notifications (already notified), got %d", len(notifier.sent))
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
		&mockDeviceTokenRepo{
			getByUserIDFn: func(_ context.Context, _ string) ([]domain.DeviceToken, error) {
				return []domain.DeviceToken{{Token: "token-1"}}, nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.sent) != 0 {
		t.Fatalf("expected 0 notifications (60 days > all alert days), got %d", len(notifier.sent))
	}
}

func TestExpirationChecker_Check_NoDeviceTokens(t *testing.T) {
	t.Parallel()

	notifier := &mockNotifier{}

	ec := newTestChecker(
		&mockDocRepo{
			listExpiringFn: func(_ context.Context, _ int) ([]domain.Document, error) {
				return []domain.Document{
					docExpiringIn("doc-1", "user-1", 5, []int{30}),
				}, nil
			},
		},
		&mockNotifLogRepo{
			existsFn: func(_ context.Context, _, _ string, _ int) (bool, error) { return false, nil },
			createFn: func(_ context.Context, _, _ string, _ int) error { return nil },
		},
		&mockDeviceTokenRepo{
			getByUserIDFn: func(_ context.Context, _ string) ([]domain.DeviceToken, error) {
				return nil, nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.sent) != 0 {
		t.Fatalf("expected 0 notifications (no device tokens), got %d", len(notifier.sent))
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
		&mockDeviceTokenRepo{
			getByUserIDFn: func(_ context.Context, _ string) ([]domain.DeviceToken, error) {
				return nil, nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.sent) != 0 {
		t.Fatalf("expected 0 notifications, got %d", len(notifier.sent))
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
		&mockDeviceTokenRepo{
			getByUserIDFn: func(_ context.Context, _ string) ([]domain.DeviceToken, error) {
				return nil, nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.sent) != 0 {
		t.Fatalf("expected 0 notifications on error, got %d", len(notifier.sent))
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
		&mockDeviceTokenRepo{
			getByUserIDFn: func(_ context.Context, _ string) ([]domain.DeviceToken, error) {
				return []domain.DeviceToken{{Token: "token-1"}}, nil
			},
		},
		notifier,
	)

	ec.check(context.Background())

	if len(notifier.sent) == 0 {
		t.Fatal("expected notification for expired document")
	}
	if notifier.sent[0].Title != "Document Expired" {
		t.Errorf("expected 'Document Expired' title, got %q", notifier.sent[0].Title)
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
