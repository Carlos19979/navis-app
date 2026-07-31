package service

import (
	"context"
	"fmt"
	"log/slog"
	"slices"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// FeedRecorder decorates a NotificationProvider with the two things a delivery
// needs beyond the push itself: the user's per-category opt-out, and a stored
// copy of what was sent so the app's bell icon has a history.
//
// It sits at the provider boundary on purpose. Both notification paths go
// through it — the Notifier (every in-app event) and the crons, which hold the
// provider directly — so neither can bypass preferences or skip the feed.
type FeedRecorder struct {
	inner  port.NotificationProvider
	feed   port.NotificationFeedRepository
	prefs  port.NotificationPrefsRepository
	logger *slog.Logger

	// recordUndelivered files the notification in the feed even when the
	// provider call failed. Set it for callers that never retry, and leave it
	// off for callers that do (see NewFeedRecorder).
	recordUndelivered bool
}

var _ port.NotificationProvider = (*FeedRecorder)(nil)

// NewFeedRecorder wraps inner so deliveries are filtered by preferences and
// recorded in the feed.
//
// recordUndelivered decides what happens when the provider fails, and the two
// answers are both right for their caller:
//   - false for the crons: they record dedup state only on success and retry on
//     the next run, so recording a failed delivery would duplicate the entry.
//   - true for the in-app Notifier: it is fire-and-forget with no retry, so
//     dropping the row would lose the event entirely — which is exactly what
//     the feed exists to prevent.
func NewFeedRecorder(
	inner port.NotificationProvider,
	feed port.NotificationFeedRepository,
	prefs port.NotificationPrefsRepository,
	logger *slog.Logger,
	recordUndelivered bool,
) *FeedRecorder {
	return &FeedRecorder{
		inner:             inner,
		feed:              feed,
		prefs:             prefs,
		logger:            logger,
		recordUndelivered: recordUndelivered,
	}
}

// TriggerWorkflow delivers the notification and records it in the feed, unless
// the user muted its category — in which case nothing is sent, nothing is
// stored, and domain.ErrNotificationMuted says so.
//
// Muting reports an error rather than success on purpose: the crons record
// their dedup state only when a trigger succeeded, and treating a muted
// category as delivered would burn the reminder's only slot. The user would
// then unmute and never hear about the document that was about to expire.
//
// With no NOVU_API_KEY the provider is a no-op that returns nil, so the feed
// still fills in — that is what makes the bell work before push is configured.
func (r *FeedRecorder) TriggerWorkflow(
	ctx context.Context, workflowID, subscriberID string, payload map[string]any,
) error {
	category := domain.NotificationCategory(workflowID)
	if !category.Valid() {
		// Unknown workflow: deliver it, but there is no category to file it
		// under (nor to check preferences against).
		return r.inner.TriggerWorkflow(ctx, workflowID, subscriberID, payload)
	}

	if r.muted(ctx, subscriberID, category) {
		return domain.ErrNotificationMuted
	}

	deliveryErr := r.inner.TriggerWorkflow(ctx, workflowID, subscriberID, payload)
	if deliveryErr != nil && !r.recordUndelivered {
		return deliveryErr
	}

	n := &domain.Notification{
		UserID:   subscriberID,
		Category: category,
		Title:    payloadString(payload, "title"),
		Body:     payloadString(payload, "body"),
		LinkType: payloadString(payload, "type"),
		LinkID:   payloadString(payload, "id"),
	}
	if err := r.feed.Create(ctx, n); err != nil && r.logger != nil {
		// A feed write failure must not turn a delivered notification into a
		// failed one (crons would re-send it).
		r.logger.Warn("notification feed write failed",
			"category", workflowID, "user_id", subscriberID, "error", err)
	}
	return deliveryErr
}

// muted reports whether the user opted out of this category. A lookup failure
// is treated as "not muted": losing a notification is worse than sending one
// the user may have muted.
func (r *FeedRecorder) muted(ctx context.Context, userID string, category domain.NotificationCategory) bool {
	if r.prefs == nil {
		return false
	}
	muted, err := r.prefs.ListMuted(ctx, userID)
	if err != nil {
		if r.logger != nil {
			r.logger.Warn("notification preferences lookup failed",
				"user_id", userID, "error", err)
		}
		return false
	}
	return slices.Contains(muted, category)
}

// EnsureSubscriber delegates to the wrapped provider.
func (r *FeedRecorder) EnsureSubscriber(ctx context.Context, subscriberID string) error {
	return r.inner.EnsureSubscriber(ctx, subscriberID)
}

// SetPushToken delegates to the wrapped provider.
func (r *FeedRecorder) SetPushToken(ctx context.Context, subscriberID, token string) error {
	return r.inner.SetPushToken(ctx, subscriberID, token)
}

// RemovePushToken delegates to the wrapped provider.
func (r *FeedRecorder) RemovePushToken(ctx context.Context, subscriberID, token string) error {
	return r.inner.RemovePushToken(ctx, subscriberID, token)
}

// payloadString reads a string value from a notification payload, tolerating a
// missing key or a non-string value.
func payloadString(payload map[string]any, key string) string {
	if v, ok := payload[key].(string); ok {
		return v
	}
	return ""
}

// NotificationService serves the notification feed (the bell icon) and the
// per-category preferences.
type NotificationService struct {
	feed  port.NotificationFeedRepository
	prefs port.NotificationPrefsRepository
}

// NewNotificationService creates a new NotificationService.
func NewNotificationService(
	feed port.NotificationFeedRepository,
	prefs port.NotificationPrefsRepository,
) *NotificationService {
	return &NotificationService{feed: feed, prefs: prefs}
}

// List returns a page of the user's notifications, newest first.
func (s *NotificationService) List(
	ctx context.Context, userID, cursor string, limit int,
) ([]domain.Notification, string, error) {
	items, next, err := s.feed.List(ctx, userID, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("notification_service.List: %w", err)
	}
	return items, next, nil
}

// UnreadCount returns the badge value for the user.
func (s *NotificationService) UnreadCount(ctx context.Context, userID string) (int, error) {
	count, err := s.feed.UnreadCount(ctx, userID)
	if err != nil {
		return 0, fmt.Errorf("notification_service.UnreadCount: %w", err)
	}
	return count, nil
}

// MarkRead marks one notification as read.
func (s *NotificationService) MarkRead(ctx context.Context, userID, id string) error {
	if err := s.feed.MarkRead(ctx, userID, id); err != nil {
		return fmt.Errorf("notification_service.MarkRead: %w", err)
	}
	return nil
}

// MarkAllRead clears the user's unread notifications.
func (s *NotificationService) MarkAllRead(ctx context.Context, userID string) error {
	if err := s.feed.MarkAllRead(ctx, userID); err != nil {
		return fmt.Errorf("notification_service.MarkAllRead: %w", err)
	}
	return nil
}

// Preferences returns every category with whether the user wants it, in the
// canonical display order. Categories without a mute row are enabled.
func (s *NotificationService) Preferences(
	ctx context.Context, userID string,
) ([]domain.CategoryPreference, error) {
	muted, err := s.prefs.ListMuted(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("notification_service.Preferences: %w", err)
	}

	all := domain.AllNotificationCategories()
	prefs := make([]domain.CategoryPreference, 0, len(all))
	for _, category := range all {
		prefs = append(prefs, domain.CategoryPreference{
			Category: category,
			Enabled:  !slices.Contains(muted, category),
		})
	}
	return prefs, nil
}

// SetPreferences replaces the user's preferences with the given set. Any
// category not present stays enabled; unknown categories are rejected.
func (s *NotificationService) SetPreferences(
	ctx context.Context, userID string, prefs []domain.CategoryPreference,
) ([]domain.CategoryPreference, error) {
	muted := make([]domain.NotificationCategory, 0, len(prefs))
	seen := make(map[domain.NotificationCategory]struct{}, len(prefs))
	for _, p := range prefs {
		if !p.Category.Valid() {
			return nil, &domain.ValidationError{
				Field:   "category",
				Message: "unsupported notification category",
			}
		}
		// Two entries for one category have no defined answer — rejecting is
		// better than silently letting one of them win.
		if _, dup := seen[p.Category]; dup {
			return nil, &domain.ValidationError{
				Field:   "category",
				Message: "duplicate notification category",
			}
		}
		seen[p.Category] = struct{}{}
		if !p.Enabled {
			muted = append(muted, p.Category)
		}
	}

	if err := s.prefs.ReplaceMuted(ctx, userID, muted); err != nil {
		return nil, fmt.Errorf("notification_service.SetPreferences: %w", err)
	}
	return s.Preferences(ctx, userID)
}
