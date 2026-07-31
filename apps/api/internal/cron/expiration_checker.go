package cron

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strings"
	"time"

	"github.com/robfig/cron/v3"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// ExpirationChecker runs a daily cron job that checks for expiring documents
// and triggers notification workflows via Novu for their owners.
type ExpirationChecker struct {
	docs      port.DocumentRepository
	notifLogs port.NotificationLogRepository
	profiles  port.ProfileRepository
	notifier  port.NotificationProvider
	logger    *slog.Logger
	cron      *cron.Cron
}

// New creates a new ExpirationChecker.
func New(
	docs port.DocumentRepository,
	notifLogs port.NotificationLogRepository,
	profiles port.ProfileRepository,
	notifier port.NotificationProvider,
	logger *slog.Logger,
) *ExpirationChecker {
	return &ExpirationChecker{
		docs:      docs,
		notifLogs: notifLogs,
		profiles:  profiles,
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

	// Free users only get reminders for their single nearest-expiry document;
	// Pro users get all. allowed holds the doc IDs eligible to notify this run.
	allowed := ec.allowedDocs(ctx, docs)

	var sent, skipped, muted int
	for _, doc := range docs {
		if !allowed[doc.ID] {
			skipped++
			continue
		}

		daysUntilExpiry := int(time.Until(doc.ExpiryDate).Hours() / 24)

		// Alert days that have been crossed and not yet notified. A document 5
		// days out has crossed BOTH the 30- and 7-day marks, but the message
		// only ever says "expires in 5 days": notifying once per crossed mark
		// sent the very same text twice (and, since #80, filed it twice in the
		// in-app feed). Notify once, then log every crossed mark so the
		// remaining ones cannot fire the same reminder again tomorrow.
		var pending []int
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
			pending = append(pending, alertDay)
		}
		if len(pending) == 0 {
			continue
		}

		title, body := buildMessage(doc.Type, doc.CustomName, daysUntilExpiry, doc.ExpiryDate)

		payload := map[string]any{
			"title": title,
			"body":  body,
			// The deep-link pair the app routes on, both for the push tap and
			// for the row in the notification feed. Without these the reminder
			// opens nothing.
			"type":              "document",
			"id":                doc.ID,
			"document_id":       doc.ID,
			"document_type":     string(doc.Type),
			"days_until_expiry": daysUntilExpiry,
			"expiry_date":       doc.ExpiryDate.Format("2006-01-02"),
		}

		if err := ec.notifier.TriggerWorkflow(ctx, "reminders", doc.UserID, payload); err != nil {
			// A muted category is not a failure and must stay pending: the user
			// unmuting later is exactly when this reminder should be delivered.
			if errors.Is(err, domain.ErrNotificationMuted) {
				muted++
				continue
			}
			ec.logger.Error("failed to trigger notification workflow",
				slog.String("doc_id", doc.ID),
				slog.String("user_id", doc.UserID),
				slog.String("error", err.Error()),
			)
			continue
		}

		for _, alertDay := range pending {
			if err := ec.notifLogs.Create(ctx, doc.UserID, doc.ID, alertDay); err != nil {
				ec.logger.Error("failed to create notification log",
					slog.String("doc_id", doc.ID),
					slog.String("error", err.Error()),
				)
			}
		}

		sent++
		ec.logger.Info("triggered expiry notification",
			slog.String("doc_id", doc.ID),
			slog.String("user_id", doc.UserID),
			slog.Any("alert_days", pending),
		)
	}

	ec.logger.Info("expiration check completed",
		slog.Int("documents_checked", len(docs)),
		slog.Int("notifications_sent", sent),
		slog.Int("notifications_skipped", skipped),
		// Muted reminders stay pending on purpose, so they are counted apart
		// from the ones that were actually handled.
		slog.Int("notifications_muted", muted),
	)
}

// allowedDocs returns the set of document IDs eligible for a reminder this run,
// applying each owner's plan reminder quota. Free users are capped at their
// nearest-expiry document(s); Pro (unlimited) users get every document. If the
// profiles repo is unavailable it fails open (all allowed).
func (ec *ExpirationChecker) allowedDocs(ctx context.Context, docs []domain.Document) map[string]bool {
	allowed := make(map[string]bool, len(docs))
	if ec.profiles == nil {
		for _, doc := range docs {
			allowed[doc.ID] = true
		}
		return allowed
	}

	// Group document indices by owner.
	byUser := make(map[string][]int)
	for i, doc := range docs {
		byUser[doc.UserID] = append(byUser[doc.UserID], i)
	}

	planCache := make(map[string]domain.Plan)
	for userID, idxs := range byUser {
		plan, ok := planCache[userID]
		if !ok {
			profile, err := ec.profiles.GetOrCreate(ctx, userID)
			if err != nil {
				// Fail open for this user rather than silently dropping alerts.
				ec.logger.Warn("expiration checker: could not load profile; allowing all",
					slog.String("user_id", userID), slog.String("error", err.Error()))
				plan = domain.PlanPro
			} else {
				plan = profile.Plan
			}
			planCache[userID] = plan
		}

		limit := plan.ReminderDocLimit()
		if limit == domain.Unlimited || len(idxs) <= limit {
			for _, i := range idxs {
				allowed[docs[i].ID] = true
			}
			continue
		}

		// Keep the `limit` documents closest to expiry (deterministic tie-break
		// on document ID).
		sortByExpiry(docs, idxs)
		for _, i := range idxs[:limit] {
			allowed[docs[i].ID] = true
		}
	}
	return allowed
}

// sortByExpiry orders the given document indices by ascending expiry date, then
// by ID for a stable tie-break.
func sortByExpiry(docs []domain.Document, idxs []int) {
	slices.SortFunc(idxs, func(a, b int) int {
		if c := docs[a].ExpiryDate.Compare(docs[b].ExpiryDate); c != 0 {
			return c
		}
		return strings.Compare(docs[a].ID, docs[b].ID)
	})
}

// documentLabels are the Spanish names of the canonical document types, so a
// reminder reads "El seguro a terceros caduca..." instead of leaking the
// database slug ("insurance_rc") to the user.
var documentLabels = map[domain.DocumentType]string{
	domain.DocumentTypeITB:               "certificado ITB",
	domain.DocumentTypeInsuranceRC:       "seguro de responsabilidad civil",
	domain.DocumentTypeInsuranceFull:     "seguro a todo riesgo",
	domain.DocumentTypeLifeRaft:          "balsa salvavidas",
	domain.DocumentTypeExtinguisher:      "extintor",
	domain.DocumentTypeFlares:            "bengalas",
	domain.DocumentTypeFirstAid:          "botiquin",
	domain.DocumentTypeMedicalCert:       "certificado medico",
	domain.DocumentTypeRadioCert:         "titulo de radio",
	domain.DocumentTypeNavigationLicense: "titulacion de navegacion",
	domain.DocumentTypeCustom:            "documento",
}

// documentName is the user-facing name of a document: its custom name when it
// has one, otherwise the Spanish label of its type.
func documentName(docType domain.DocumentType, customName *string) string {
	if customName != nil && *customName != "" {
		return *customName
	}
	if label, ok := documentLabels[docType]; ok {
		return label
	}
	return "documento"
}

// buildMessage writes the reminder text. Spanish, like every other
// notification the API sends (the app is Spanish-first and the server has no
// per-user locale to switch on).
func buildMessage(
	docType domain.DocumentType, customName *string, daysUntil int, expiryDate time.Time,
) (string, string) {
	name := documentName(docType, customName)

	if daysUntil <= 0 {
		return "Documento caducado",
			fmt.Sprintf("Tu %s ha caducado.", name)
	}
	if daysUntil == 1 {
		return "Documento a punto de caducar",
			fmt.Sprintf("Tu %s caduca manana (%s).", name, expiryDate.Format("02/01/2006"))
	}

	return "Documento a punto de caducar",
		fmt.Sprintf("Tu %s caduca en %d dias (el %s).",
			name, daysUntil, expiryDate.Format("02/01/2006"))
}
