package domain

import "time"

// MaintenanceLog is one entry in a task's history: the record of a job being
// carried out. TaskID is the task it belongs to; it stays nullable only for
// rows written before every log was adopted by a task (migration 00042).
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
	PhotoURLs   []string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// MaintenanceTaskKind separates a job that comes back on a schedule from one
// that simply happens now and then. It is the only thing the owner decides when
// creating a task, and it is what makes a due date meaningful.
type MaintenanceTaskKind string

// MaintenanceTaskKind values.
const (
	// MaintenanceKindPeriodic repeats: it carries an interval, a next due date
	// and it expires like a document.
	MaintenanceKindPeriodic MaintenanceTaskKind = "periodic"
	// MaintenanceKindOneOff is a job with a history and no calendar (a repair).
	MaintenanceKindOneOff MaintenanceTaskKind = "one_off"
)

// MaintenanceTask is a maintenance job on a boat (oil, anodes, antifouling, a
// pump that broke...). A periodic task owns its NextDueDate — stored, not
// re-derived from its history — so it expires and warns exactly like a
// document, and it has a date to warn about from the moment it is created.
// NextDueHours is the same idea for engines serviced by running hours; it is
// secondary and only ever brings the due state forward.
type MaintenanceTask struct {
	ID             string
	BoatID         string
	UserID         string
	Name           string
	Kind           MaintenanceTaskKind
	IntervalMonths *int
	IntervalHours  *float64
	NextDueDate    *time.Time
	NextDueHours   *float64
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// Periodic reports whether the task repeats on a schedule.
func (t MaintenanceTask) Periodic() bool {
	return t.Kind == MaintenanceKindPeriodic
}

// MaintenanceCompletion is the record of carrying a task out: the history entry
// to write, whose date also decides where the next due date lands.
type MaintenanceCompletion struct {
	PerformedAt time.Time
	EngineHours *float64
	Cost        *float64
	Provider    *string
	Notes       *string
	InvoiceURL  *string
	PhotoURLs   []string
}

// MaintenanceTaskView is a task plus its derived state, so the client renders
// the plan without recomputing "when does this expire".
type MaintenanceTaskView struct {
	Task            MaintenanceTask
	Status          MaintenanceTaskStatus
	LastPerformedAt *time.Time
	LastEngineHours *float64
	DueDays         int      // days until the due date (meaningful when Task.NextDueDate != nil)
	HoursUntilDue   *float64 // engine hours until the hours limit (nil = n/a)
	TimesDone       int      // how many times it has been carried out
}

// MaintenanceTaskStatus is the derived state of a maintenance task. The values
// mirror documents.status on purpose: an owner should not have to learn a second
// vocabulary for "this expires soon".
type MaintenanceTaskStatus string

// MaintenanceTaskStatus values, sharing the documents thresholds (90/30 days).
const (
	MaintenanceOK       MaintenanceTaskStatus = "ok"       // due date comfortably ahead
	MaintenanceWarning  MaintenanceTaskStatus = "warning"  // within 90 days
	MaintenanceCritical MaintenanceTaskStatus = "critical" // within 30 days
	MaintenanceExpired  MaintenanceTaskStatus = "expired"  // past due
	// MaintenanceUnscheduled is a one-off task: it has a history, never a date.
	MaintenanceUnscheduled MaintenanceTaskStatus = "unscheduled"
)

// MaintenanceDueNotice is a task close to (or past) its due date, ready to
// notify: its evaluated state plus the owner and boat context the notification
// needs. DueKey pins the concrete occurrence so servicing the task opens a new
// dedup slot (see the maintenance_notification_logs migration).
type MaintenanceDueNotice struct {
	TaskID        string
	TaskName      string
	BoatID        string
	BoatName      string
	OwnerID       string
	Status        MaintenanceTaskStatus
	NextDueDate   *time.Time
	DueDays       int
	HoursUntilDue *float64
	DueKey        string
}

// MaintenanceTaskWithLatest is a task joined with its boat context, for
// cross-boat due evaluation (the notification cron). The due date lives on the
// task itself, so no history join is needed — only the boat's engine hours,
// which the hours limit is measured against.
type MaintenanceTaskWithLatest struct {
	Task        MaintenanceTask
	BoatName    string
	OwnerID     string
	EngineHours float64
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
	InvoiceURL *string
	// Liters is optional and meaningful for fuel expenses; it lets cost
	// intelligence derive a real €/L trend.
	Liters    *float64
	CreatedAt time.Time
	UpdatedAt time.Time
}

// Canonical (Spanish) expense categories: the quick picks the app offers. The
// column is free text — an owner can invent a category — but these are the ones
// the API has to recognise, e.g. for €/L and the fixed/variable cost split.
const (
	ExpenseCategoryFuel      = "combustible"
	ExpenseCategoryMooring   = "amarre"
	ExpenseCategoryInsurance = "seguro"
	ExpenseCategoryRepair    = "reparación"
	ExpenseCategoryCleaning  = "limpieza"
	ExpenseCategoryOther     = "otros"
)
