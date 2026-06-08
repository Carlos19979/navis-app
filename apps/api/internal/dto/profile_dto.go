package dto

import "github.com/Carlos19979/navis-app/apps/api/internal/domain"

// MeResponse describes the current user's plan and derived limits.
type MeResponse struct {
	Plan            string `json:"plan"`
	MaxBoats        int    `json:"max_boats"`
	BoatCount       int    `json:"boat_count"`
	CanCreateGroups bool   `json:"can_create_groups"`
}

// MeResponseFromDomain builds a MeResponse from a profile and boat count.
func MeResponseFromDomain(p *domain.Profile, boatCount int) MeResponse {
	return MeResponse{
		Plan:            string(p.Plan),
		MaxBoats:        p.Plan.MaxBoats(),
		BoatCount:       boatCount,
		CanCreateGroups: p.Plan.CanCreateGroups(),
	}
}

// UpdatePlanRequest is the payload for changing the current user's plan.
type UpdatePlanRequest struct {
	Plan string `json:"plan" validate:"required,oneof=normal armador gestor"`
}
