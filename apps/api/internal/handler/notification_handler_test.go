package handler_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/handler"
)

// --- Mocks ---

type mockNotificationService struct {
	items       []domain.Notification
	nextCursor  string
	unread      int
	markReadErr error
	markedID    string
	markedAll   bool
	prefs       []domain.CategoryPreference
	setPrefs    []domain.CategoryPreference
	setPrefsErr error
}

func (m *mockNotificationService) List(
	_ context.Context, _, _ string, _ int,
) ([]domain.Notification, string, error) {
	return m.items, m.nextCursor, nil
}

func (m *mockNotificationService) UnreadCount(_ context.Context, _ string) (int, error) {
	return m.unread, nil
}

func (m *mockNotificationService) MarkRead(_ context.Context, _, id string) error {
	if m.markReadErr != nil {
		return m.markReadErr
	}
	m.markedID = id
	return nil
}

func (m *mockNotificationService) MarkAllRead(_ context.Context, _ string) error {
	m.markedAll = true
	return nil
}

func (m *mockNotificationService) Preferences(
	_ context.Context, _ string,
) ([]domain.CategoryPreference, error) {
	return m.prefs, nil
}

func (m *mockNotificationService) SetPreferences(
	_ context.Context, _ string, prefs []domain.CategoryPreference,
) ([]domain.CategoryPreference, error) {
	if m.setPrefsErr != nil {
		return nil, m.setPrefsErr
	}
	m.setPrefs = prefs
	return prefs, nil
}

// --- List ---

func TestNotificationHandler_List_ReturnsFeedWithCursor(t *testing.T) {
	t.Parallel()

	readAt := time.Date(2026, 7, 31, 9, 0, 0, 0, time.UTC)
	svc := &mockNotificationService{
		items: []domain.Notification{
			{
				ID: "n1", UserID: "user-1", Category: domain.CategoryReminders,
				Title: "Seguro caduca", Body: "30 dias",
				LinkType: "document", LinkID: "doc-1",
				CreatedAt: time.Date(2026, 7, 31, 8, 0, 0, 0, time.UTC),
			},
			{
				ID: "n2", UserID: "user-1", Category: domain.CategoryBoatActivity,
				Title: "Reserva creada", ReadAt: &readAt,
				CreatedAt: time.Date(2026, 7, 30, 8, 0, 0, 0, time.UTC),
			},
		},
		nextCursor: "cursor-2",
	}
	h := handler.NewNotificationHandler(svc)

	w := httptest.NewRecorder()
	h.List(w, authedRequest(http.MethodGet, "/api/v1/notifications", "", "user-1"))

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", w.Code, w.Body.String())
	}

	var resp struct {
		Data []struct {
			ID       string  `json:"id"`
			Category string  `json:"category"`
			Title    string  `json:"title"`
			LinkType *string `json:"link_type"`
			LinkID   *string `json:"link_id"`
			Read     bool    `json:"read"`
		} `json:"data"`
		Meta *struct {
			NextCursor *string `json:"next_cursor"`
		} `json:"meta"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decoding response: %v", err)
	}

	if len(resp.Data) != 2 {
		t.Fatalf("got %d notifications, want 2", len(resp.Data))
	}
	if resp.Data[0].Category != "reminders" || resp.Data[0].Read {
		t.Errorf("first item = %+v, want unread reminders", resp.Data[0])
	}
	if resp.Data[0].LinkType == nil || *resp.Data[0].LinkType != "document" {
		t.Errorf("link_type = %v, want document", resp.Data[0].LinkType)
	}
	if !resp.Data[1].Read {
		t.Errorf("second item should be read")
	}
	// A notification with no deep-link target must not fake one.
	if resp.Data[1].LinkType != nil || resp.Data[1].LinkID != nil {
		t.Errorf("empty link should serialise as null, got %v / %v",
			resp.Data[1].LinkType, resp.Data[1].LinkID)
	}
	if resp.Meta == nil || resp.Meta.NextCursor == nil || *resp.Meta.NextCursor != "cursor-2" {
		t.Errorf("meta next_cursor missing, got %+v", resp.Meta)
	}
}

func TestNotificationHandler_List_RequiresAuth(t *testing.T) {
	t.Parallel()

	h := handler.NewNotificationHandler(&mockNotificationService{})

	w := httptest.NewRecorder()
	h.List(w, httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil))

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", w.Code)
	}
}

// --- Unread count ---

func TestNotificationHandler_UnreadCount_ReturnsBadgeValue(t *testing.T) {
	t.Parallel()

	h := handler.NewNotificationHandler(&mockNotificationService{unread: 3})

	w := httptest.NewRecorder()
	h.UnreadCount(w, authedRequest(http.MethodGet, "/api/v1/notifications/unread-count", "", "user-1"))

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}

	var resp struct {
		Data struct {
			Count int `json:"count"`
		} `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decoding response: %v", err)
	}
	if resp.Data.Count != 3 {
		t.Errorf("count = %d, want 3", resp.Data.Count)
	}
}

// --- Mark read ---

func TestNotificationHandler_MarkRead_Success(t *testing.T) {
	t.Parallel()

	svc := &mockNotificationService{}
	h := handler.NewNotificationHandler(svc)

	r := withChiParam(
		authedRequest(http.MethodPut, "/api/v1/notifications/n1/read", "", "user-1"), "id", "n1")
	w := httptest.NewRecorder()
	h.MarkRead(w, r)

	if w.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204: %s", w.Code, w.Body.String())
	}
	if svc.markedID != "n1" {
		t.Errorf("marked id = %q, want n1", svc.markedID)
	}
}

func TestNotificationHandler_MarkRead_UnknownIDIs404(t *testing.T) {
	t.Parallel()

	h := handler.NewNotificationHandler(&mockNotificationService{markReadErr: domain.ErrNotFound})

	r := withChiParam(
		authedRequest(http.MethodPut, "/api/v1/notifications/nope/read", "", "user-1"), "id", "nope")
	w := httptest.NewRecorder()
	h.MarkRead(w, r)

	if w.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", w.Code)
	}
}

func TestNotificationHandler_MarkAllRead_Success(t *testing.T) {
	t.Parallel()

	svc := &mockNotificationService{}
	h := handler.NewNotificationHandler(svc)

	w := httptest.NewRecorder()
	h.MarkAllRead(w, authedRequest(http.MethodPut, "/api/v1/notifications/read-all", "", "user-1"))

	if w.Code != http.StatusNoContent {
		t.Fatalf("status = %d, want 204", w.Code)
	}
	if !svc.markedAll {
		t.Error("service was not asked to mark all read")
	}
}

// --- Preferences ---

func TestNotificationHandler_GetPreferences_ReturnsEveryCategory(t *testing.T) {
	t.Parallel()

	svc := &mockNotificationService{prefs: []domain.CategoryPreference{
		{Category: domain.CategoryReminders, Enabled: true},
		{Category: domain.CategoryGroupUpdates, Enabled: false},
	}}
	h := handler.NewNotificationHandler(svc)

	w := httptest.NewRecorder()
	h.GetPreferences(w, authedRequest(http.MethodGet, "/api/v1/me/notification-preferences", "", "user-1"))

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}

	var resp struct {
		Data struct {
			Categories []struct {
				Category string `json:"category"`
				Enabled  bool   `json:"enabled"`
			} `json:"categories"`
		} `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decoding response: %v", err)
	}
	if len(resp.Data.Categories) != 2 {
		t.Fatalf("got %d categories, want 2", len(resp.Data.Categories))
	}
	if resp.Data.Categories[1].Category != "group-updates" || resp.Data.Categories[1].Enabled {
		t.Errorf("second category = %+v, want group-updates disabled", resp.Data.Categories[1])
	}
}

func TestNotificationHandler_UpdatePreferences_Success(t *testing.T) {
	t.Parallel()

	svc := &mockNotificationService{}
	h := handler.NewNotificationHandler(svc)

	body := `{"categories":[{"category":"reminders","enabled":true},{"category":"event-live","enabled":false}]}`
	w := httptest.NewRecorder()
	h.UpdatePreferences(w,
		authedRequest(http.MethodPut, "/api/v1/me/notification-preferences", body, "user-1"))

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200: %s", w.Code, w.Body.String())
	}
	if len(svc.setPrefs) != 2 {
		t.Fatalf("service got %d preferences, want 2", len(svc.setPrefs))
	}
	if svc.setPrefs[1].Category != domain.CategoryEventLive || svc.setPrefs[1].Enabled {
		t.Errorf("second preference = %+v, want event-live disabled", svc.setPrefs[1])
	}
}

func TestNotificationHandler_UpdatePreferences_RejectsUnknownCategory(t *testing.T) {
	t.Parallel()

	svc := &mockNotificationService{}
	h := handler.NewNotificationHandler(svc)

	body := `{"categories":[{"category":"gossip","enabled":false}]}`
	w := httptest.NewRecorder()
	h.UpdatePreferences(w,
		authedRequest(http.MethodPut, "/api/v1/me/notification-preferences", body, "user-1"))

	// DTO validation rejects it before the service is reached (422, as
	// everywhere else in the API).
	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("status = %d, want 422: %s", w.Code, w.Body.String())
	}
	if svc.setPrefs != nil {
		t.Errorf("service was called with %+v, want no call", svc.setPrefs)
	}
}
