package cron

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/robfig/cron/v3"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// dueNoticeLister is the service surface the maintenance checker consumes
// (consumer-side interface; implemented by service.MaintenanceService).
type dueNoticeLister interface {
	DueNotices(ctx context.Context) ([]domain.MaintenanceDueNotice, error)
}

// MaintenanceChecker runs a daily cron job that notifies boat owners about
// maintenance tasks that are due soon or overdue. Scheduled maintenance
// reminders are a Pro capability: Free owners are skipped (they still see
// the due state in-app on the maintenance and readiness screens).
type MaintenanceChecker struct {
	notices   dueNoticeLister
	notifLogs port.MaintenanceNotificationLogRepository
	profiles  port.ProfileRepository
	notifier  port.NotificationProvider
	logger    *slog.Logger
	cron      *cron.Cron
}

// NewMaintenanceChecker creates a new MaintenanceChecker.
func NewMaintenanceChecker(
	notices dueNoticeLister,
	notifLogs port.MaintenanceNotificationLogRepository,
	profiles port.ProfileRepository,
	notifier port.NotificationProvider,
	logger *slog.Logger,
) *MaintenanceChecker {
	return &MaintenanceChecker{
		notices:   notices,
		notifLogs: notifLogs,
		profiles:  profiles,
		notifier:  notifier,
		logger:    logger,
	}
}

// Start begins the cron schedule. Runs daily at 08:15 UTC (offset from the
// document expiration checker at 08:00).
func (mc *MaintenanceChecker) Start() {
	mc.cron = cron.New(cron.WithLocation(time.UTC))

	_, err := mc.cron.AddFunc("15 8 * * *", func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		mc.check(ctx)
	})
	if err != nil {
		mc.logger.Error("failed to schedule maintenance checker", slog.String("error", err.Error()))
		return
	}

	mc.cron.Start()
	mc.logger.Info("maintenance checker cron started", slog.String("schedule", "daily 08:15 UTC"))
}

// Stop gracefully stops the cron scheduler.
func (mc *MaintenanceChecker) Stop() {
	if mc.cron != nil {
		mc.cron.Stop()
		mc.logger.Info("maintenance checker cron stopped")
	}
}

// check evaluates due tasks and notifies Pro owners, avoiding duplicates.
func (mc *MaintenanceChecker) check(ctx context.Context) {
	notices, err := mc.notices.DueNotices(ctx)
	if err != nil {
		mc.logger.Error("failed to list due maintenance", slog.String("error", err.Error()))
		return
	}

	mc.logger.Info("checking maintenance due", slog.Int("count", len(notices)))

	// Cache plan lookups per owner within the run.
	pro := map[string]bool{}

	var sent, skipped int
	for _, n := range notices {
		allowed, ok := pro[n.OwnerID]
		if !ok {
			allowed = mc.ownerIsPro(ctx, n.OwnerID)
			pro[n.OwnerID] = allowed
		}
		if !allowed {
			skipped++
			continue
		}

		exists, err := mc.notifLogs.Exists(ctx, n.OwnerID, n.TaskID, string(n.Status), n.DueKey)
		if err != nil {
			mc.logger.Error("failed to check maintenance notification log",
				slog.String("task_id", n.TaskID),
				slog.String("error", err.Error()),
			)
			continue
		}
		if exists {
			skipped++
			continue
		}

		title, body := buildMaintenanceMessage(n)
		payload := map[string]any{
			"title":     title,
			"body":      body,
			"boat_id":   n.BoatID,
			"boat_name": n.BoatName,
			"task_id":   n.TaskID,
			"task_name": n.TaskName,
			"status":    string(n.Status),
		}
		if n.NextDueDate != nil {
			payload["due_date"] = n.NextDueDate.Format("2006-01-02")
		}

		if err := mc.notifier.TriggerWorkflow(ctx, "reminders", n.OwnerID, payload); err != nil {
			mc.logger.Error("failed to trigger maintenance workflow",
				slog.String("task_id", n.TaskID),
				slog.String("user_id", n.OwnerID),
				slog.String("error", err.Error()),
			)
			continue
		}

		if err := mc.notifLogs.Create(ctx, n.OwnerID, n.TaskID, string(n.Status), n.DueKey); err != nil {
			mc.logger.Error("failed to create maintenance notification log",
				slog.String("task_id", n.TaskID),
				slog.String("error", err.Error()),
			)
		}

		sent++
		mc.logger.Info("triggered maintenance notification",
			slog.String("task_id", n.TaskID),
			slog.String("user_id", n.OwnerID),
			slog.String("status", string(n.Status)),
		)
	}

	mc.logger.Info("maintenance check completed",
		slog.Int("tasks_due", len(notices)),
		slog.Int("notifications_sent", sent),
		slog.Int("notifications_skipped", skipped),
	)
}

// ownerIsPro reports whether scheduled-maintenance reminders are unlocked for
// the owner. Fails closed: an unreadable profile skips the notification (it
// will retry on the next run).
func (mc *MaintenanceChecker) ownerIsPro(ctx context.Context, userID string) bool {
	profile, err := mc.profiles.GetOrCreate(ctx, userID)
	if err != nil {
		mc.logger.Error("failed to load profile for maintenance notify",
			slog.String("user_id", userID),
			slog.String("error", err.Error()),
		)
		return false
	}
	return profile.Plan.CanUseMaintenanceSchedules()
}

// buildMaintenanceMessage renders the notification title/body for a due task.
func buildMaintenanceMessage(n domain.MaintenanceDueNotice) (string, string) {
	if n.Status == domain.MaintenanceOverdue {
		title := fmt.Sprintf("%s overdue", n.TaskName)
		body := fmt.Sprintf("%s on %s is overdue.", n.TaskName, n.BoatName)
		if n.NextDueDate != nil && n.DueDays < 0 {
			body = fmt.Sprintf("%s on %s was due %d days ago.", n.TaskName, n.BoatName, -n.DueDays)
		} else if n.HoursUntilDue != nil && *n.HoursUntilDue <= 0 {
			body = fmt.Sprintf("%s on %s is %.0f engine hours past due.", n.TaskName, n.BoatName, -*n.HoursUntilDue)
		}
		return title, body
	}
	title := fmt.Sprintf("%s due soon", n.TaskName)
	body := fmt.Sprintf("%s on %s is due soon.", n.TaskName, n.BoatName)
	switch {
	case n.NextDueDate != nil && n.HoursUntilDue != nil:
		body = fmt.Sprintf("%s on %s is due in %d days or %.0f engine hours.",
			n.TaskName, n.BoatName, n.DueDays, *n.HoursUntilDue)
	case n.NextDueDate != nil:
		body = fmt.Sprintf("%s on %s is due in %d days.", n.TaskName, n.BoatName, n.DueDays)
	case n.HoursUntilDue != nil:
		body = fmt.Sprintf("%s on %s is due in %.0f engine hours.", n.TaskName, n.BoatName, *n.HoursUntilDue)
	}
	return title, body
}
