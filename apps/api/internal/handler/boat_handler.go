package handler

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// boatService is the service surface the boat handlers consume
// (boat_handler.go and boat_share_handler.go).
type boatService interface {
	Create(ctx context.Context, boat *domain.Boat) (*domain.Boat, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Boat, error)
	GetAccessible(ctx context.Context, userID, id string) (*domain.Boat, error)
	List(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error)
	Update(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error)
	Delete(ctx context.Context, userID, id string) error
	EffectivePermissions(ctx context.Context, userID, boatID string) (domain.BoatPermissions, error)
	ShareCode(ctx context.Context, userID, boatID string) (string, error)
	JoinByCode(ctx context.Context, userID, code string) (*domain.SharedBoat, error)
	ListShared(ctx context.Context, userID string) ([]domain.SharedBoat, error)
	ListMembers(ctx context.Context, userID, boatID string) ([]domain.BoatMember, error)
	RemoveMember(ctx context.Context, ownerID, boatID, memberUserID string) error
	SetMemberPermissions(ctx context.Context, ownerID, boatID, memberUserID string, p domain.BoatPermissions) error
	Leave(ctx context.Context, userID, boatID string) error
}

// BoatHandler handles HTTP requests for boat operations.
type BoatHandler struct {
	svc boatService
}

// NewBoatHandler creates a new BoatHandler.
func NewBoatHandler(svc boatService) *BoatHandler {
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

	JSON(w, http.StatusCreated, dto.OwnedBoatResponseFromDomain(created))
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

	// The client gates its UI on these flags, so a failed lookup must surface as
	// an error rather than as "you may do nothing".
	perms, err := h.svc.EffectivePermissions(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.BoatResponseFromDomain(boat, userID, perms))
}

// Permissions handles GET /boats/{id}/permissions — the caller's effective
// permission set on the boat. Its own endpoint (rather than only the field on
// the boat detail) so screens that hold just a boat id — documents,
// maintenance, expenses — can resolve and cache it without refetching the boat.
func (h *BoatHandler) Permissions(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	id := chi.URLParam(r, "id")
	perms, err := h.svc.EffectivePermissions(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.BoatEffectivePermissionsResponseFromDomain(id, perms))
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

	JSONWithMeta(w, http.StatusOK, dto.OwnedBoatListResponseFromDomain(boats), metaFromCursor(nextCursor))
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

	JSON(w, http.StatusOK, dto.OwnedBoatResponseFromDomain(updated))
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
