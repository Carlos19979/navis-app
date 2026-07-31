package service_test

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

// --- Fakes ---

// fakeFeedRepo is an in-memory port.NotificationFeedRepository.
type fakeFeedRepo struct {
	created   []domain.Notification
	createErr error
	listErr   error
	unread    int
	markedAll []string
	marked    map[string]string
	markErr   error
}

func newFakeFeedRepo() *fakeFeedRepo {
	return &fakeFeedRepo{marked: map[string]string{}}
}

func (f *fakeFeedRepo) Create(_ context.Context, n *domain.Notification) error {
	if f.createErr != nil {
		return f.createErr
	}
	f.created = append(f.created, *n)
	return nil
}

func (f *fakeFeedRepo) List(_ context.Context, userID, _ string, limit int) ([]domain.Notification, string, error) {
	if f.listErr != nil {
		return nil, "", f.listErr
	}
	items := make([]domain.Notification, 0, len(f.created))
	for _, n := range f.created {
		if n.UserID == userID {
			items = append(items, n)
		}
	}
	if len(items) > limit {
		return items[:limit], "next", nil
	}
	return items, "", nil
}

func (f *fakeFeedRepo) UnreadCount(_ context.Context, _ string) (int, error) {
	return f.unread, nil
}

func (f *fakeFeedRepo) MarkRead(_ context.Context, userID, id string) error {
	if f.markErr != nil {
		return f.markErr
	}
	f.marked[id] = userID
	return nil
}

func (f *fakeFeedRepo) MarkAllRead(_ context.Context, userID string) error {
	f.markedAll = append(f.markedAll, userID)
	return nil
}

// fakePrefsRepo is an in-memory port.NotificationPrefsRepository.
type fakePrefsRepo struct {
	muted   map[string][]domain.NotificationCategory
	listErr error
	saveErr error
}

func newFakePrefsRepo() *fakePrefsRepo {
	return &fakePrefsRepo{muted: map[string][]domain.NotificationCategory{}}
}

func (f *fakePrefsRepo) ListMuted(_ context.Context, userID string) ([]domain.NotificationCategory, error) {
	if f.listErr != nil {
		return nil, f.listErr
	}
	return f.muted[userID], nil
}

func (f *fakePrefsRepo) ReplaceMuted(_ context.Context, userID string, muted []domain.NotificationCategory) error {
	if f.saveErr != nil {
		return f.saveErr
	}
	f.muted[userID] = muted
	return nil
}

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

// remindersPayload mirrors what the expiry cron actually sends (see
// internal/cron/expiration_checker.go): the extra document_* keys are part of
// the real shape, and "type"/"id" are what the feed stores as the deep link. A
// hand-idealised payload here is how the missing deep link went unnoticed.
func remindersPayload() map[string]any {
	return map[string]any{
		"title":             "Documento a punto de caducar",
		"body":              "Tu seguro de responsabilidad civil caduca en 5 dias (el 05/08/2026).",
		"type":              "document",
		"id":                "doc-1",
		"document_id":       "doc-1",
		"document_type":     "insurance_rc",
		"days_until_expiry": 5,
		"expiry_date":       "2026-08-05",
	}
}

// --- FeedRecorder ---

func TestFeedRecorder_TriggerWorkflow_RecordsDeliveredNotification(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	rec := service.NewFeedRecorder(provider, feed, newFakePrefsRepo(), discardLogger(), false)

	if err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowReminders, "user-1", remindersPayload()); err != nil {
		t.Fatalf("TriggerWorkflow: %v", err)
	}

	if len(provider.Triggered) != 1 {
		t.Fatalf("provider triggered %d times, want 1", len(provider.Triggered))
	}
	if len(feed.created) != 1 {
		t.Fatalf("recorded %d notifications, want 1", len(feed.created))
	}

	got := feed.created[0]
	if got.UserID != "user-1" {
		t.Errorf("user id = %q, want user-1", got.UserID)
	}
	if got.Category != domain.CategoryReminders {
		t.Errorf("category = %q, want %q", got.Category, domain.CategoryReminders)
	}
	if got.Title != "Documento a punto de caducar" ||
		!strings.Contains(got.Body, "caduca en 5 dias") {
		t.Errorf("title/body = %q / %q", got.Title, got.Body)
	}
	if got.LinkType != "document" || got.LinkID != "doc-1" {
		t.Errorf("link = %q / %q, want document / doc-1", got.LinkType, got.LinkID)
	}
}

func TestFeedRecorder_TriggerWorkflow_MutedCategoryIsNotDeliveredNorRecorded(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	prefs := newFakePrefsRepo()
	prefs.muted["user-1"] = []domain.NotificationCategory{domain.CategoryReminders}
	rec := service.NewFeedRecorder(provider, feed, prefs, discardLogger(), false)

	err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowReminders, "user-1", remindersPayload())

	// Reported as muted, not as delivered: the crons record dedup state only on
	// success, so "delivered" would burn the reminder's only slot and the user
	// would never hear about it after unmuting.
	if !errors.Is(err, domain.ErrNotificationMuted) {
		t.Fatalf("error = %v, want ErrNotificationMuted", err)
	}
	if len(provider.Triggered) != 0 {
		t.Errorf("muted category was delivered (%d triggers)", len(provider.Triggered))
	}
	if len(feed.created) != 0 {
		t.Errorf("muted category was recorded (%d rows)", len(feed.created))
	}
}

func TestFeedRecorder_TriggerWorkflow_OtherCategoriesStillDeliveredWhenOneIsMuted(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	prefs := newFakePrefsRepo()
	prefs.muted["user-1"] = []domain.NotificationCategory{domain.CategoryReminders}
	rec := service.NewFeedRecorder(provider, feed, prefs, discardLogger(), false)

	if err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowBoatActivity, "user-1", remindersPayload()); err != nil {
		t.Fatalf("TriggerWorkflow: %v", err)
	}

	if len(provider.Triggered) != 1 || len(feed.created) != 1 {
		t.Fatalf("boat-activity was dropped: %d triggers, %d rows",
			len(provider.Triggered), len(feed.created))
	}
	if feed.created[0].Category != domain.CategoryBoatActivity {
		t.Errorf("category = %q, want %q", feed.created[0].Category, domain.CategoryBoatActivity)
	}
}

// A failed delivery must leave no feed row: the crons record their dedup state
// only on success and will retry, which would otherwise duplicate the entry.
func TestFeedRecorder_TriggerWorkflow_ProviderFailureRecordsNothing(t *testing.T) {
	t.Parallel()

	wantErr := errors.New("novu down")
	provider := &testutil.FakeNotificationProvider{
		TriggerFn: func(_ context.Context, _, _ string, _ map[string]any) error { return wantErr },
	}
	feed := newFakeFeedRepo()
	rec := service.NewFeedRecorder(provider, feed, newFakePrefsRepo(), discardLogger(), false)

	err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowReminders, "user-1", remindersPayload())
	if !errors.Is(err, wantErr) {
		t.Fatalf("error = %v, want %v", err, wantErr)
	}
	if len(feed.created) != 0 {
		t.Errorf("recorded %d notifications after a failed delivery, want 0", len(feed.created))
	}
}

// The push already went out, so a feed write failure must not be reported as a
// failed delivery (the cron would re-send it).
func TestFeedRecorder_TriggerWorkflow_FeedWriteFailureStillSucceeds(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	feed.createErr = errors.New("db down")
	rec := service.NewFeedRecorder(provider, feed, newFakePrefsRepo(), discardLogger(), false)

	if err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowReminders, "user-1", remindersPayload()); err != nil {
		t.Fatalf("TriggerWorkflow: %v", err)
	}
	if len(provider.Triggered) != 1 {
		t.Errorf("provider triggered %d times, want 1", len(provider.Triggered))
	}
}

// A preferences lookup failure must not silence notifications.
func TestFeedRecorder_TriggerWorkflow_PrefsFailureDeliversAnyway(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	prefs := newFakePrefsRepo()
	prefs.listErr = errors.New("db down")
	rec := service.NewFeedRecorder(provider, feed, prefs, discardLogger(), false)

	if err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowReminders, "user-1", remindersPayload()); err != nil {
		t.Fatalf("TriggerWorkflow: %v", err)
	}
	if len(provider.Triggered) != 1 {
		t.Errorf("provider triggered %d times, want 1", len(provider.Triggered))
	}
}

func TestFeedRecorder_TriggerWorkflow_UnknownWorkflowIsDeliveredButNotRecorded(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	rec := service.NewFeedRecorder(provider, feed, newFakePrefsRepo(), discardLogger(), false)

	if err := rec.TriggerWorkflow(context.Background(),
		"some-future-workflow", "user-1", remindersPayload()); err != nil {
		t.Fatalf("TriggerWorkflow: %v", err)
	}
	if len(provider.Triggered) != 1 {
		t.Errorf("provider triggered %d times, want 1", len(provider.Triggered))
	}
	if len(feed.created) != 0 {
		t.Errorf("recorded %d notifications for an uncategorised workflow, want 0", len(feed.created))
	}
}

// Every event the app sends must land under a category the user can toggle.
func TestFeedRecorder_AllWorkflowsAreValidCategories(t *testing.T) {
	t.Parallel()

	workflows := []string{
		service.WorkflowReminders,
		service.WorkflowRegattaUpdates,
		service.WorkflowGroupUpdates,
		service.WorkflowBoatActivity,
		service.WorkflowEventLive,
	}
	for _, w := range workflows {
		if !domain.NotificationCategory(w).Valid() {
			t.Errorf("workflow %q is not a valid notification category", w)
		}
	}
}

// Notifier delivers through the provider, so wrapping it records in-app events.
func TestNotifier_Send_RecordsThroughFeedRecorder(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	rec := service.NewFeedRecorder(provider, feed, newFakePrefsRepo(), discardLogger(), false)
	notifier := service.NewNotifier(rec, nil, discardLogger())

	notifier.Send(context.Background(), "user-1", service.WorkflowBoatActivity,
		"Nuevo gasto", "Carlos añadió un gasto", "boat", "boat-1")

	if len(feed.created) != 1 {
		t.Fatalf("recorded %d notifications, want 1", len(feed.created))
	}
	if feed.created[0].LinkType != "boat" || feed.created[0].LinkID != "boat-1" {
		t.Errorf("link = %q / %q, want boat / boat-1",
			feed.created[0].LinkType, feed.created[0].LinkID)
	}
}

// --- NotificationService ---

func TestNotificationService_Preferences_AllEnabledByDefault(t *testing.T) {
	t.Parallel()

	svc := service.NewNotificationService(newFakeFeedRepo(), newFakePrefsRepo())

	prefs, err := svc.Preferences(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("Preferences: %v", err)
	}

	if len(prefs) != len(domain.AllNotificationCategories()) {
		t.Fatalf("got %d categories, want %d", len(prefs), len(domain.AllNotificationCategories()))
	}
	for _, p := range prefs {
		if !p.Enabled {
			t.Errorf("category %q disabled by default", p.Category)
		}
	}
	// Order is the app's display order.
	if prefs[0].Category != domain.CategoryReminders {
		t.Errorf("first category = %q, want %q", prefs[0].Category, domain.CategoryReminders)
	}
}

func TestNotificationService_SetPreferences_MutesDisabledCategories(t *testing.T) {
	t.Parallel()

	prefsRepo := newFakePrefsRepo()
	svc := service.NewNotificationService(newFakeFeedRepo(), prefsRepo)

	got, err := svc.SetPreferences(context.Background(), "user-1", []domain.CategoryPreference{
		{Category: domain.CategoryReminders, Enabled: true},
		{Category: domain.CategoryGroupUpdates, Enabled: false},
		{Category: domain.CategoryEventLive, Enabled: false},
	})
	if err != nil {
		t.Fatalf("SetPreferences: %v", err)
	}

	stored := prefsRepo.muted["user-1"]
	if len(stored) != 2 ||
		!slices.Contains(stored, domain.CategoryGroupUpdates) ||
		!slices.Contains(stored, domain.CategoryEventLive) {
		t.Fatalf("stored muted = %v, want [group-updates event-live]", stored)
	}

	// The response reflects the new state for every category.
	for _, p := range got {
		wantEnabled := p.Category != domain.CategoryGroupUpdates && p.Category != domain.CategoryEventLive
		if p.Enabled != wantEnabled {
			t.Errorf("category %q enabled = %v, want %v", p.Category, p.Enabled, wantEnabled)
		}
	}
}

func TestNotificationService_SetPreferences_RejectsUnknownCategory(t *testing.T) {
	t.Parallel()

	prefsRepo := newFakePrefsRepo()
	svc := service.NewNotificationService(newFakeFeedRepo(), prefsRepo)

	_, err := svc.SetPreferences(context.Background(), "user-1", []domain.CategoryPreference{
		{Category: domain.NotificationCategory("gossip"), Enabled: false},
	})
	if !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("error = %v, want a validation error", err)
	}
	if len(prefsRepo.muted) != 0 {
		t.Errorf("stored preferences despite the invalid category: %v", prefsRepo.muted)
	}
}

func TestNotificationService_SetPreferences_ReEnableClearsMute(t *testing.T) {
	t.Parallel()

	prefsRepo := newFakePrefsRepo()
	prefsRepo.muted["user-1"] = []domain.NotificationCategory{domain.CategoryReminders}
	svc := service.NewNotificationService(newFakeFeedRepo(), prefsRepo)

	if _, err := svc.SetPreferences(context.Background(), "user-1", []domain.CategoryPreference{
		{Category: domain.CategoryReminders, Enabled: true},
	}); err != nil {
		t.Fatalf("SetPreferences: %v", err)
	}

	if len(prefsRepo.muted["user-1"]) != 0 {
		t.Errorf("muted = %v, want empty", prefsRepo.muted["user-1"])
	}
}

func TestNotificationService_List_ReturnsUsersNotifications(t *testing.T) {
	t.Parallel()

	feed := newFakeFeedRepo()
	feed.created = []domain.Notification{
		{ID: "n1", UserID: "user-1", Category: domain.CategoryReminders, CreatedAt: time.Now()},
		{ID: "n2", UserID: "user-2", Category: domain.CategoryReminders, CreatedAt: time.Now()},
	}
	svc := service.NewNotificationService(feed, newFakePrefsRepo())

	items, next, err := svc.List(context.Background(), "user-1", "", 20)
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(items) != 1 || items[0].ID != "n1" {
		t.Fatalf("items = %+v, want just n1", items)
	}
	if next != "" {
		t.Errorf("next cursor = %q, want empty", next)
	}
}

func TestNotificationService_MarkRead_PropagatesNotFound(t *testing.T) {
	t.Parallel()

	feed := newFakeFeedRepo()
	feed.markErr = domain.ErrNotFound
	svc := service.NewNotificationService(feed, newFakePrefsRepo())

	err := svc.MarkRead(context.Background(), "user-1", "missing")
	if !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("error = %v, want ErrNotFound", err)
	}
}

func TestNotificationService_MarkAllRead_DelegatesForCaller(t *testing.T) {
	t.Parallel()

	feed := newFakeFeedRepo()
	svc := service.NewNotificationService(feed, newFakePrefsRepo())

	if err := svc.MarkAllRead(context.Background(), "user-1"); err != nil {
		t.Fatalf("MarkAllRead: %v", err)
	}
	if len(feed.markedAll) != 1 || feed.markedAll[0] != "user-1" {
		t.Errorf("markedAll = %v, want [user-1]", feed.markedAll)
	}
}

func TestNotificationService_UnreadCount_ReturnsBadgeValue(t *testing.T) {
	t.Parallel()

	feed := newFakeFeedRepo()
	feed.unread = 7
	svc := service.NewNotificationService(feed, newFakePrefsRepo())

	count, err := svc.UnreadCount(context.Background(), "user-1")
	if err != nil {
		t.Fatalf("UnreadCount: %v", err)
	}
	if count != 7 {
		t.Errorf("count = %d, want 7", count)
	}
}

// A provider failure on the in-app path (fire-and-forget, no retry) must still
// leave a feed row: dropping it loses the event for good, which is the exact
// failure the feed exists to prevent.
func TestFeedRecorder_TriggerWorkflow_RecordsUndeliveredForNonRetryingCaller(t *testing.T) {
	t.Parallel()

	wantErr := errors.New("novu 429")
	provider := &testutil.FakeNotificationProvider{
		TriggerFn: func(_ context.Context, _, _ string, _ map[string]any) error { return wantErr },
	}
	feed := newFakeFeedRepo()
	rec := service.NewFeedRecorder(provider, feed, newFakePrefsRepo(), discardLogger(), true)

	err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowBoatActivity, "user-1", remindersPayload())

	// The error still surfaces (the caller decides what to do with it)...
	if !errors.Is(err, wantErr) {
		t.Fatalf("error = %v, want %v", err, wantErr)
	}
	// ...but the notification is in the feed.
	if len(feed.created) != 1 {
		t.Fatalf("recorded %d notifications, want 1", len(feed.created))
	}
}

// Muted must not be recorded even for the record-undelivered variant.
func TestFeedRecorder_TriggerWorkflow_MutedIsNeverRecorded(t *testing.T) {
	t.Parallel()

	provider := &testutil.FakeNotificationProvider{}
	feed := newFakeFeedRepo()
	prefs := newFakePrefsRepo()
	prefs.muted["user-1"] = []domain.NotificationCategory{domain.CategoryBoatActivity}
	rec := service.NewFeedRecorder(provider, feed, prefs, discardLogger(), true)

	err := rec.TriggerWorkflow(context.Background(),
		service.WorkflowBoatActivity, "user-1", remindersPayload())

	if !errors.Is(err, domain.ErrNotificationMuted) {
		t.Fatalf("error = %v, want ErrNotificationMuted", err)
	}
	if len(feed.created) != 0 {
		t.Errorf("recorded %d rows for a muted category, want 0", len(feed.created))
	}
}

func TestNotificationService_SetPreferences_RejectsDuplicateCategory(t *testing.T) {
	t.Parallel()

	prefsRepo := newFakePrefsRepo()
	svc := service.NewNotificationService(newFakeFeedRepo(), prefsRepo)

	// Which one wins is undefined, so the request is refused instead.
	_, err := svc.SetPreferences(context.Background(), "user-1", []domain.CategoryPreference{
		{Category: domain.CategoryReminders, Enabled: false},
		{Category: domain.CategoryReminders, Enabled: true},
	})
	if !errors.Is(err, domain.ErrValidation) {
		t.Fatalf("error = %v, want a validation error", err)
	}
	if len(prefsRepo.muted) != 0 {
		t.Errorf("stored %v despite the duplicate", prefsRepo.muted)
	}
}

// The category CHECK constraint in migration 00041 must list exactly the
// categories the code can emit: a mismatch only shows up in production as a
// constraint violation that the feed writer swallows as a WARN log.
func TestNotificationCategories_MatchMigrationConstraint(t *testing.T) {
	t.Parallel()

	sql, err := os.ReadFile(
		filepath.Join("..", "..", "..", "..",
			"packages", "supabase", "migrations", "00041_notification_feed.sql"))
	if err != nil {
		t.Fatalf("reading migration: %v", err)
	}

	for _, category := range domain.AllNotificationCategories() {
		if !strings.Contains(string(sql), "'"+string(category)+"'") {
			t.Errorf("category %q is missing from the migration CHECK constraint", category)
		}
	}
	// And nothing extra: count the quoted values inside the CHECK lists.
	quoted := regexp.MustCompile(`'([a-z-]+)'`).FindAllStringSubmatch(string(sql), -1)
	found := map[string]bool{}
	for _, m := range quoted {
		found[m[1]] = true
	}
	for value := range found {
		if !domain.NotificationCategory(value).Valid() {
			t.Errorf("migration allows category %q, which the code never emits", value)
		}
	}
}
