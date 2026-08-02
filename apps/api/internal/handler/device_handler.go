package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

type deviceRepo interface {
	Upsert(ctx context.Context, userID, token string, platform domain.Platform) error
	Delete(ctx context.Context, userID, token string) error
}

type notificationProvider interface {
	EnsureSubscriber(ctx context.Context, subscriberID, email, name string) error
	SetPushToken(ctx context.Context, subscriberID, token string) error
	RemovePushToken(ctx context.Context, subscriberID, token string) error
}

// subscriberDirectory resolves the details the provider needs to reach a user
// on channels other than push.
type subscriberDirectory interface {
	DisplayName(ctx context.Context, userID string) (string, error)
	Email(ctx context.Context, userID string) (string, error)
}

// DeviceHandler handles device token registration and removal.
type DeviceHandler struct {
	repo     deviceRepo
	notifier notificationProvider
	users    subscriberDirectory
}

// NewDeviceHandler creates a new DeviceHandler.
func NewDeviceHandler(repo deviceRepo, notifier notificationProvider, users subscriberDirectory) *DeviceHandler {
	return &DeviceHandler{repo: repo, notifier: notifier, users: users}
}

// Create registers or updates a device token.
func (h *DeviceHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.CreateDeviceRequest](w, r)
	if !ok {
		return
	}

	if err := h.repo.Upsert(r.Context(), userID, req.Token, domain.Platform(req.Platform)); err != nil {
		Error(w, http.StatusInternalServerError, "failed to register device", "INTERNAL_ERROR")
		return
	}

	// Registering a device is the one moment we are sure who the user is, so
	// it doubles as the point where the provider-side subscriber gets an email
	// address. Without it every email step ends as "Subscriber missing email
	// address" — the fallback for when push does not arrive could not deliver.
	// Lookup failures must not fail the registration: push still works.
	email, name := h.subscriberDetails(r.Context(), userID)
	_ = h.notifier.EnsureSubscriber(r.Context(), userID, email, name)
	_ = h.notifier.SetPushToken(r.Context(), userID, req.Token)

	JSON(w, http.StatusCreated, map[string]string{"status": "registered"})
}

// subscriberDetails resolves the user's email and display name, tolerating a
// missing directory or a failed lookup (both yield empty values, which the
// provider then leaves untouched).
func (h *DeviceHandler) subscriberDetails(ctx context.Context, userID string) (email, name string) {
	if h.users == nil {
		return "", ""
	}
	if got, err := h.users.Email(ctx, userID); err == nil {
		email = got
	}
	if got, err := h.users.DisplayName(ctx, userID); err == nil {
		name = got
	}
	return email, name
}

// Delete removes one of the caller's own device tokens. Scoping by user ID
// prevents unregistering another user's device (IDOR).
func (h *DeviceHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	token := chi.URLParam(r, "token")
	if token == "" {
		Error(w, http.StatusBadRequest, "token is required", "BAD_REQUEST")
		return
	}

	if err := h.repo.Delete(r.Context(), userID, token); err != nil {
		Error(w, http.StatusInternalServerError, "failed to delete device token", "INTERNAL_ERROR")
		return
	}

	_ = h.notifier.RemovePushToken(r.Context(), userID, token)

	w.WriteHeader(http.StatusNoContent)
}
