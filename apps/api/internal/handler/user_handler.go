package handler

import (
	"net/http"

	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// UserHandler handles GDPR data export and account deletion.
type UserHandler struct {
	boats   port.BoatRepository
	docs    port.DocumentRepository
	trips   port.TripRepository
	tracks  port.TripTrackRepository
	devices port.DeviceTokenRepository
}

// NewUserHandler creates a UserHandler with the given repositories.
func NewUserHandler(
	boats port.BoatRepository,
	docs port.DocumentRepository,
	trips port.TripRepository,
	tracks port.TripTrackRepository,
	devices port.DeviceTokenRepository,
) *UserHandler {
	return &UserHandler{
		boats:   boats,
		docs:    docs,
		trips:   trips,
		tracks:  tracks,
		devices: devices,
	}
}

// ExportData returns all user data as a JSON download.
func (h *UserHandler) ExportData(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	boats, _, err := h.boats.List(r.Context(), userID, "", 1000)
	if err != nil {
		Error(w, http.StatusInternalServerError, "failed to export boats", "EXPORT_FAILED")
		return
	}

	docs, _, err := h.docs.List(r.Context(), userID, "", 1000)
	if err != nil {
		Error(w, http.StatusInternalServerError, "failed to export documents", "EXPORT_FAILED")
		return
	}

	trips, _, err := h.trips.List(r.Context(), userID, "", "", 1000)
	if err != nil {
		Error(w, http.StatusInternalServerError, "failed to export trips", "EXPORT_FAILED")
		return
	}

	tracksByTrip := make(map[string]any)
	for _, trip := range trips {
		tracks, trackErr := h.tracks.ListByTrip(r.Context(), trip.ID)
		if trackErr == nil && len(tracks) > 0 {
			tracksByTrip[trip.ID] = tracks
		}
	}

	devices, _ := h.devices.GetByUserID(r.Context(), userID)

	export := map[string]any{
		"user_id":   userID,
		"boats":     boats,
		"documents": docs,
		"trips":     trips,
		"tracks":    tracksByTrip,
		"devices":   devices,
	}

	w.Header().Set("Content-Disposition", "attachment; filename=navis-export.json")
	JSON(w, http.StatusOK, export)
}

// DeleteAccount removes all user data and device tokens.
func (h *UserHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	trips, _, err := h.trips.List(r.Context(), userID, "", "", 1000)
	if err != nil {
		Error(w, http.StatusInternalServerError, "failed to list trips", "DELETE_FAILED")
		return
	}
	for _, trip := range trips {
		_ = h.trips.Delete(r.Context(), userID, trip.ID)
	}

	docs, _, err := h.docs.List(r.Context(), userID, "", 1000)
	if err != nil {
		Error(w, http.StatusInternalServerError, "failed to list documents", "DELETE_FAILED")
		return
	}
	for _, doc := range docs {
		_ = h.docs.Delete(r.Context(), userID, doc.ID)
	}

	boats, _, err := h.boats.List(r.Context(), userID, "", 1000)
	if err != nil {
		Error(w, http.StatusInternalServerError, "failed to list boats", "DELETE_FAILED")
		return
	}
	for _, boat := range boats {
		_ = h.boats.Delete(r.Context(), userID, boat.ID)
	}

	devices, _ := h.devices.GetByUserID(r.Context(), userID)
	for _, d := range devices {
		_ = h.devices.Delete(r.Context(), d.Token)
	}

	w.WriteHeader(http.StatusNoContent)
}
