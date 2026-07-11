package handler

import (
	"net/http"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
)

// ProfileHandler exposes the current user's plan and limits.
type ProfileHandler struct {
	svc *service.ProfileService
}

// NewProfileHandler creates a new ProfileHandler.
func NewProfileHandler(svc *service.ProfileService) *ProfileHandler {
	return &ProfileHandler{svc: svc}
}

// Me handles GET /me.
func (h *ProfileHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	profile, boatCount, err := h.svc.Me(r.Context(), userID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.MeResponseFromDomain(profile, boatCount))
}

// UpdatePlan handles PUT /me/plan. Used by the dev plan switcher; in production
// this would be driven by a payment webhook instead of the user.
func (h *ProfileHandler) UpdatePlan(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	req, ok := decodeAndValidate[dto.UpdatePlanRequest](w, r)
	if !ok {
		return
	}

	profile, err := h.svc.SetPlan(r.Context(), userID, domain.Plan(req.Plan))
	if err != nil {
		MapDomainError(w, err)
		return
	}

	boatCount := 0
	if _, c, err := h.svc.Me(r.Context(), userID); err == nil {
		boatCount = c
	}
	JSON(w, http.StatusOK, dto.MeResponseFromDomain(profile, boatCount))
}
