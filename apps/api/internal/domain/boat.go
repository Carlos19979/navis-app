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
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// BoatMember is a user with shared access to a boat (crew / co-owner).
type BoatMember struct {
	BoatID string
	UserID string
	Name   string
	Role   string // viewer | editor
}
