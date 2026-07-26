package handler

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// portService is the service surface the port handlers consume.
type portService interface {
	GetByID(ctx context.Context, id string) (*domain.Port, error)
	NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Port, string, error)
	WithinBBox(ctx context.Context, minLon, minLat, maxLon, maxLat float64, cursor string, limit int) ([]domain.Port, string, error)
	Search(ctx context.Context, query string, nearLat, nearLon *float64, cursor string, limit int) ([]domain.Port, string, error)
}

// PortHandler handles HTTP requests for port operations.
type PortHandler struct {
	svc portService
}

// NewPortHandler creates a new PortHandler.
func NewPortHandler(svc portService) *PortHandler {
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

// List handles the public GET /ports. It supports two modes:
//   - search:  ?q=<text>[&near=<lat>,<lon>] — name search, optionally ordered
//     by distance to near (powers the port pickers).
//   - viewport: ?bbox=minLon,minLat,maxLon,maxLat — ports inside the visible
//     map area (powers the chart map).
//
// q takes precedence when both are present.
func (h *PortHandler) List(w http.ResponseWriter, r *http.Request) {
	if q := r.URL.Query().Get("q"); q != "" {
		h.search(w, r, q)
		return
	}

	bboxStr := r.URL.Query().Get("bbox")
	if bboxStr == "" {
		Error(w, http.StatusBadRequest, "bbox or q query parameter is required", "BAD_REQUEST")
		return
	}

	minLon, minLat, maxLon, maxLat, err := parseBBox(bboxStr)
	if err != nil {
		Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
		return
	}

	// The viewport feed gets a higher page ceiling than the API default so a
	// map screen fetches its markers in one request instead of walking pages.
	cursor, limit := pagination.ParseCursorTo(r, pagination.MaxViewportLimit)

	ports, nextCursor, err := h.svc.WithinBBox(r.Context(), minLon, minLat, maxLon, maxLat, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.PortListResponseFromDomain(ports), metaFromCursor(nextCursor))
}

// search handles the ?q= mode of List, parsing the optional near point.
func (h *PortHandler) search(w http.ResponseWriter, r *http.Request, q string) {
	var nearLat, nearLon *float64
	if nearStr := r.URL.Query().Get("near"); nearStr != "" {
		lat, lon, err := parseNearPoint(nearStr)
		if err != nil {
			Error(w, http.StatusBadRequest, err.Error(), "BAD_REQUEST")
			return
		}
		nearLat, nearLon = &lat, &lon
	}

	cursor, limit := pagination.ParseCursor(r)

	ports, nextCursor, err := h.svc.Search(r.Context(), q, nearLat, nearLon, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.PortListResponseFromDomain(ports), metaFromCursor(nextCursor))
}

// parseNearPoint parses a "lat,lon" string into its two float components.
func parseNearPoint(s string) (lat, lon float64, err error) {
	parts := strings.Split(s, ",")
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("near must be lat,lon")
	}
	lat, err = strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
	if err != nil {
		return 0, 0, fmt.Errorf("near contains a non-numeric value")
	}
	lon, err = strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
	if err != nil {
		return 0, 0, fmt.Errorf("near contains a non-numeric value")
	}
	return lat, lon, nil
}

// parseBBox parses a "minLon,minLat,maxLon,maxLat" string into its four
// float components. It only checks the wire format; semantic validation
// (ranges, ordering, span) lives in the service.
func parseBBox(s string) (minLon, minLat, maxLon, maxLat float64, err error) {
	parts := strings.Split(s, ",")
	if len(parts) != 4 {
		return 0, 0, 0, 0, fmt.Errorf("bbox must be minLon,minLat,maxLon,maxLat")
	}

	vals := make([]float64, 4)
	for i, p := range parts {
		v, parseErr := strconv.ParseFloat(strings.TrimSpace(p), 64)
		if parseErr != nil {
			return 0, 0, 0, 0, fmt.Errorf("bbox contains a non-numeric value")
		}
		vals[i] = v
	}

	return vals[0], vals[1], vals[2], vals[3], nil
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
