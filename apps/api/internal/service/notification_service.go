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
}

var _ port.NotificationProvider = (*FeedRecorder)(nil)

// NewFeedRecorder wraps inner so deliveries are filtered by preferences and
// recorded in the feed.
func NewFeedRecorder(
	inner port.NotificationProvider,
	feed port.NotificationFeedRepository,
	prefs port.NotificationPrefsRepository,
	logger *slog.Logger,
) *FeedRecorder {
	return &FeedRecorder{inner: inner, feed: feed, prefs: prefs, logger: logger}
}

// TriggerWorkflow drops the notification when the user muted its category,
// otherwise delegates and — on success — records it in the feed.
//
// Delivery happens before recording so a provider failure leaves no row: the
// crons only persist their dedup state on success and will retry, which would
// otherwise pile up duplicates in the feed. With no NOVU_API_KEY the provider
// is a no-op that returns nil, so the feed still fills in (that is what makes
// the bell work before push is configured).
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
		return nil
	}

	if err := r.inner.TriggerWorkflow(ctx, workflowID, subscriberID, payload); err != nil {
		return err
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
		// The push already went out; a feed write failure must not turn a
		// delivered notification into a failed one (crons would re-send it).
		r.logger.Warn("notification feed write failed",
			"category", workflowID, "user_id", subscriberID, "error", err)
	}
	return nil
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
	for _, p := range prefs {
		if !p.Category.Valid() {
			return nil, &domain.ValidationError{
				Field:   "category",
				Message: "unsupported notification category",
			}
		}
		if !p.Enabled && !slices.Contains(muted, p.Category) {
			muted = append(muted, p.Category)
		}
	}

	if err := s.prefs.ReplaceMuted(ctx, userID, muted); err != nil {
		return nil, fmt.Errorf("notification_service.SetPreferences: %w", err)
	}
	return s.Preferences(ctx, userID)
}
