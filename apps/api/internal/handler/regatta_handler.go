package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// RegattaHandler handles HTTP requests for group regattas, RSVP and checklists.
type RegattaHandler struct {
	svc *service.RegattaService
}

// NewRegattaHandler creates a new RegattaHandler.
func NewRegattaHandler(svc *service.RegattaService) *RegattaHandler {
	return &RegattaHandler{svc: svc}
}

// Schedule handles POST /groups/{id}/trips.
func (h *RegattaHandler) Schedule(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.ScheduleRegattaRequest](w, r)
	if !ok {
		return
	}

	trip, err := h.svc.Schedule(r.Context(), uid, chi.URLParam(r, "id"), req.ToDomain())
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusCreated, dto.TripResponseFromDomain(trip))
}

// ListGroupTrips handles GET /groups/{id}/trips.
func (h *RegattaHandler) ListGroupTrips(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	cursor, limit := pagination.ParseCursor(r)
	trips, nextCursor, err := h.svc.ListByGroup(r.Context(), uid, chi.URLParam(r, "id"), cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.TripListResponseFromDomain(trips), metaFromCursor(nextCursor))
}

// SetRSVP handles POST /trips/{id}/rsvp.
func (h *RegattaHandler) SetRSVP(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.RSVPRequest](w, r)
	if !ok {
		return
	}

	if err := h.svc.SetRSVP(r.Context(), uid, chi.URLParam(r, "id"), domain.RSVP(req.RSVP)); err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, map[string]string{"rsvp": req.RSVP})
}

// ListParticipants handles GET /trips/{id}/participants.
func (h *RegattaHandler) ListParticipants(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	participants, err := h.svc.ListParticipants(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripParticipantListResponseFromDomain(participants))
}

// Start handles PUT /trips/{id}/start.
func (h *RegattaHandler) Start(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	trip, err := h.svc.Start(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(trip))
}

// Revert handles PUT /trips/{id}/revert (recording -> planned).
func (h *RegattaHandler) Revert(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	trip, err := h.svc.RevertToPlanned(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(trip))
}

// Cancel handles PUT /trips/{id}/cancel.
func (h *RegattaHandler) Cancel(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	trip, err := h.svc.Cancel(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(trip))
}

// GetChecklist handles GET /trips/{id}/checklist.
func (h *RegattaHandler) GetChecklist(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	items, err := h.svc.GetChecklist(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.ChecklistItemListResponseFromDomain(items))
}

// AddChecklistItem handles POST /trips/{id}/checklist.
func (h *RegattaHandler) AddChecklistItem(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.ChecklistAddItemRequest](w, r)
	if !ok {
		return
	}

	item, err := h.svc.AddChecklistItem(r.Context(), uid, chi.URLParam(r, "id"), req.Label)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusCreated, dto.ChecklistItemResponseFromDomain(item))
}

// SetChecklistItem handles PUT /trips/{id}/checklist/{itemId}.
func (h *RegattaHandler) SetChecklistItem(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.ChecklistSetCheckedRequest](w, r)
	if !ok {
		return
	}

	item, err := h.svc.SetChecklistItemChecked(
		r.Context(), uid, chi.URLParam(r, "id"), chi.URLParam(r, "itemId"), req.IsChecked)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.ChecklistItemResponseFromDomain(item))
}

// RemoveChecklistItem handles DELETE /trips/{id}/checklist/{itemId}.
func (h *RegattaHandler) RemoveChecklistItem(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	if err := h.svc.RemoveChecklistItem(
		r.Context(), uid, chi.URLParam(r, "id"), chi.URLParam(r, "itemId")); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// CompleteChecklist handles PUT /trips/{id}/checklist/complete.
func (h *RegattaHandler) CompleteChecklist(w http.ResponseWriter, r *http.Request) {
	uid, ok := requireUserID(w, r)
	if !ok {
		return
	}

	trip, err := h.svc.CompleteChecklist(r.Context(), uid, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.TripResponseFromDomain(trip))
}
