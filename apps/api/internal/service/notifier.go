package service

import (
	"context"
	"log/slog"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// Novu workflow identifiers. These must exist in the Novu dashboard for real
// delivery; with no NOVU_API_KEY the provider runs in dry-run (logs only).
// Workflows are grouped by domain into a handful of shared Novu workflows
// (the Novu plan caps total workflows at 20). Delivery is generic — each
// trigger carries its own title/body + deep-link in the payload — so one
// workflow per domain serves many event types without losing information.
const (
	WorkflowRegattaUpdates = "regatta-updates" // regatta lifecycle
	WorkflowGroupUpdates   = "group-updates"   // club/group membership
	WorkflowBoatActivity   = "boat-activity"   // shared-boat crew activity
	WorkflowReminders      = "reminders"       // cron reminders (docs, maintenance)
	WorkflowEventLive      = "event-live"      // nautical event goes live
)

// Per-event aliases → the grouped workflow they belong to. Keeping the
// event-specific names lets every call site stay expressive while all
// triggers resolve to one of the five workflows above.
const (
	WorkflowRegattaScheduled = WorkflowRegattaUpdates
	WorkflowRegattaRSVP      = WorkflowRegattaUpdates
	WorkflowRegattaReminder  = WorkflowRegattaUpdates
	WorkflowRegattaCancelled = WorkflowRegattaUpdates

	WorkflowGroupJoinRequest     = WorkflowGroupUpdates
	WorkflowGroupRequestApproved = WorkflowGroupUpdates
	WorkflowGroupRequestRejected = WorkflowGroupUpdates
	WorkflowGroupMemberRemoved   = WorkflowGroupUpdates
	WorkflowGroupMemberLeft      = WorkflowGroupUpdates
	WorkflowGroupJoined          = WorkflowGroupUpdates

	WorkflowExpenseSplit      = WorkflowBoatActivity
	WorkflowExpenseSettled    = WorkflowBoatActivity
	WorkflowBookingCreated    = WorkflowBoatActivity
	WorkflowBookingCancelled  = WorkflowBoatActivity
	WorkflowBoatMemberJoined  = WorkflowBoatActivity
	WorkflowBoatMemberRemoved = WorkflowBoatActivity
	WorkflowTripCompleted     = WorkflowBoatActivity
	WorkflowMaintenanceLogged = WorkflowBoatActivity
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

// SendMany fans a workflow out to several recipients, skipping the acting user
// (exclude) and any empty IDs. Best-effort, like Send.
func (n *Notifier) SendMany(ctx context.Context, userIDs []string, exclude, workflow, title, body, linkType, linkID string) {
	if n == nil {
		return
	}
	for _, uid := range userIDs {
		if uid == "" || uid == exclude {
			continue
		}
		n.Send(ctx, uid, workflow, title, body, linkType, linkID)
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
