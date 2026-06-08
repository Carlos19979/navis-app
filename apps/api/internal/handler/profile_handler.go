package handler

import (
	"encoding/json"
	"net/http"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
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
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	var req dto.UpdatePlanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}
	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
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
