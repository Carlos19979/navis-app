package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// anomalyService is the service surface the anomaly handler consumes.
type anomalyService interface {
	ForBoat(ctx context.Context, userID, boatID string) ([]domain.Anomaly, error)
}

// AnomalyHandler serves the anomaly-detection endpoint.
type AnomalyHandler struct {
	svc anomalyService
}

// NewAnomalyHandler creates a new AnomalyHandler.
func NewAnomalyHandler(svc anomalyService) *AnomalyHandler {
	return &AnomalyHandler{svc: svc}
}

// List handles GET /boats/{id}/anomalies.
func (h *AnomalyHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	anomalies, err := h.svc.ForBoat(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.AnomalyListFromDomain(anomalies))
}
