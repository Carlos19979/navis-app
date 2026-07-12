package domain

import "time"

// MaintenanceLog is a service record for a boat (oil change, antifouling…).
// TaskID optionally links it to a recurring MaintenanceTask; nil = a one-off.
type MaintenanceLog struct {
	ID          string
	BoatID      string
	UserID      string
	TaskID      *string
	Type        string
	PerformedAt time.Time
	EngineHours *float64
	Cost        *float64
	Provider    *string
	Notes       *string
	InvoiceURL  *string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// MaintenanceTask is a recurring service plan for a boat component (oil, anodes,
// antifouling…). IntervalMonths and/or IntervalHours define how often it is due;
// with neither set it is a history-only bucket that never flags as due.
type MaintenanceTask struct {
	ID             string
	BoatID         string
	UserID         string
	Name           string
	IntervalMonths *int
	IntervalHours  *float64
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// MaintenanceTaskView is a task plus its derived due-state, for the client to
// render the plan without recomputing "due" logic.
type MaintenanceTaskView struct {
	Task            MaintenanceTask
	Status          MaintenanceTaskStatus
	LastPerformedAt *time.Time
	LastEngineHours *float64
	NextDueDate     *time.Time
	DueDays         int      // days until the date-based service (meaningful when NextDueDate != nil)
	HoursUntilDue   *float64 // engine hours until the hours-based service (nil = n/a)
}

// MaintenanceTaskStatus is the derived due-state of a maintenance task.
type MaintenanceTaskStatus string

// MaintenanceTaskStatus values.
const (
	MaintenanceOK      MaintenanceTaskStatus = "ok"       // done, next service not near
	MaintenanceDueSoon MaintenanceTaskStatus = "due_soon" // within the warning window
	MaintenanceOverdue MaintenanceTaskStatus = "overdue"  // past due (date or hours)
	MaintenancePending MaintenanceTaskStatus = "pending"  // has interval, never logged
	MaintenanceNoPlan  MaintenanceTaskStatus = "none"     // history-only (no interval)
)

// Expense is a cost associated with a boat (fuel, mooring, insurance…).
type Expense struct {
	ID         string
	BoatID     string
	UserID     string
	Category   string
	Amount     float64
	IncurredOn time.Time
	Notes      *string
	InvoiceURL *string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}
