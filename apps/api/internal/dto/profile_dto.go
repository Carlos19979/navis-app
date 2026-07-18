package dto

import "github.com/Carlos19979/navis-app/apps/api/internal/domain"

// Entitlements are the plan-derived capabilities the client uses to gate UI.
// The backend enforces the same limits server-side; this is a mirror for UX.
type Entitlements struct {
	MaxBoats             int  `json:"max_boats"`
	BoatCount            int  `json:"boat_count"`
	CanCreateGroups      bool `json:"can_create_groups"`
	ReminderDocLimit     int  `json:"reminder_doc_limit"` // -1 = unlimited
	MaintenanceSchedules bool `json:"maintenance_schedules"`
	AttachmentLimit      int  `json:"attachment_limit"` // -1 = unlimited
	GalleryLimit         int  `json:"gallery_limit"`    // boat photos incl. cover
	FullReadiness        bool `json:"full_readiness"`
	CostAnalytics        bool `json:"cost_analytics"`
	ExportPassport       bool `json:"export_passport"`
	SharedCoordination   bool `json:"shared_coordination"`
	AnomalyAlerts        bool `json:"anomaly_alerts"`
	AnchorAlarm          bool `json:"anchor_alarm"`
}

// MeResponse describes the current user's plan and derived entitlements.
type MeResponse struct {
	Plan         string       `json:"plan"`
	IsPro        bool         `json:"is_pro"`
	Entitlements Entitlements `json:"entitlements"`

	// Deprecated: kept as top-level mirrors for older mobile builds. Prefer
	// Entitlements. Remove once no client reads them.
	MaxBoats        int  `json:"max_boats"`
	BoatCount       int  `json:"boat_count"`
	CanCreateGroups bool `json:"can_create_groups"`
}

// MeResponseFromDomain builds a MeResponse from a profile and boat count.
func MeResponseFromDomain(p *domain.Profile, boatCount int) MeResponse {
	ent := Entitlements{
		MaxBoats:             p.Plan.MaxBoats(),
		BoatCount:            boatCount,
		CanCreateGroups:      p.Plan.CanCreateGroups(),
		ReminderDocLimit:     p.Plan.ReminderDocLimit(),
		MaintenanceSchedules: p.Plan.CanUseMaintenanceSchedules(),
		AttachmentLimit:      p.Plan.AttachmentLimit(),
		GalleryLimit:         p.Plan.GalleryLimit(),
		FullReadiness:        p.Plan.CanUseFullReadiness(),
		CostAnalytics:        p.Plan.CanUseCostAnalytics(),
		ExportPassport:       p.Plan.CanExportPassport(),
		SharedCoordination:   p.Plan.CanUseSharedCoordination(),
		AnomalyAlerts:        p.Plan.CanUseAnomalyAlerts(),
		AnchorAlarm:          p.Plan.CanUseAnchorAlarm(),
	}
	return MeResponse{
		Plan:            string(p.Plan),
		IsPro:           p.Plan.IsPro(),
		Entitlements:    ent,
		MaxBoats:        ent.MaxBoats,
		BoatCount:       ent.BoatCount,
		CanCreateGroups: ent.CanCreateGroups,
	}
}

// UpdatePlanRequest is the payload for the dev-only plan switcher.
type UpdatePlanRequest struct {
	Plan string `json:"plan" validate:"required,oneof=free plus pro"`
}
