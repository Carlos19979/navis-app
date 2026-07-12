package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// costService is the service surface the cost handler consumes.
type costService interface {
	Get(ctx context.Context, userID, boatID string) (*domain.CostAnalytics, error)
}

// CostHandler serves the cost-analytics endpoint.
type CostHandler struct {
	svc costService
}

// NewCostHandler creates a new CostHandler.
func NewCostHandler(svc costService) *CostHandler {
	return &CostHandler{svc: svc}
}

// Get handles GET /boats/{id}/cost-analytics.
func (h *CostHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boatID := chi.URLParam(r, "id")
	analytics, err := h.svc.Get(r.Context(), userID, boatID)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.CostAnalyticsResponseFromDomain(analytics))
}
