package handler_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/handler"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
)

// --- Mocks ---

type mockDeviceRepo struct {
	upsertFn func(ctx context.Context, userID, token string, platform domain.Platform) error
	deleteFn func(ctx context.Context, userID, token string) error
}

func (m *mockDeviceRepo) Upsert(ctx context.Context, userID, token string, platform domain.Platform) error {
	return m.upsertFn(ctx, userID, token, platform)
}

func (m *mockDeviceRepo) Delete(ctx context.Context, userID, token string) error {
	return m.deleteFn(ctx, userID, token)
}

type mockNotifier struct{}

func (m *mockNotifier) EnsureSubscriber(_ context.Context, _ string) error   { return nil }
func (m *mockNotifier) SetPushToken(_ context.Context, _, _ string) error    { return nil }
func (m *mockNotifier) RemovePushToken(_ context.Context, _, _ string) error { return nil }

// --- Helpers ---

func authedRequest(method, path, body, userID string) *http.Request {
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	r.Header.Set("Content-Type", "application/json")
	ctx := middleware.ContextWithUserID(r.Context(), userID)
	return r.WithContext(ctx)
}

func withChiParam(r *http.Request, key, value string) *http.Request {
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add(key, value)
	return r.WithContext(context.WithValue(r.Context(), chi.RouteCtxKey, rctx))
}

// --- Create Tests ---

func TestDeviceHandler_Create_Success(t *testing.T) {
	t.Parallel()

	var gotUserID, gotToken string
	var gotPlatform domain.Platform

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, userID, token string, platform domain.Platform) error {
			gotUserID = userID
			gotToken = token
			gotPlatform = platform
			return nil
		},
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodPost, "/api/v1/devices", `{"token":"abc123","platform":"ios"}`, "user-1")
	h.Create(w, r)

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
	}
	if gotUserID != "user-1" {
		t.Errorf("expected user-1, got %s", gotUserID)
	}
	if gotToken != "abc123" {
		t.Errorf("expected abc123, got %s", gotToken)
	}
	if gotPlatform != domain.PlatformIOS {
		t.Errorf("expected ios, got %s", gotPlatform)
	}
}

func TestDeviceHandler_Create_MissingAuth(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodPost, "/api/v1/devices", strings.NewReader(`{"token":"abc","platform":"ios"}`))
	h.Create(w, r)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestDeviceHandler_Create_InvalidJSON(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodPost, "/api/v1/devices", `{invalid`, "user-1")
	h.Create(w, r)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestDeviceHandler_Create_ValidationError_MissingFields(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodPost, "/api/v1/devices", `{}`, "user-1")
	h.Create(w, r)

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestDeviceHandler_Create_ValidationError_InvalidPlatform(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodPost, "/api/v1/devices", `{"token":"abc","platform":"windows"}`, "user-1")
	h.Create(w, r)

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}
}

func TestDeviceHandler_Create_RepoError(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error {
			return errors.New("db error")
		},
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodPost, "/api/v1/devices", `{"token":"abc","platform":"android"}`, "user-1")
	h.Create(w, r)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", w.Code)
	}
}

// --- Delete Tests ---

func TestDeviceHandler_Delete_Success(t *testing.T) {
	t.Parallel()

	var deletedUserID, deletedToken string

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
		deleteFn: func(_ context.Context, userID, token string) error {
			deletedUserID = userID
			deletedToken = token
			return nil
		},
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodDelete, "/api/v1/devices/abc123", "", "user-1")
	r = withChiParam(r, "token", "abc123")
	h.Delete(w, r)

	if w.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d: %s", w.Code, w.Body.String())
	}
	if deletedToken != "abc123" {
		t.Errorf("expected abc123, got %s", deletedToken)
	}
	if deletedUserID != "user-1" {
		t.Errorf("delete must be scoped to the caller, got user %q", deletedUserID)
	}
}

func TestDeviceHandler_Delete_Unauthenticated(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
		deleteFn: func(_ context.Context, _, _ string) error { return nil },
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodDelete, "/api/v1/devices/abc123", nil)
	r = withChiParam(r, "token", "abc123")
	h.Delete(w, r)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestDeviceHandler_Delete_MissingToken(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
		deleteFn: func(_ context.Context, _, _ string) error { return nil },
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodDelete, "/api/v1/devices/", "", "user-1")
	r = withChiParam(r, "token", "")
	h.Delete(w, r)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

func TestDeviceHandler_Delete_RepoError(t *testing.T) {
	t.Parallel()

	h := handler.NewDeviceHandler(&mockDeviceRepo{
		upsertFn: func(_ context.Context, _, _ string, _ domain.Platform) error { return nil },
		deleteFn: func(_ context.Context, _, _ string) error {
			return errors.New("db error")
		},
	}, &mockNotifier{})

	w := httptest.NewRecorder()
	r := authedRequest(http.MethodDelete, "/api/v1/devices/abc123", "", "user-1")
	r = withChiParam(r, "token", "abc123")
	h.Delete(w, r)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", w.Code)
	}
}
