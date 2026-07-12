package domain

import "time"

// Plan is a user's subscription tier.
type Plan string

// Plan values. Navis has a single paid tier (Pro); "fleet"/B2B is future work.
const (
	PlanFree Plan = "free"
	PlanPro  Plan = "pro"
)

// Unlimited is the sentinel for entitlements that have no cap on the Pro plan.
const Unlimited = -1

// Profile holds per-user account data such as the subscription plan.
type Profile struct {
	UserID    string
	Plan      Plan
	CreatedAt time.Time
	UpdatedAt time.Time
}

// IsPro reports whether the plan is the paid tier.
func (p Plan) IsPro() bool {
	return p == PlanPro
}

// MaxBoats returns how many boats the plan allows.
func (p Plan) MaxBoats() int {
	if p == PlanPro {
		return 3
	}
	return 1
}

// CanCreateGroups reports whether the plan may create groups/clubs and events.
func (p Plan) CanCreateGroups() bool {
	return p == PlanPro
}

// ReminderDocLimit is how many documents get expiry reminders. Free users get a
// single reminder (a taste of the hook); Pro is Unlimited.
func (p Plan) ReminderDocLimit() int {
	if p == PlanPro {
		return Unlimited
	}
	return 1
}

// CanUseMaintenanceSchedules reports whether the plan unlocks scheduled
// maintenance reminders (Pro only).
func (p Plan) CanUseMaintenanceSchedules() bool {
	return p == PlanPro
}

// AttachmentLimit is how many attachments a single document may hold. Free is
// capped; Pro is Unlimited.
func (p Plan) AttachmentLimit() int {
	if p == PlanPro {
		return Unlimited
	}
	return 1
}

// CanUseFullReadiness reports whether the plan unlocks the full boat-readiness
// breakdown (documents + safety gear + maintenance/engine hours). Free users see
// only the documents block; Pro sees the complete score.
func (p Plan) CanUseFullReadiness() bool {
	return p == PlanPro
}

// CanUseCostAnalytics reports whether the plan unlocks advanced cost intelligence
// (cost per NM, cost per trip, fuel efficiency, seasonal spend). Free keeps the
// plain expense totals.
func (p Plan) CanUseCostAnalytics() bool {
	return p == PlanPro
}

// CanExportPassport reports whether the plan may export the boat passport dossier
// (PDF with documents, maintenance history, trips and expenses).
func (p Plan) CanExportPassport() bool {
	return p == PlanPro
}

// CanUseFloatPlan reports whether the plan unlocks float plans (filed trip plan,
// check-ins, and overdue email/SMS alerts to shore contacts).
func (p Plan) CanUseFloatPlan() bool {
	return p == PlanPro
}

// CanUseSharedCoordination reports whether the plan unlocks shared-boat
// coordination (bookings calendar and expense splitting among co-owners).
func (p Plan) CanUseSharedCoordination() bool {
	return p == PlanPro
}

// CanUseAnomalyAlerts reports whether the plan unlocks anomaly alerts (e.g. a
// trip whose fuel-per-mile deviates sharply from the boat's history).
func (p Plan) CanUseAnomalyAlerts() bool {
	return p == PlanPro
}

// CanUseAutoTripDetection reports whether the plan unlocks automatic trip
// recording via a home-port geofence.
func (p Plan) CanUseAutoTripDetection() bool {
	return p == PlanPro
}

// Valid reports whether p is a known plan.
func (p Plan) Valid() bool {
	return p == PlanFree || p == PlanPro
}
