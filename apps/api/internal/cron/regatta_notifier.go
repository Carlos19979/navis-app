package cron

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/robfig/cron/v3"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
)

// RegattaNotifier runs two scheduled jobs:
//   - a daily reminder of group regattas happening soon, and
//   - a frequent check that alerts interested users when a regatta event has
//     just started (so they can follow it live).
type RegattaNotifier struct {
	trips     port.TripRepository
	members   port.GroupMemberRepository
	events    port.EventRepository
	interests port.EventInterestRepository
	sent      port.SentNotificationRepository
	notifier  *service.Notifier
	logger    *slog.Logger
	cron      *cron.Cron
}

// NewRegattaNotifier creates a new RegattaNotifier.
func NewRegattaNotifier(
	trips port.TripRepository,
	members port.GroupMemberRepository,
	events port.EventRepository,
	interests port.EventInterestRepository,
	sent port.SentNotificationRepository,
	notifier *service.Notifier,
	logger *slog.Logger,
) *RegattaNotifier {
	return &RegattaNotifier{
		trips:     trips,
		members:   members,
		events:    events,
		interests: interests,
		sent:      sent,
		notifier:  notifier,
		logger:    logger,
	}
}

// Start begins both schedules.
func (n *RegattaNotifier) Start() {
	n.cron = cron.New(cron.WithLocation(time.UTC))

	if _, err := n.cron.AddFunc("0 9 * * *", func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		n.remindUpcoming(ctx)
	}); err != nil {
		n.logger.Error("failed to schedule regatta reminder", slog.String("error", err.Error()))
	}

	if _, err := n.cron.AddFunc("*/15 * * * *", func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		n.alertLive(ctx)
	}); err != nil {
		n.logger.Error("failed to schedule live-event alert", slog.String("error", err.Error()))
	}

	if _, err := n.cron.AddFunc("*/15 * * * *", func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		n.alertOverdue(ctx)
	}); err != nil {
		n.logger.Error("failed to schedule overdue float-plan alert", slog.String("error", err.Error()))
	}

	n.cron.Start()
	n.logger.Info("regatta notifier cron started",
		slog.String("reminder", "daily 09:00 UTC"),
		slog.String("live", "every 15m"),
		slog.String("overdue", "every 15m"))
}

// Stop gracefully stops the cron scheduler.
func (n *RegattaNotifier) Stop() {
	if n.cron != nil {
		n.cron.Stop()
		n.logger.Info("regatta notifier cron stopped")
	}
}

// remindUpcoming notifies group members about regattas scheduled in the next 36h.
func (n *RegattaNotifier) remindUpcoming(ctx context.Context) {
	from := time.Now().UTC()
	to := from.Add(36 * time.Hour)
	trips, err := n.trips.ListUpcomingRegattas(ctx, from, to)
	if err != nil {
		n.logger.Error("regatta reminder query failed", slog.String("error", err.Error()))
		return
	}
	for i := range trips {
		t := &trips[i]
		if t.GroupID == nil {
			continue
		}
		members, err := n.members.ListMembers(ctx, *t.GroupID)
		if err != nil {
			continue
		}
		title := "La regata"
		if t.Title != nil && *t.Title != "" {
			title = *t.Title
		}
		body := fmt.Sprintf("%s empieza pronto", title)
		for j := range members {
			uid := members[j].UserID
			if exists, _ := n.sent.Exists(ctx, uid, service.WorkflowRegattaReminder, t.ID, ""); exists {
				continue
			}
			n.notifier.Send(ctx, uid, service.WorkflowRegattaReminder,
				"Regata próxima", body, "regatta", t.ID)
			_ = n.sent.Record(ctx, uid, service.WorkflowRegattaReminder, t.ID, "")
		}
	}
}

// alertLive notifies interested users when a regatta event has just started.
func (n *RegattaNotifier) alertLive(ctx context.Context) {
	to := time.Now().UTC()
	from := to.Add(-1 * time.Hour)
	events, err := n.events.ListStartingBetween(ctx, from, to)
	if err != nil {
		n.logger.Error("live-event query failed", slog.String("error", err.Error()))
		return
	}
	for i := range events {
		e := &events[i]
		users, err := n.interests.ListInterestedUsers(ctx, e.ID)
		if err != nil {
			continue
		}
		for _, uid := range users {
			if exists, _ := n.sent.Exists(ctx, uid, service.WorkflowEventLive, e.ID, ""); exists {
				continue
			}
			n.notifier.Send(ctx, uid, service.WorkflowEventLive,
				e.Name, "La regata empieza — síguela en directo", "event", e.ID)
			_ = n.sent.Record(ctx, uid, service.WorkflowEventLive, e.ID, "")
		}
	}
}

// alertOverdue notifies skippers whose recording trip has passed its ETA by a
// grace margin (a "have you arrived safely?" safety nudge).
func (n *RegattaNotifier) alertOverdue(ctx context.Context) {
	const grace = 30 * time.Minute
	cutoff := time.Now().UTC().Add(-grace)
	trips, err := n.trips.ListOverdueFloatPlans(ctx, cutoff)
	if err != nil {
		n.logger.Error("overdue float-plan query failed", slog.String("error", err.Error()))
		return
	}
	for i := range trips {
		t := &trips[i]
		if exists, _ := n.sent.Exists(ctx, t.UserID, service.WorkflowFloatPlanOverdue, t.ID, ""); exists {
			continue
		}
		dest := "tu destino"
		if t.Destination != nil && *t.Destination != "" {
			dest = *t.Destination
		}
		n.notifier.Send(ctx, t.UserID, service.WorkflowFloatPlanOverdue,
			"¿Has llegado bien?",
			fmt.Sprintf("Tu viaje a %s debía haber llegado. Cierra el viaje si ya estás a salvo.", dest),
			"trip", t.ID)
		_ = n.sent.Record(ctx, t.UserID, service.WorkflowFloatPlanOverdue, t.ID, "")
	}
}
