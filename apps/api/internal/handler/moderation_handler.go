package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// moderationService is the service surface the moderation handlers consume.
type moderationService interface {
	CreateReport(ctx context.Context, report *domain.Report) error
	BlockUser(ctx context.Context, blockerID, blockedID string) error
	UnblockUser(ctx context.Context, blockerID, blockedID string) error
	ListBlocked(ctx context.Context, blockerID string) ([]string, error)
}

// ModerationHandler handles content reports and user blocks (App Store guideline 1.2).
type ModerationHandler struct {
	svc moderationService
}

// NewModerationHandler creates a new ModerationHandler.
func NewModerationHandler(svc moderationService) *ModerationHandler {
	return &ModerationHandler{svc: svc}
}

// Report handles POST /reports — flag objectionable content for operator review.
func (h *ModerationHandler) Report(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.CreateReportRequest](w, r)
	if !ok {
		return
	}

	if err := h.svc.CreateReport(r.Context(), req.ToDomain(userID)); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusCreated)
}

// Block handles POST /users/{id}/block.
func (h *ModerationHandler) Block(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	if err := h.svc.BlockUser(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// Unblock handles DELETE /users/{id}/block.
func (h *ModerationHandler) Unblock(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	if err := h.svc.UnblockUser(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ListBlocked handles GET /me/blocked.
func (h *ModerationHandler) ListBlocked(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	ids, err := h.svc.ListBlocked(r.Context(), userID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.BlockedUsersResponse{BlockedUserIDs: ids})
}
