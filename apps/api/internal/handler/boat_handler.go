package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// BoatHandler handles HTTP requests for boat operations.
type BoatHandler struct {
	svc *service.BoatService
}

// NewBoatHandler creates a new BoatHandler.
func NewBoatHandler(svc *service.BoatService) *BoatHandler {
	return &BoatHandler{svc: svc}
}

// Create handles POST /boats.
func (h *BoatHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.CreateBoatRequest](w, r)
	if !ok {
		return
	}

	boat := req.ToDomain(userID)
	created, err := h.svc.Create(r.Context(), boat)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusCreated, dto.BoatResponseFromDomain(created))
}

// GetByID handles GET /boats/{id}.
func (h *BoatHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	id := chi.URLParam(r, "id")
	// Accessible to the owner or shared members (read-only for members).
	boat, err := h.svc.GetAccessible(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	resp := dto.BoatResponseFromDomain(boat)
	resp.IsOwner = boat.UserID == userID
	perms, _, _ := h.svc.Permissions(r.Context(), userID, id)
	resp.Permissions = dto.BoatPermissionsResponseFromDomain(perms)
	JSON(w, http.StatusOK, resp)
}

// List handles GET /boats.
func (h *BoatHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	cursor, limit := pagination.ParseCursor(r)
	boats, nextCursor, err := h.svc.List(r.Context(), userID, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.BoatListResponseFromDomain(boats), metaFromCursor(nextCursor))
}

// Update handles PUT /boats/{id}.
func (h *BoatHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	id := chi.URLParam(r, "id")

	req, ok := decodeAndValidate[dto.UpdateBoatRequest](w, r)
	if !ok {
		return
	}

	// Fetch existing boat, apply partial updates.
	existing, err := h.svc.GetByID(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	req.ApplyTo(existing)
	updated, err := h.svc.Update(r.Context(), userID, existing)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.BoatResponseFromDomain(updated))
}

// Delete handles DELETE /boats/{id}.
func (h *BoatHandler) Delete(w http.ResponseWriter, r *http.Request) {
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
