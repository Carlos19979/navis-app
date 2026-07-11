package service

import (
	"context"
	"log/slog"
	"time"

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
)

// Notifier centralises push-notification sending. It is best-effort: failures
// are logged and never propagate, so a notification problem can't break the
// user action that triggered it.
//
// Send enqueues onto a background worker (started with Start) so the Novu
// HTTP call never blocks a request. Without Start (tests, tools) Send
// delivers synchronously. TrySend always delivers synchronously — cron
// callers need the real outcome before recording dedup state.
type Notifier struct {
	provider port.NotificationProvider
	users    port.UserRepository
	logger   *slog.Logger

	queue chan notification
	done  chan struct{}
}

// notification is one queued delivery. It carries no request context: the
// worker outlives the request that enqueued it.
type notification struct {
	userID, workflow, title, body, linkType, linkID string
}

// queueSize bounds the notification backlog; when full, new notifications are
// dropped with a warning (best-effort by design).
const queueSize = 256

// deliveryTimeout bounds one provider call from the worker.
const deliveryTimeout = 15 * time.Second

// NewNotifier creates a Notifier.
func NewNotifier(provider port.NotificationProvider, users port.UserRepository, logger *slog.Logger) *Notifier {
	return &Notifier{provider: provider, users: users, logger: logger}
}

// Start launches the delivery worker. Call once from main; pair with Stop on
// shutdown.
func (n *Notifier) Start() {
	n.queue = make(chan notification, queueSize)
	n.done = make(chan struct{})
	go func() {
		defer close(n.done)
		for msg := range n.queue {
			ctx, cancel := context.WithTimeout(context.Background(), deliveryTimeout)
			_ = n.TrySend(ctx, msg.userID, msg.workflow, msg.title, msg.body, msg.linkType, msg.linkID)
			cancel()
		}
	}()
}

// Stop closes the queue and waits (bounded) for the worker to drain it.
func (n *Notifier) Stop() {
	if n.queue == nil {
		return
	}
	close(n.queue)
	select {
	case <-n.done:
	case <-time.After(2 * deliveryTimeout):
		n.logger.Warn("notifier: shutdown timeout, dropping queued notifications")
	}
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

// Send triggers a Novu workflow for one recipient without blocking the
// caller. The payload carries the display text plus a {type, id} deep-link
// target for the notification tap.
func (n *Notifier) Send(ctx context.Context, userID, workflow, title, body, linkType, linkID string) {
	if n == nil {
		return
	}
	if n.queue == nil {
		// Worker not started (tests / one-off tools): deliver inline.
		_ = n.TrySend(ctx, userID, workflow, title, body, linkType, linkID)
		return
	}
	select {
	case n.queue <- notification{userID, workflow, title, body, linkType, linkID}:
	default:
		n.logger.Warn("notifier: queue full, dropping notification",
			"workflow", workflow, "user_id", userID)
	}
}

// TrySend is Send reporting whether the provider accepted the trigger. Callers
// that record dedup state (crons) must only record on success, otherwise a
// transient provider failure permanently swallows the notification.
func (n *Notifier) TrySend(ctx context.Context, userID, workflow, title, body, linkType, linkID string) bool {
	if n == nil || n.provider == nil || userID == "" {
		return false
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
		return false
	}
	return true
}
