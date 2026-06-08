package handler

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// EventHandler handles HTTP requests for event operations.
type EventHandler struct {
	svc *service.EventService
}

// NewEventHandler creates a new EventHandler.
func NewEventHandler(svc *service.EventService) *EventHandler {
	return &EventHandler{svc: svc}
}

// List handles GET /events.
func (h *EventHandler) List(w http.ResponseWriter, r *http.Request) {
	cursor, limit := pagination.ParseCursor(r)

	// Check for location-based query parameters.
	latStr := r.URL.Query().Get("lat")
	lonStr := r.URL.Query().Get("lon")
	radiusStr := r.URL.Query().Get("radius_km")

	if latStr != "" && lonStr != "" {
		lat, err := strconv.ParseFloat(latStr, 64)
		if err != nil {
			Error(w, http.StatusBadRequest, "invalid lat parameter", "BAD_REQUEST")
			return
		}
		lon, err := strconv.ParseFloat(lonStr, 64)
		if err != nil {
			Error(w, http.StatusBadRequest, "invalid lon parameter", "BAD_REQUEST")
			return
		}
		radiusKM := 50.0
		if radiusStr != "" {
			if parsed, err := strconv.ParseFloat(radiusStr, 64); err == nil {
				radiusKM = parsed
			}
		}

		events, nextCursor, err := h.svc.NearLocation(r.Context(), lat, lon, radiusKM, cursor, limit)
		if err != nil {
			MapDomainError(w, err)
			return
		}

		var meta *Meta
		if nextCursor != "" {
			encoded := pagination.EncodeCursor(nextCursor)
			meta = &Meta{NextCursor: &encoded}
		}

		JSONWithMeta(w, http.StatusOK, dto.EventListResponseFromDomain(events, h.interestedMap(r, events)), meta)
		return
	}

	// Check for upcoming filter.
	if r.URL.Query().Get("upcoming") == "true" {
		events, nextCursor, err := h.svc.ListUpcoming(r.Context(), cursor, limit)
		if err != nil {
			MapDomainError(w, err)
			return
		}

		var meta *Meta
		if nextCursor != "" {
			encoded := pagination.EncodeCursor(nextCursor)
			meta = &Meta{NextCursor: &encoded}
		}

		JSONWithMeta(w, http.StatusOK, dto.EventListResponseFromDomain(events, h.interestedMap(r, events)), meta)
		return
	}

	// Default: list all events.
	events, nextCursor, err := h.svc.List(r.Context(), cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	var meta *Meta
	if nextCursor != "" {
		encoded := pagination.EncodeCursor(nextCursor)
		meta = &Meta{NextCursor: &encoded}
	}

	JSONWithMeta(w, http.StatusOK, dto.EventListResponseFromDomain(events, h.interestedMap(r, events)), meta)
}

// GetByID handles GET /events/{id}.
func (h *EventHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	event, err := h.svc.GetByID(r.Context(), id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	interested := false
	if userID, ok := middleware.UserIDFromContext(r.Context()); ok {
		interested, _ = h.svc.IsInterested(r.Context(), userID, id)
	}

	JSON(w, http.StatusOK, dto.EventResponseFromDomain(event, interested))
}

// interestedMap resolves which of the given events the current user likes.
func (h *EventHandler) interestedMap(r *http.Request, events []domain.Event) map[string]bool {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok || len(events) == 0 {
		return nil
	}
	ids := make([]string, len(events))
	for i := range events {
		ids[i] = events[i].ID
	}
	m, err := h.svc.InterestedIn(r.Context(), userID, ids)
	if err != nil {
		return nil
	}
	return m
}

// ToggleInterest handles POST /events/{id}/interest.
func (h *EventHandler) ToggleInterest(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	eventID := chi.URLParam(r, "id")

	interested, err := h.svc.ToggleInterest(r.Context(), userID, eventID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, map[string]bool{"interested": interested})
}
