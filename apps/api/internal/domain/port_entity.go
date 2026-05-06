package domain

import "time"

// PortType represents the category of a port.
type PortType string

// PortType values.
const (
	PortTypeMarina     PortType = "marina"
	PortTypeAnchorage  PortType = "anchorage"
	PortTypeFuel       PortType = "fuel"
	PortTypeCommercial PortType = "commercial"
	PortTypeFishing    PortType = "fishing"
	PortTypeOther      PortType = "other"
)

// Port represents a nautical port, marina, or anchorage.
type Port struct {
	ID         string
	Name       string
	Lat        float64
	Lon        float64
	Country    string
	PortType   PortType
	DepthM     *float64
	Facilities []string
	VHFChannel *string
	Website    *string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}
