package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
)

// TripHandler handles HTTP requests for trip operations.
type TripHandler struct {
	svc *service.TripService
}

// NewTripHandler creates a new TripHandler.
func NewTripHandler(svc *service.TripService) *TripHandler {
	return &TripHandler{svc: svc}
}

// Create handles POST /boats/{boatId}/trips.
func (h *TripHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	var req dto.CreateTripRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	// Override BoatID from URL parameter.
	boatID := chi.URLParam(r, "boatId")
	if boatID != "" {
		req.BoatID = boatID
	}

	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
		return
	}

	trip := req.ToDomain(userID)
	created, err := h.svc.Create(r.Context(), trip)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusCreated, dto.TripResponseFromDomain(created))
}

// GetByID handles GET /trips/{id}.
func (h *TripHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	id := chi.URLParam(r, "id")
	trip, err := h.svc.GetByID(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(trip))
}

// List handles GET /boats/{boatId}/trips.
func (h *TripHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	cursor, limit := pagination.ParseCursor(r)
	trips, nextCursor, err := h.svc.List(r.Context(), userID, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	var meta *Meta
	if nextCursor != "" {
		encoded := pagination.EncodeCursor(nextCursor)
		meta = &Meta{NextCursor: &encoded}
	}

	JSONWithMeta(w, http.StatusOK, dto.TripListResponseFromDomain(trips), meta)
}

// Update handles PUT /trips/{id}.
func (h *TripHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	id := chi.URLParam(r, "id")

	// For trip updates, we accept a partial trip payload.
	// We re-use the existing trip data and overwrite sent fields.
	existing, err := h.svc.GetByID(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	// Decode the request body into a map to apply partial updates.
	var updates map[string]json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&updates); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	if v, ok := updates["notes"]; ok {
		var notes *string
		if err := json.Unmarshal(v, &notes); err == nil {
			existing.Notes = notes
		}
	}
	if v, ok := updates["crew_members"]; ok {
		var crew []string
		if err := json.Unmarshal(v, &crew); err == nil {
			existing.CrewMembers = crew
		}
	}
	if v, ok := updates["photos"]; ok {
		var photos []string
		if err := json.Unmarshal(v, &photos); err == nil {
			existing.Photos = photos
		}
	}

	updated, err := h.svc.Update(r.Context(), userID, existing)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(updated))
}

// Complete handles PUT /trips/{id}/complete.
func (h *TripHandler) Complete(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	id := chi.URLParam(r, "id")

	var req dto.CompleteTripRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
		return
	}

	trip, err := h.svc.Complete(r.Context(), userID, id, req.ArrivalPort, req.DistanceNM, req.EngineHours, req.FuelConsumedL)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(trip))
}

// AddTracks handles POST /trips/{id}/tracks.
func (h *TripHandler) AddTracks(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	tripID := chi.URLParam(r, "id")

	var req dto.BatchTrackRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
		return
	}

	tracks, err := req.ToDomain(tripID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	if err := h.svc.AddTrackPoints(r.Context(), userID, tracks); err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusCreated, map[string]int{"count": len(tracks)})
}
