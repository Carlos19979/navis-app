package cron

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/robfig/cron/v3"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// ExpirationChecker runs a daily cron job that checks for expiring documents
// and sends push notifications to their owners.
type ExpirationChecker struct {
	docs      port.DocumentRepository
	notifLogs port.NotificationLogRepository
	notifier  port.PushNotifier
	logger    *slog.Logger
	cron      *cron.Cron
}

// New creates a new ExpirationChecker.
func New(
	docs port.DocumentRepository,
	notifLogs port.NotificationLogRepository,
	notifier port.PushNotifier,
	logger *slog.Logger,
) *ExpirationChecker {
	return &ExpirationChecker{
		docs:      docs,
		notifLogs: notifLogs,
		notifier:  notifier,
		logger:    logger,
	}
}

// Start begins the cron schedule. Runs daily at 08:00 UTC.
func (ec *ExpirationChecker) Start() {
	ec.cron = cron.New(cron.WithLocation(time.UTC))

	_, err := ec.cron.AddFunc("0 8 * * *", func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()
		ec.check(ctx)
	})
	if err != nil {
		ec.logger.Error("failed to schedule expiration checker", slog.String("error", err.Error()))
		return
	}

	ec.cron.Start()
	ec.logger.Info("expiration checker cron started", slog.String("schedule", "0 8 * * * (daily 8am UTC)"))
}

// Stop gracefully stops the cron scheduler.
func (ec *ExpirationChecker) Stop() {
	if ec.cron != nil {
		ec.cron.Stop()
		ec.logger.Info("expiration checker cron stopped")
	}
}

// check queries for expiring documents and sends notifications, avoiding duplicates.
func (ec *ExpirationChecker) check(ctx context.Context) {
	// Check documents expiring within 90 days to cover typical alert windows.
	docs, err := ec.docs.ListExpiring(ctx, 90)
	if err != nil {
		ec.logger.Error("failed to list expiring documents", slog.String("error", err.Error()))
		return
	}

	ec.logger.Info("checking document expirations", slog.Int("count", len(docs)))

	for _, doc := range docs {
		daysUntilExpiry := int(time.Until(doc.ExpiryDate).Hours() / 24)

		for _, alertDay := range doc.AlertDays {
			if daysUntilExpiry > alertDay {
				continue
			}

			// Check if we already sent this specific notification.
			exists, err := ec.notifLogs.Exists(ctx, doc.UserID, doc.ID, alertDay)
			if err != nil {
				ec.logger.Error("failed to check notification log",
					slog.String("doc_id", doc.ID),
					slog.String("error", err.Error()),
				)
				continue
			}
			if exists {
				continue
			}

			// Build notification message.
			docName := string(doc.Type)
			if doc.CustomName != nil {
				docName = *doc.CustomName
			}

			title := "Document Expiring Soon"
			body := fmt.Sprintf("Your document %q expires in %d days (on %s).",
				docName, daysUntilExpiry, doc.ExpiryDate.Format("2006-01-02"))

			if daysUntilExpiry <= 0 {
				title = "Document Expired"
				body = fmt.Sprintf("Your document %q has expired.", docName)
			}

			// Send notification.
			if err := ec.notifier.Send(ctx, doc.UserID, title, body); err != nil {
				ec.logger.Error("failed to send expiry notification",
					slog.String("doc_id", doc.ID),
					slog.String("error", err.Error()),
				)
				continue
			}

			// Log that we sent this notification to avoid duplicates.
			if err := ec.notifLogs.Create(ctx, doc.UserID, doc.ID, alertDay); err != nil {
				ec.logger.Error("failed to create notification log",
					slog.String("doc_id", doc.ID),
					slog.String("error", err.Error()),
				)
			}

			ec.logger.Info("sent expiry notification",
				slog.String("doc_id", doc.ID),
				slog.String("user_id", doc.UserID),
				slog.Int("alert_day", alertDay),
			)
		}
	}
}
