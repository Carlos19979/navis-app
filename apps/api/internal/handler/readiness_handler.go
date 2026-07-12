package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// readinessService is the service surface the readiness handler consumes.
type readinessService interface {
	Get(ctx context.Context, userID, boatID string) (*domain.Readiness, error)
}

// ReadinessHandler serves the boat-readiness endpoint.
type ReadinessHandler struct {
	svc readinessService
}

// NewReadinessHandler creates a new ReadinessHandler.
func NewReadinessHandler(svc readinessService) *ReadinessHandler {
	return &ReadinessHandler{svc: svc}
}

// Get handles GET /boats/{id}/readiness.
func (h *ReadinessHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boatID := chi.URLParam(r, "id")
	readiness, err := h.svc.Get(r.Context(), userID, boatID)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.ReadinessResponseFromDomain(readiness))
}
