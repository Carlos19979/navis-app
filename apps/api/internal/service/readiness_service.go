package service

import (
	"context"
	"fmt"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// Expiry thresholds, aligned with the documents.status DB trigger and the
// mobile NavisDateUtils single source of truth.
const (
	readinessCriticalDays = 30
	readinessWarningDays  = 90
	// The engine-hours limit of a maintenance task, in the same three bands as
	// the dates above but measured in running hours.
	maintenanceCriticalHours = 10
	maintenanceWarningHours  = 30
)

// ReadinessService synthesizes a boat's "ready to sail" score from documents,
// safety gear and maintenance.
type ReadinessService struct {
	docs     port.DocumentRepository
	maint    port.MaintenanceRepository
	tasks    port.MaintenanceTaskRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
	now      func() time.Time
}

// NewReadinessService creates a new ReadinessService.
func NewReadinessService(
	docs port.DocumentRepository,
	maint port.MaintenanceRepository,
	tasks port.MaintenanceTaskRepository,
	boats port.BoatRepository,
	profiles port.ProfileRepository,
) *ReadinessService {
	return &ReadinessService{
		docs:     docs,
		maint:    maint,
		tasks:    tasks,
		boats:    boats,
		profiles: profiles,
		now:      time.Now,
	}
}

// Get computes the readiness summary for a boat the user can access. Free users
// get a documents-only view; Pro adds safety-gear and maintenance analysis.
func (s *ReadinessService) Get(ctx context.Context, userID, boatID string) (*domain.Readiness, error) {
	boat, err := s.boats.GetByIDAccessible(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("readiness: %w", err)
	}

	// A generous single page: boats rarely carry more than a handful of docs.
	docs, _, err := s.docs.ListByBoat(ctx, boatID, "", 200)
	if err != nil {
		return nil, fmt.Errorf("readiness: %w", err)
	}

	full := true
	if s.profiles != nil {
		profile, err := s.profiles.GetOrCreate(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("readiness: %w", err)
		}
		full = profile.Plan.CanUseFullReadiness()
	}

	paperwork := &domain.ReadinessCategory{Key: domain.ReadinessCatDocuments}
	gear := &domain.ReadinessCategory{Key: domain.ReadinessCatSafetyGear}
	var attention []domain.ReadinessItem
	score := 100

	for _, doc := range docs {
		days := s.daysUntil(doc.ExpiryDate)
		st := statusFromDays(days)
		cat := paperwork
		catKey := domain.ReadinessCatDocuments
		if domain.SafetyGearTypes[doc.Type] {
			cat = gear
			catKey = domain.ReadinessCatSafetyGear
		}
		cat.Total++
		// Prefer the document's own name over the bare type in the UI.
		label := ""
		if doc.CustomName != nil {
			label = *doc.CustomName
		}
		switch st {
		case domain.ReadinessNotReady:
			cat.Expired++
			score -= 25
			attention = append(attention, domain.ReadinessItem{
				Category: catKey, Ref: string(doc.Type), Label: label,
				Status: domain.ReadinessNotReady, Days: days,
			})
		case domain.ReadinessAttention:
			// Attention bucket splits into critical (<=30d) vs warning (<=90d).
			if days <= readinessCriticalDays {
				cat.Critical++
				score -= 12
				attention = append(attention, domain.ReadinessItem{
					Category: catKey, Ref: string(doc.Type), Label: label,
					Status: domain.ReadinessAttention, Days: days,
				})
			} else {
				cat.Warning++
				score -= 4
			}
		case domain.ReadinessReady:
			cat.OK++
		}
	}
	paperwork.Status = categoryStatus(paperwork)
	gear.Status = categoryStatus(gear)

	categories := []domain.ReadinessCategory{*paperwork, *gear}

	if full {
		maintCat, maintItems, penalty := s.maintenanceCategory(ctx, boat)
		score -= penalty
		categories = append(categories, maintCat)
		attention = append(attention, maintItems...)
	}

	if score < 0 {
		score = 0
	}

	return &domain.Readiness{
		Score:      score,
		Status:     overallStatus(categories),
		Full:       full,
		Categories: categories,
		Attention:  attention,
	}, nil
}

// maxMaintenancePenalty caps the total score hit from maintenance so a long
// neglected plan (many due tasks) can't sink the whole readiness score.
const maxMaintenancePenalty = 40

// maintenanceCategory evaluates the boat's maintenance tasks. Each periodic task
// is scored on the same bands as a document — expired, critical (<=30d),
// warning (<=90d) — so 60 days from a service reads the same here as on an
// insurance policy. One-off tasks have no calendar and are not part of the
// signal. Returns the category, the attention items, and the score penalty.
//
// A boat with no plan is **ready with 0/0**, not flagged: defining a maintenance
// schedule is opt-in, and charging a brand-new boat 10 points for not having one
// meant every owner's first look at readiness said "needs attention · 90".
func (s *ReadinessService) maintenanceCategory(ctx context.Context, boat *domain.Boat) (domain.ReadinessCategory, []domain.ReadinessItem, int) {
	cat := domain.ReadinessCategory{Key: domain.ReadinessCatMaintenance}
	tasks, _ := s.tasks.ListByBoat(ctx, boat.ID)
	logs, _ := s.maint.ListByBoat(ctx, boat.ID)

	// No plan at all: nothing to judge, so nothing to deduct.
	if len(tasks) == 0 {
		cat.Status = domain.ReadinessReady
		return cat, nil, 0
	}

	now := s.now()
	var items []domain.ReadinessItem
	penalty := 0
	for _, t := range tasks {
		ev := evaluateTask(t, logsForTask(logs, t.ID), boat.EngineHours, now)
		switch ev.Status {
		case domain.MaintenanceUnscheduled:
			continue // one-off job: no due date, not part of the signal
		case domain.MaintenanceExpired:
			cat.Total++
			cat.Expired++
			penalty += 15
			items = append(items, maintenanceItem(t, ev, domain.ReadinessNotReady))
		case domain.MaintenanceCritical:
			cat.Total++
			cat.Critical++
			penalty += 8
			items = append(items, maintenanceItem(t, ev, domain.ReadinessAttention))
		case domain.MaintenanceWarning:
			// Same as a document three months out: it costs a little score but
			// it is not something to put on the attention list yet.
			cat.Total++
			cat.Warning++
			penalty += 4
		case domain.MaintenanceOK:
			cat.Total++
			cat.OK++
		}
	}

	// Only one-off tasks existed: nothing to flag, same as no plan.
	if cat.Total == 0 {
		cat.Status = domain.ReadinessReady
		return cat, nil, 0
	}

	if penalty > maxMaintenancePenalty {
		penalty = maxMaintenancePenalty
	}
	cat.Status = categoryStatus(&cat)
	return cat, items, penalty
}

// logsForTask returns the subset of logs linked to a given task id.
func logsForTask(logs []domain.MaintenanceLog, taskID string) []domain.MaintenanceLog {
	out := make([]domain.MaintenanceLog, 0)
	for i := range logs {
		if logs[i].TaskID != nil && *logs[i].TaskID == taskID {
			out = append(out, logs[i])
		}
	}
	return out
}

// maintenanceItem builds a readiness attention item for a flagged task. Label is
// the task name; Ref stays "engine_service" so the client keeps the icon.
func maintenanceItem(t domain.MaintenanceTask, ev taskEval, st domain.ReadinessStatus) domain.ReadinessItem {
	return domain.ReadinessItem{
		Category: domain.ReadinessCatMaintenance,
		Ref:      "engine_service",
		Label:    t.Name,
		Status:   st,
		Days:     ev.DueDays,
		Reason:   maintenanceReason(ev.Status),
		Hours:    ev.HoursUntilDue,
	}
}

// maintenanceReason maps a task status to the client-facing reason string. The
// values stay "overdue"/"due_soon" so existing clients keep their copy.
func maintenanceReason(st domain.MaintenanceTaskStatus) string {
	switch st {
	case domain.MaintenanceExpired:
		return "overdue"
	case domain.MaintenanceCritical:
		return "due_soon"
	case domain.MaintenanceOK, domain.MaintenanceWarning, domain.MaintenanceUnscheduled:
		return ""
	default:
		return ""
	}
}

// daysUntil returns whole days from today (date-only) until the target date.
func (s *ReadinessService) daysUntil(t time.Time) int {
	return daysBetween(s.now(), t)
}

func statusFromDays(days int) domain.ReadinessStatus {
	switch {
	case days < 0:
		return domain.ReadinessNotReady
	case days <= readinessWarningDays:
		return domain.ReadinessAttention
	default:
		return domain.ReadinessReady
	}
}

// categoryStatus derives a category's status from its buckets.
func categoryStatus(c *domain.ReadinessCategory) domain.ReadinessStatus {
	switch {
	case c.Expired > 0:
		return domain.ReadinessNotReady
	case c.Critical > 0:
		return domain.ReadinessAttention
	default:
		return domain.ReadinessReady
	}
}

// overallStatus is the worst category status: any expired doc => not_ready;
// any critical/attention => attention; otherwise ready (warnings still sail).
func overallStatus(cats []domain.ReadinessCategory) domain.ReadinessStatus {
	worst := domain.ReadinessReady
	for _, c := range cats {
		switch c.Status {
		case domain.ReadinessNotReady:
			return domain.ReadinessNotReady
		case domain.ReadinessAttention:
			worst = domain.ReadinessAttention
		case domain.ReadinessReady:
			// keep current worst
		}
	}
	return worst
}
