package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// PortHandler handles HTTP requests for port operations.
type PortHandler struct {
	svc *service.PortService
}

// NewPortHandler creates a new PortHandler.
func NewPortHandler(svc *service.PortService) *PortHandler {
	return &PortHandler{svc: svc}
}

// Nearby handles GET /ports/nearby.
func (h *PortHandler) Nearby(w http.ResponseWriter, r *http.Request) {
	latStr := r.URL.Query().Get("lat")
	lonStr := r.URL.Query().Get("lon")

	if latStr == "" || lonStr == "" {
		Error(w, http.StatusBadRequest, "lat and lon query parameters are required", "BAD_REQUEST")
		return
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil || lat < -90 || lat > 90 {
		Error(w, http.StatusBadRequest, "invalid lat parameter", "BAD_REQUEST")
		return
	}
	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil || lon < -180 || lon > 180 {
		Error(w, http.StatusBadRequest, "invalid lon parameter", "BAD_REQUEST")
		return
	}

	radiusKM := 50.0
	if radiusStr := r.URL.Query().Get("radius_km"); radiusStr != "" {
		if parsed, err := strconv.ParseFloat(radiusStr, 64); err == nil && parsed > 0 {
			radiusKM = parsed
		}
	}

	cursor, limit := pagination.ParseCursor(r)

	ports, nextCursor, err := h.svc.NearLocation(r.Context(), lat, lon, radiusKM, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.PortListResponseFromDomain(ports), metaFromCursor(nextCursor))
}

// GetByID handles GET /ports/{id}.
func (h *PortHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	p, err := h.svc.GetByID(r.Context(), id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.PortResponseFromDomain(p))
}
