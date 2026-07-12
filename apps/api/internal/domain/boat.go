package domain

import "time"

// BoatType represents the type of boat.
type BoatType string

// BoatType values.
const (
	BoatTypeSailboat  BoatType = "sailboat"
	BoatTypeMotorboat BoatType = "motorboat"
	BoatTypeCatamaran BoatType = "catamaran"
	BoatTypeRIB       BoatType = "rib"
	BoatTypeJetSki    BoatType = "jetski"
	BoatTypeOther     BoatType = "other"
)

// Boat represents a user's boat.
type Boat struct {
	ID           string
	UserID       string
	Name         string
	Registration string
	Type         BoatType
	LengthM      float64
	HomePort     string
	HomePortLat  *float64
	HomePortLon  *float64
	PhotoURL     *string
	EngineHours  float64
	// Maintenance schedule: service interval by months and/or engine hours
	// (either optional). Used by readiness to flag the next service.
	MaintenanceIntervalMonths *int
	MaintenanceIntervalHours  *float64
	CreatedAt                 time.Time
	UpdatedAt                 time.Time
}

// BoatPermissions is the granular permission set for a shared boat member.
// The boat owner implicitly has all permissions.
type BoatPermissions struct {
	CanRecordTrips       bool
	CanManageExpenses    bool
	CanManageMaintenance bool
	CanViewDocuments     bool
	CanManageDocuments   bool
}

// OwnerPermissions returns a permission set with everything enabled.
func OwnerPermissions() BoatPermissions {
	return BoatPermissions{
		CanRecordTrips:       true,
		CanManageExpenses:    true,
		CanManageMaintenance: true,
		CanViewDocuments:     true,
		CanManageDocuments:   true,
	}
}

// BoatMember is a user with shared access to a boat (crew / co-owner).
type BoatMember struct {
	BoatID      string
	UserID      string
	Name        string
	Permissions BoatPermissions
}
