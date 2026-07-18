package domain

import "time"

// Plan is a user's subscription tier.
type Plan string

// Plan values. Navis has two paid tiers: Plus (individual owner) and Pro
// (shared boat / data). "fleet"/B2B is future work.
const (
	PlanFree Plan = "free"
	PlanPlus Plan = "plus"
	PlanPro  Plan = "pro"
)

// rank orders tiers so gating can express "at least Plus". Unknown plans rank
// as free (0).
func (p Plan) rank() int {
	switch p {
	case PlanPro:
		return 2
	case PlanPlus:
		return 1
	case PlanFree:
		return 0
	default:
		return 0
	}
}

// atLeast reports whether p is at or above tier o.
func (p Plan) atLeast(o Plan) bool { return p.rank() >= o.rank() }

// IsPaid reports whether the plan is any paid tier.
func (p Plan) IsPaid() bool { return p != PlanFree }

// Unlimited is the sentinel for entitlements that have no cap on the Pro plan.
const Unlimited = -1

// Profile holds per-user account data such as the subscription plan.
type Profile struct {
	UserID    string
	Plan      Plan
	CreatedAt time.Time
	UpdatedAt time.Time
}

// IsPro reports whether the plan is the top (Pro) tier. Used only for the
// display mirror in MeResponse; feature gating uses the specific CanUse*
// methods below.
func (p Plan) IsPro() bool {
	return p == PlanPro
}

// MaxBoats returns how many boats the plan allows (Free 1 / Plus 2 / Pro 5).
func (p Plan) MaxBoats() int {
	switch p {
	case PlanPro:
		return 5
	case PlanPlus:
		return 2
	case PlanFree:
		return 1
	default:
		return 1
	}
}

// CanCreateGroups reports whether the plan may create groups/clubs and events
// (Pro only).
func (p Plan) CanCreateGroups() bool {
	return p == PlanPro
}

// ReminderDocLimit is how many documents get expiry reminders. Free users get a
// single reminder (a taste of the hook); Plus and Pro are Unlimited.
func (p Plan) ReminderDocLimit() int {
	if p.atLeast(PlanPlus) {
		return Unlimited
	}
	return 1
}

// CanUseMaintenanceSchedules reports whether the plan unlocks scheduled
// maintenance reminders (Plus and up).
func (p Plan) CanUseMaintenanceSchedules() bool {
	return p.atLeast(PlanPlus)
}

// AttachmentLimit is how many attachments a single document may hold. Free is
// capped; Plus and Pro are Unlimited.
func (p Plan) AttachmentLimit() int {
	if p.atLeast(PlanPlus) {
		return Unlimited
	}
	return 1
}

// GalleryLimit is the total number of photos a boat may hold: the single
// cover (photo_url) plus gallery extras (photo_urls). Free keeps just the
// cover; Plus and Pro get a small gallery.
func (p Plan) GalleryLimit() int {
	if p.atLeast(PlanPlus) {
		return 10
	}
	return 1
}

// CanUseFullReadiness reports whether the plan unlocks the full boat-readiness
// breakdown (documents + safety gear + maintenance/engine hours). Free users see
// only the documents block; Plus and up see the complete score.
func (p Plan) CanUseFullReadiness() bool {
	return p.atLeast(PlanPlus)
}

// CanUseAnchorAlarm reports whether the plan unlocks the anchor watch (drop an
// anchor position + swing radius and get a loud drift alarm). Plus and up.
func (p Plan) CanUseAnchorAlarm() bool {
	return p.atLeast(PlanPlus)
}

// CanUseCostAnalytics reports whether the plan unlocks advanced cost intelligence
// (cost per NM, cost per trip, fuel efficiency, €/L, seasonal spend). Pro only.
func (p Plan) CanUseCostAnalytics() bool {
	return p == PlanPro
}

// CanExportPassport reports whether the plan may export the boat passport dossier
// (PDF with documents, maintenance history, trips and expenses). Pro only.
func (p Plan) CanExportPassport() bool {
	return p == PlanPro
}

// CanUseSharedCoordination reports whether the plan unlocks shared-boat
// coordination (bookings calendar and expense splitting among co-owners).
// Pro only.
func (p Plan) CanUseSharedCoordination() bool {
	return p == PlanPro
}

// CanUseAnomalyAlerts reports whether the plan unlocks anomaly alerts (e.g. a
// trip whose fuel-per-mile deviates sharply from the boat's history). Pro only.
func (p Plan) CanUseAnomalyAlerts() bool {
	return p == PlanPro
}

// Valid reports whether p is a known plan.
func (p Plan) Valid() bool {
	return p == PlanFree || p == PlanPlus || p == PlanPro
}
