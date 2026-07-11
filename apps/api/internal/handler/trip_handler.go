package handler

import (
	"context"
	"encoding/json"
	"math"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
)

// tripService is the service surface the trip handlers consume
// (trip_handler.go and trip_share_handler.go).
type tripService interface {
	Create(ctx context.Context, trip *domain.Trip) (*domain.Trip, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Trip, error)
	List(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Trip, string, error)
	Update(ctx context.Context, userID string, trip *domain.Trip) (*domain.Trip, error)
	Complete(ctx context.Context, userID, id string, arrivalPort *string, distanceNM, engineHours, fuelConsumedL *float64) (*domain.Trip, error)
	Delete(ctx context.Context, userID, id string) error
	AddTrackPoints(ctx context.Context, userID string, tracks []domain.TripTrack) error
	GetTrackPoints(ctx context.Context, userID, tripID string) ([]domain.TripTrack, error)
	Share(ctx context.Context, userID, tripID string) (string, error)
	Unshare(ctx context.Context, userID, tripID string) error
	PublicByToken(ctx context.Context, token string) (*domain.Trip, []domain.TripTrack, error)
}

// TripHandler handles HTTP requests for trip operations.
type TripHandler struct {
	svc tripService
}

// NewTripHandler creates a new TripHandler.
func NewTripHandler(svc tripService) *TripHandler {
	return &TripHandler{svc: svc}
}

// Create handles POST /boats/{boatId}/trips.
func (h *TripHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	var req dto.CreateTripRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	validator.TrimStrings(&req)

	// Override BoatID from URL parameter.
	boatID := chi.URLParam(r, "id")
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
	userID, ok := requireUserID(w, r)
	if !ok {
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
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	boatID := chi.URLParam(r, "id")
	cursor, limit := pagination.ParseCursor(r)
	trips, nextCursor, err := h.svc.List(r.Context(), userID, boatID, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.TripListResponseFromDomain(trips), metaFromCursor(nextCursor))
}

// Update handles PUT /trips/{id}.
func (h *TripHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
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
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	id := chi.URLParam(r, "id")

	req, ok := decodeAndValidate[dto.CompleteTripRequest](w, r)
	if !ok {
		return
	}

	trip, err := h.svc.Complete(r.Context(), userID, id, req.ArrivalPort, req.DistanceNM, req.EngineHours, req.FuelConsumedL)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(trip))
}

// Delete handles DELETE /trips/{id}.
func (h *TripHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	id := chi.URLParam(r, "id")
	if err := h.svc.Delete(r.Context(), userID, id); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// AddTracks handles POST /trips/{id}/tracks.
func (h *TripHandler) AddTracks(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	tripID := chi.URLParam(r, "id")

	req, ok := decodeAndValidate[dto.BatchTrackRequest](w, r)
	if !ok {
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

// GetTracks handles GET /trips/{id}/tracks?simplify=0.0001.
// Returns track points, optionally simplified with Douglas-Peucker.
func (h *TripHandler) GetTracks(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	tripID := chi.URLParam(r, "id")
	tracks, err := h.svc.GetTrackPoints(r.Context(), userID, tripID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	if epsilon := r.URL.Query().Get("simplify"); epsilon != "" {
		if eps, err := strconv.ParseFloat(epsilon, 64); err == nil && eps > 0 {
			tracks = simplifyTracks(tracks, eps)
		}
	}

	JSON(w, http.StatusOK, dto.TrackPointListResponseFromDomain(tracks))
}

type point2D struct {
	lat, lon float64
	idx      int
}

func simplifyTracks(tracks []domain.TripTrack, epsilon float64) []domain.TripTrack {
	if len(tracks) <= 2 {
		return tracks
	}

	pts := make([]point2D, len(tracks))
	for i, t := range tracks {
		pts[i] = point2D{lat: t.Lat, lon: t.Lon, idx: i}
	}

	kept := dpSimplify(pts, epsilon)
	result := make([]domain.TripTrack, len(kept))
	for i, p := range kept {
		result[i] = tracks[p.idx]
	}
	return result
}

func dpSimplify(points []point2D, epsilon float64) []point2D {
	if len(points) <= 2 {
		return points
	}

	maxDist := 0.0
	maxIdx := 0
	first, last := points[0], points[len(points)-1]
	for i, p := range points[1 : len(points)-1] {
		if d := perpDist(p, first, last); d > maxDist {
			maxDist = d
			maxIdx = i + 1
		}
	}

	if maxDist > epsilon {
		left := dpSimplify(points[:maxIdx+1], epsilon)
		right := dpSimplify(points[maxIdx:], epsilon)
		return append(left[:len(left)-1], right...)
	}

	return []point2D{points[0], points[len(points)-1]}
}

func perpDist(p, a, b point2D) float64 {
	dx := b.lon - a.lon
	dy := b.lat - a.lat
	if dx == 0 && dy == 0 {
		return math.Hypot(p.lon-a.lon, p.lat-a.lat)
	}
	num := math.Abs(dy*p.lon - dx*p.lat + b.lon*a.lat - b.lat*a.lon)
	den := math.Hypot(dx, dy)
	return num / den
}
