package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// GroupHandler handles HTTP requests for group operations.
type GroupHandler struct {
	svc *service.GroupService
}

// NewGroupHandler creates a new GroupHandler.
func NewGroupHandler(svc *service.GroupService) *GroupHandler {
	return &GroupHandler{svc: svc}
}

// Create handles POST /groups.
func (h *GroupHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.CreateGroupRequest](w, r)
	if !ok {
		return
	}

	created, err := h.svc.Create(r.Context(), req.ToDomain(userID))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusCreated, dto.GroupResponseFromDomain(created))
}

// List handles GET /groups. With ?discover=true it lists joinable public groups.
func (h *GroupHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	cursor, limit := pagination.ParseCursor(r)

	listFn := h.svc.List
	if r.URL.Query().Get("discover") == "true" {
		listFn = h.svc.ListPublic
	}

	groups, nextCursor, err := listFn(r.Context(), userID, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSONWithMeta(w, http.StatusOK, dto.GroupListResponseFromDomain(groups), metaFromCursor(nextCursor))
}

// GetByID handles GET /groups/{id}.
func (h *GroupHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	group, err := h.svc.GetByID(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.GroupResponseFromDomain(group))
}

// Update handles PUT /groups/{id}.
func (h *GroupHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	id := chi.URLParam(r, "id")

	req, ok := decodeAndValidate[dto.UpdateGroupRequest](w, r)
	if !ok {
		return
	}

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

	JSON(w, http.StatusOK, dto.GroupResponseFromDomain(updated))
}

// Delete handles DELETE /groups/{id}.
func (h *GroupHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	if err := h.svc.Delete(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// RequestJoin handles POST /groups/{id}/join (public groups, owner approval).
func (h *GroupHandler) RequestJoin(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	group, err := h.svc.RequestJoin(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.GroupResponseFromDomain(group))
}

// JoinByCode handles POST /groups/join (private groups, invite code).
func (h *GroupHandler) JoinByCode(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.JoinByCodeRequest](w, r)
	if !ok {
		return
	}

	group, err := h.svc.JoinByCode(r.Context(), userID, req.Code)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.GroupResponseFromDomain(group))
}

// Leave handles POST /groups/{id}/leave.
func (h *GroupHandler) Leave(w http.ResponseWriter, r *http.Request) {
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

// ListMembers handles GET /groups/{id}/members.
func (h *GroupHandler) ListMembers(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	members, err := h.svc.ListMembers(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.GroupMemberListResponseFromDomain(members))
}

// RemoveMember handles DELETE /groups/{id}/members/{userId} (owner only).
func (h *GroupHandler) RemoveMember(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	err := h.svc.RemoveMember(r.Context(), userID, chi.URLParam(r, "id"), chi.URLParam(r, "userId"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ListRequests handles GET /groups/{id}/requests (owner only).
func (h *GroupHandler) ListRequests(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	pending, err := h.svc.ListPendingRequests(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.GroupMemberListResponseFromDomain(pending))
}

// ApproveRequest handles POST /groups/{id}/requests/{userId}/approve (owner only).
func (h *GroupHandler) ApproveRequest(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	err := h.svc.ApproveRequest(r.Context(), userID, chi.URLParam(r, "id"), chi.URLParam(r, "userId"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// RejectRequest handles POST /groups/{id}/requests/{userId}/reject (owner only).
func (h *GroupHandler) RejectRequest(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	err := h.svc.RejectRequest(r.Context(), userID, chi.URLParam(r, "id"), chi.URLParam(r, "userId"))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
