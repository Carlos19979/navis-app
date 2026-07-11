package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// ShareCode handles PUT /boats/{id}/share-code — owner generates/returns code.
func (h *BoatHandler) ShareCode(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	code, err := h.svc.ShareCode(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.BoatShareCodeResponse{Code: code})
}

// Join handles POST /boats/join — join a boat by its share code.
func (h *BoatHandler) Join(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.JoinBoatRequest](w, r)
	if !ok {
		return
	}
	boat, err := h.svc.JoinByCode(r.Context(), userID, req.Code)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.BoatResponseFromDomain(boat))
}

// ListShared handles GET /boats/shared — boats shared with the user.
func (h *BoatHandler) ListShared(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	boats, err := h.svc.ListShared(r.Context(), userID)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.BoatListResponseFromDomain(boats))
}

// ListMembers handles GET /boats/{id}/members — owner sees shared members.
func (h *BoatHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	members, err := h.svc.ListMembers(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.BoatMemberListFromDomain(members))
}

// RemoveMember handles DELETE /boats/{id}/members/{userId} — owner revokes.
func (h *BoatHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	if err := h.svc.RemoveMember(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "userId")); err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// SetMemberPermissions handles PUT /boats/{id}/members/{userId}/permissions —
// owner sets a member's granular permission flags.
func (h *BoatHandler) SetMemberPermissions(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.UpdateBoatMemberPermissionsRequest](w, r)
	if !ok {
		return
	}
	if err := h.svc.SetMemberPermissions(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "userId"), req.ToDomain()); err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Leave handles POST /boats/{id}/leave — a member leaves a shared boat.
func (h *BoatHandler) Leave(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	if err := h.svc.Leave(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
