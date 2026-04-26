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
// and sends push notifications to their owners via their registered device tokens.
type ExpirationChecker struct {
	docs         port.DocumentRepository
	notifLogs    port.NotificationLogRepository
	deviceTokens port.DeviceTokenRepository
	notifier     port.PushNotifier
	logger       *slog.Logger
	cron         *cron.Cron
}

// New creates a new ExpirationChecker.
func New(
	docs port.DocumentRepository,
	notifLogs port.NotificationLogRepository,
	deviceTokens port.DeviceTokenRepository,
	notifier port.PushNotifier,
	logger *slog.Logger,
) *ExpirationChecker {
	return &ExpirationChecker{
		docs:         docs,
		notifLogs:    notifLogs,
		deviceTokens: deviceTokens,
		notifier:     notifier,
		logger:       logger,
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
	ec.logger.Info("expiration checker cron started", slog.String("schedule", "daily 08:00 UTC"))
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
	docs, err := ec.docs.ListExpiring(ctx, 90)
	if err != nil {
		ec.logger.Error("failed to list expiring documents", slog.String("error", err.Error()))
		return
	}

	ec.logger.Info("checking document expirations", slog.Int("count", len(docs)))

	var sent, skipped int
	for _, doc := range docs {
		daysUntilExpiry := int(time.Until(doc.ExpiryDate).Hours() / 24)

		for _, alertDay := range doc.AlertDays {
			if daysUntilExpiry > alertDay {
				continue
			}

			exists, err := ec.notifLogs.Exists(ctx, doc.UserID, doc.ID, alertDay)
			if err != nil {
				ec.logger.Error("failed to check notification log",
					slog.String("doc_id", doc.ID),
					slog.String("error", err.Error()),
				)
				continue
			}
			if exists {
				skipped++
				continue
			}

			title, body := buildMessage(string(doc.Type), doc.CustomName, daysUntilExpiry, doc.ExpiryDate)

			tokens, err := ec.deviceTokens.GetByUserID(ctx, doc.UserID)
			if err != nil {
				ec.logger.Error("failed to get device tokens",
					slog.String("user_id", doc.UserID),
					slog.String("error", err.Error()),
				)
				continue
			}

			if len(tokens) == 0 {
				ec.logger.Debug("no device tokens for user, skipping",
					slog.String("user_id", doc.UserID),
				)
				continue
			}

			for _, dt := range tokens {
				if err := ec.notifier.Send(ctx, dt.Token, title, body); err != nil {
					ec.logger.Error("failed to send push notification",
						slog.String("doc_id", doc.ID),
						slog.String("device_token", dt.Token),
						slog.String("error", err.Error()),
					)
				}
			}

			if err := ec.notifLogs.Create(ctx, doc.UserID, doc.ID, alertDay); err != nil {
				ec.logger.Error("failed to create notification log",
					slog.String("doc_id", doc.ID),
					slog.String("error", err.Error()),
				)
			}

			sent++
			ec.logger.Info("sent expiry notification",
				slog.String("doc_id", doc.ID),
				slog.String("user_id", doc.UserID),
				slog.Int("alert_day", alertDay),
				slog.Int("devices", len(tokens)),
			)
		}
	}

	ec.logger.Info("expiration check completed",
		slog.Int("documents_checked", len(docs)),
		slog.Int("notifications_sent", sent),
		slog.Int("notifications_skipped", skipped),
	)
}

func buildMessage(docType string, customName *string, daysUntil int, expiryDate time.Time) (string, string) {
	name := docType
	if customName != nil {
		name = *customName
	}

	if daysUntil <= 0 {
		return "Document Expired", fmt.Sprintf("Your document %q has expired.", name)
	}

	return "Document Expiring Soon", fmt.Sprintf("Your document %q expires in %d days (on %s).",
		name, daysUntil, expiryDate.Format("2006-01-02"))
}
