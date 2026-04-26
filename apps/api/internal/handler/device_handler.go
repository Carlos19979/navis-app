package handler

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
)

type deviceRepo interface {
	Upsert(ctx context.Context, userID, token string, platform domain.Platform) error
	Delete(ctx context.Context, token string) error
}

// DeviceHandler handles device token registration and removal.
type DeviceHandler struct {
	repo deviceRepo
}

// NewDeviceHandler creates a new DeviceHandler.
func NewDeviceHandler(repo deviceRepo) *DeviceHandler {
	return &DeviceHandler{repo: repo}
}

// Create registers or updates a device token.
func (h *DeviceHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "missing user", "UNAUTHORIZED")
		return
	}

	var req dto.CreateDeviceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
		return
	}

	if err := h.repo.Upsert(r.Context(), userID, req.Token, domain.Platform(req.Platform)); err != nil {
		Error(w, http.StatusInternalServerError, "failed to register device", "INTERNAL_ERROR")
		return
	}

	JSON(w, http.StatusCreated, map[string]string{"status": "registered"})
}

// Delete removes a device token.
func (h *DeviceHandler) Delete(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	if token == "" {
		Error(w, http.StatusBadRequest, "token is required", "BAD_REQUEST")
		return
	}

	if err := h.repo.Delete(r.Context(), token); err != nil {
		Error(w, http.StatusInternalServerError, "failed to delete device token", "INTERNAL_ERROR")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
