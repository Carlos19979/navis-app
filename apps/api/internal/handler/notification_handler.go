package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// notificationService is the service surface the notification handlers consume.
type notificationService interface {
	List(ctx context.Context, userID, cursor string, limit int) ([]domain.Notification, string, error)
	UnreadCount(ctx context.Context, userID string) (int, error)
	MarkRead(ctx context.Context, userID, id string) error
	MarkAllRead(ctx context.Context, userID string) error
	Preferences(ctx context.Context, userID string) ([]domain.CategoryPreference, error)
	SetPreferences(ctx context.Context, userID string, prefs []domain.CategoryPreference) ([]domain.CategoryPreference, error)
}

// NotificationHandler serves the in-app notification feed (the bell icon) and
// the per-category notification preferences.
type NotificationHandler struct {
	svc notificationService
}

// NewNotificationHandler creates a new NotificationHandler.
func NewNotificationHandler(svc notificationService) *NotificationHandler {
	return &NotificationHandler{svc: svc}
}

// List handles GET /notifications — the feed, newest first.
func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	cursor, limit := pagination.ParseCursor(r)
	items, nextCursor, err := h.svc.List(r.Context(), userID, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.NotificationListResponse(items), metaFromCursor(nextCursor))
}

// UnreadCount handles GET /notifications/unread-count — the badge value.
func (h *NotificationHandler) UnreadCount(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	count, err := h.svc.UnreadCount(r.Context(), userID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.UnreadCountResponse{Count: count})
}

// MarkRead handles PUT /notifications/{id}/read.
func (h *NotificationHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	if err := h.svc.MarkRead(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// MarkAllRead handles PUT /notifications/read-all.
func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	if err := h.svc.MarkAllRead(r.Context(), userID); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// GetPreferences handles GET /me/notification-preferences.
func (h *NotificationHandler) GetPreferences(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	prefs, err := h.svc.Preferences(r.Context(), userID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.NotificationPreferencesResponseFromDomain(prefs))
}

// UpdatePreferences handles PUT /me/notification-preferences.
func (h *NotificationHandler) UpdatePreferences(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.UpdateNotificationPreferencesRequest](w, r)
	if !ok {
		return
	}

	prefs, err := h.svc.SetPreferences(r.Context(), userID, req.ToDomain())
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.NotificationPreferencesResponseFromDomain(prefs))
}
