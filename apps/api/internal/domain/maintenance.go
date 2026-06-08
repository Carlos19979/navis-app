package domain

import "time"

// MaintenanceLog is a service record for a boat (oil change, antifouling…).
type MaintenanceLog struct {
	ID          string
	BoatID      string
	UserID      string
	Type        string
	PerformedAt time.Time
	EngineHours *float64
	Cost        *float64
	Provider    *string
	Notes       *string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Expense is a cost associated with a boat (fuel, mooring, insurance…).
type Expense struct {
	ID         string
	BoatID     string
	UserID     string
	Category   string
	Amount     float64
	IncurredOn time.Time
	Notes      *string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}
