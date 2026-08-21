package service

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// taskEval is the derived state of a maintenance task, shared by the task
// listing, the readiness maintenance category and the due-reminder cron so all
// three use one definition of "this expires".
type taskEval struct {
	Status          domain.MaintenanceTaskStatus
	LastPerformedAt *time.Time
	LastEngineHours *float64
	DueDays         int      // days until the due date (meaningful only when the task has one)
	HoursUntilDue   *float64 // engine hours until the hours limit (nil = not applicable)
	TimesDone       int
}

// daysBetween returns whole days (date-only, UTC) from now until target,
// matching the CURRENT_DATE-based document trigger.
func daysBetween(now, target time.Time) int {
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	t := time.Date(target.Year(), target.Month(), target.Day(), 0, 0, 0, 0, time.UTC)
	return int(t.Sub(today).Hours() / 24)
}

// statusFromDueDays maps days-until-due onto the document thresholds.
func statusFromDueDays(days int) domain.MaintenanceTaskStatus {
	switch {
	case days < 0:
		return domain.MaintenanceExpired
	case days <= readinessCriticalDays:
		return domain.MaintenanceCritical
	case days <= readinessWarningDays:
		return domain.MaintenanceWarning
	default:
		return domain.MaintenanceOK
	}
}

// statusFromDueHours maps engine-hours-until-due onto the same three bands.
func statusFromDueHours(hours float64) domain.MaintenanceTaskStatus {
	switch {
	case hours <= 0:
		return domain.MaintenanceExpired
	case hours <= maintenanceCriticalHours:
		return domain.MaintenanceCritical
	case hours <= maintenanceWarningHours:
		return domain.MaintenanceWarning
	default:
		return domain.MaintenanceOK
	}
}

// statusSeverity orders the statuses so two limits can be combined.
func statusSeverity(st domain.MaintenanceTaskStatus) int {
	switch st {
	case domain.MaintenanceExpired:
		return 4
	case domain.MaintenanceCritical:
		return 3
	case domain.MaintenanceWarning:
		return 2
	case domain.MaintenanceOK:
		return 1
	case domain.MaintenanceUnscheduled:
		return 0
	default:
		return 0
	}
}

// evaluateTask computes a task's state from its own due date/hours, the boat's
// current engine hours and the current time. The history is only read for "when
// was it last done" and "how many times" — never to work out when it is due,
// which is what the stored due date is for.
func evaluateTask(t domain.MaintenanceTask, logs []domain.MaintenanceLog, engineHours float64, now time.Time) taskEval {
	ev := taskEval{Status: domain.MaintenanceOK, TimesDone: len(logs)}
	for i := range logs {
		if ev.LastPerformedAt == nil || logs[i].PerformedAt.After(*ev.LastPerformedAt) {
			performed := logs[i].PerformedAt
			ev.LastPerformedAt = &performed
			ev.LastEngineHours = logs[i].EngineHours
		}
	}

	if !t.Periodic() {
		ev.Status = domain.MaintenanceUnscheduled
		return ev
	}

	// The date drives the state, like a document's expiry...
	if t.NextDueDate != nil {
		ev.DueDays = daysBetween(now, *t.NextDueDate)
		ev.Status = statusFromDueDays(ev.DueDays)
	}
	// ...and the engine-hours limit can only bring it forward, never push it
	// out: an engine that ran hard is due early, one that sat still is not
	// excused from its calendar service.
	if t.NextDueHours != nil {
		remaining := *t.NextDueHours - engineHours
		ev.HoursUntilDue = &remaining
		byHours := statusFromDueHours(remaining)
		if t.NextDueDate == nil || statusSeverity(byHours) > statusSeverity(ev.Status) {
			ev.Status = byHours
		}
	}
	return ev
}

// rollTask moves a periodic task's limits past the service just recorded: the
// next date counts from the day the work was done, and the next hours limit from
// the reading taken then (falling back to the boat's current one). This is the
// "reset" the owner triggers by marking a task done.
func rollTask(t *domain.MaintenanceTask, c domain.MaintenanceCompletion, engineHours float64) {
	if !t.Periodic() {
		return
	}
	if t.IntervalMonths != nil {
		due := c.PerformedAt.AddDate(0, *t.IntervalMonths, 0)
		t.NextDueDate = &due
	}
	if t.IntervalHours != nil {
		base := engineHours
		if c.EngineHours != nil {
			base = *c.EngineHours
		}
		next := base + *t.IntervalHours
		t.NextDueHours = &next
	}
}
