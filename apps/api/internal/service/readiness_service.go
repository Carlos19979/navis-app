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
	// The next service flags amber this close to its date/hours limit.
	maintenanceDueSoonDays  = 30
	maintenanceDueSoonHours = 10
)

// ReadinessService synthesizes a boat's "ready to sail" score from documents,
// safety gear and maintenance.
type ReadinessService struct {
	docs     port.DocumentRepository
	maint    port.MaintenanceRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
	now      func() time.Time
}

// NewReadinessService creates a new ReadinessService.
func NewReadinessService(
	docs port.DocumentRepository,
	maint port.MaintenanceRepository,
	boats port.BoatRepository,
	profiles port.ProfileRepository,
) *ReadinessService {
	return &ReadinessService{
		docs:     docs,
		maint:    maint,
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
		maintCat, maintItem, penalty := s.maintenanceCategory(ctx, boat)
		score -= penalty
		categories = append(categories, maintCat)
		if maintItem != nil {
			attention = append(attention, *maintItem)
		}
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

// maintenanceCategory evaluates the boat's service schedule (by date and/or
// engine hours). No schedule or no service logged => pending nudge. Otherwise
// the next service is due_soon (amber) or overdue (red), whichever limit — date
// or hours — comes first.
func (s *ReadinessService) maintenanceCategory(ctx context.Context, boat *domain.Boat) (domain.ReadinessCategory, *domain.ReadinessItem, int) {
	cat := domain.ReadinessCategory{Key: domain.ReadinessCatMaintenance, Total: 1}
	hasSchedule := boat.MaintenanceIntervalMonths != nil || boat.MaintenanceIntervalHours != nil
	logs, _ := s.maint.ListByBoat(ctx, boat.ID)

	// Latest service: most recent performed_at + the engine hours logged with it.
	var last time.Time
	var lastHours *float64
	for i := range logs {
		if logs[i].PerformedAt.After(last) {
			last = logs[i].PerformedAt
			lastHours = logs[i].EngineHours
		}
	}

	if !hasSchedule || last.IsZero() {
		cat.Status = domain.ReadinessAttention
		cat.Critical = 1
		return cat, &domain.ReadinessItem{
			Category: domain.ReadinessCatMaintenance, Ref: "engine_service",
			Reason: "no_plan", Status: domain.ReadinessAttention,
		}, 10
	}

	overdue, soon := false, false
	var dueDays int
	var dueHours *float64
	if boat.MaintenanceIntervalMonths != nil {
		dueDays = s.daysUntil(last.AddDate(0, *boat.MaintenanceIntervalMonths, 0))
		if dueDays < 0 {
			overdue = true
		} else if dueDays <= maintenanceDueSoonDays {
			soon = true
		}
	}
	if boat.MaintenanceIntervalHours != nil && lastHours != nil {
		h := (*lastHours + *boat.MaintenanceIntervalHours) - boat.EngineHours
		dueHours = &h
		if h <= 0 {
			overdue = true
		} else if h <= maintenanceDueSoonHours {
			soon = true
		}
	}

	switch {
	case overdue:
		cat.Status = domain.ReadinessNotReady
		cat.Expired = 1
		return cat, &domain.ReadinessItem{
			Category: domain.ReadinessCatMaintenance, Ref: "engine_service",
			Reason: "overdue", Status: domain.ReadinessNotReady, Days: dueDays, Hours: dueHours,
		}, 15
	case soon:
		cat.Status = domain.ReadinessAttention
		cat.Critical = 1
		return cat, &domain.ReadinessItem{
			Category: domain.ReadinessCatMaintenance, Ref: "engine_service",
			Reason: "due_soon", Status: domain.ReadinessAttention, Days: dueDays, Hours: dueHours,
		}, 8
	default:
		cat.Status = domain.ReadinessReady
		cat.OK = 1
		return cat, nil, 0
	}
}

// daysUntil returns whole days from today (date-only) until the target date,
// matching the CURRENT_DATE-based DB trigger.
func (s *ReadinessService) daysUntil(t time.Time) int {
	now := s.now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	target := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	return int(target.Sub(today).Hours() / 24)
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
