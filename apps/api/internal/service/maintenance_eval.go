package service

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// taskEval is the derived due-state of a maintenance task, shared by the
// maintenance task listing and the readiness maintenance category so both use
// one definition of "due".
type taskEval struct {
	Status          domain.MaintenanceTaskStatus
	LastPerformedAt *time.Time
	LastEngineHours *float64
	NextDueDate     *time.Time
	DueDays         int      // days until the date-based service (meaningful only when NextDueDate != nil)
	HoursUntilDue   *float64 // engine hours until the hours-based service (nil = not applicable)
}

// daysBetween returns whole days (date-only, UTC) from now until target,
// matching the CURRENT_DATE-based document trigger.
func daysBetween(now, target time.Time) int {
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	t := time.Date(target.Year(), target.Month(), target.Day(), 0, 0, 0, 0, time.UTC)
	return int(t.Sub(today).Hours() / 24)
}

// evaluateTask computes a task's due-state from its logs, the boat's current
// engine hours and the current time. Whichever limit — date or hours — is
// nearest to (or past) due drives the status.
func evaluateTask(t domain.MaintenanceTask, logs []domain.MaintenanceLog, engineHours float64, now time.Time) taskEval {
	ev := taskEval{Status: domain.MaintenanceOK}

	// Latest service for this task: most recent performed_at + its engine hours.
	var last time.Time
	for i := range logs {
		if logs[i].PerformedAt.After(last) {
			last = logs[i].PerformedAt
			ev.LastEngineHours = logs[i].EngineHours
		}
	}
	if !last.IsZero() {
		lp := last
		ev.LastPerformedAt = &lp
	}

	if t.IntervalMonths == nil && t.IntervalHours == nil {
		ev.Status = domain.MaintenanceNoPlan // history-only bucket
		return ev
	}
	if last.IsZero() {
		ev.Status = domain.MaintenancePending // scheduled but never done
		return ev
	}

	overdue, soon := false, false
	if t.IntervalMonths != nil {
		due := last.AddDate(0, *t.IntervalMonths, 0)
		ev.NextDueDate = &due
		ev.DueDays = daysBetween(now, due)
		if ev.DueDays < 0 {
			overdue = true
		} else if ev.DueDays <= maintenanceDueSoonDays {
			soon = true
		}
	}
	if t.IntervalHours != nil && ev.LastEngineHours != nil {
		h := (*ev.LastEngineHours + *t.IntervalHours) - engineHours
		ev.HoursUntilDue = &h
		if h <= 0 {
			overdue = true
		} else if h <= maintenanceDueSoonHours {
			soon = true
		}
	}

	switch {
	case overdue:
		ev.Status = domain.MaintenanceOverdue
	case soon:
		ev.Status = domain.MaintenanceDueSoon
	default:
		ev.Status = domain.MaintenanceOK
	}
	return ev
}
