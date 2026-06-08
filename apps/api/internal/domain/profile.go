package domain

import "time"

// Plan is a user's subscription tier.
type Plan string

// Plan values.
const (
	PlanNormal  Plan = "normal"
	PlanArmador Plan = "armador"
	PlanGestor  Plan = "gestor"
)

// Profile holds per-user account data such as the subscription plan.
type Profile struct {
	UserID    string
	Plan      Plan
	CreatedAt time.Time
	UpdatedAt time.Time
}

// MaxBoats returns how many boats the plan allows.
func (p Plan) MaxBoats() int {
	switch p {
	case PlanGestor:
		return 15
	case PlanArmador:
		return 2
	default:
		return 1
	}
}

// CanCreateGroups reports whether the plan may create groups.
func (p Plan) CanCreateGroups() bool {
	return p == PlanArmador || p == PlanGestor
}

// Valid reports whether p is a known plan.
func (p Plan) Valid() bool {
	return p == PlanNormal || p == PlanArmador || p == PlanGestor
}
