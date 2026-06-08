package service

import (
	"context"
	"log/slog"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// Novu workflow identifiers. These must exist in the Novu dashboard for real
// delivery; with no NOVU_API_KEY the provider runs in dry-run (logs only).
const (
	WorkflowRegattaRSVP          = "regatta-rsvp"
	WorkflowRegattaScheduled     = "regatta-scheduled"
	WorkflowRegattaReminder      = "regatta-reminder"
	WorkflowGroupJoinRequest     = "group-join-request"
	WorkflowGroupRequestApproved = "group-request-approved"
	WorkflowEventLive            = "event-live"
	WorkflowFloatPlanOverdue     = "float-plan-overdue"
)

// Notifier centralises push-notification sending. It is best-effort: failures
// are logged and never propagate, so a notification problem can't break the
// user action that triggered it.
type Notifier struct {
	provider port.NotificationProvider
	users    port.UserRepository
	logger   *slog.Logger
}

// NewNotifier creates a Notifier.
func NewNotifier(provider port.NotificationProvider, users port.UserRepository, logger *slog.Logger) *Notifier {
	return &Notifier{provider: provider, users: users, logger: logger}
}

// UserName resolves a user's display name, falling back to a generic label.
func (n *Notifier) UserName(ctx context.Context, userID string) string {
	if n == nil || n.users == nil {
		return "Alguien"
	}
	name, err := n.users.DisplayName(ctx, userID)
	if err != nil || name == "" {
		return "Alguien"
	}
	return name
}

// Send triggers a Novu workflow for one recipient. The payload carries the
// display text plus a {type, id} deep-link target for the notification tap.
func (n *Notifier) Send(ctx context.Context, userID, workflow, title, body, linkType, linkID string) {
	if n == nil || n.provider == nil || userID == "" {
		return
	}
	payload := map[string]any{
		"title": title,
		"body":  body,
		"type":  linkType,
		"id":    linkID,
	}
	if err := n.provider.TriggerWorkflow(ctx, workflow, userID, payload); err != nil {
		if n.logger != nil {
			n.logger.Warn("notification failed",
				"workflow", workflow, "user_id", userID, "error", err)
		}
	}
}
