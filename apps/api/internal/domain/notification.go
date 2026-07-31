package domain

import "time"

// NotificationCategory groups notifications by domain. The values double as
// the Novu workflow identifiers (see service.Workflow* constants) and as the
// axis the user mutes: one toggle per category.
type NotificationCategory string

// NotificationCategory values.
const (
	CategoryReminders      NotificationCategory = "reminders"
	CategoryRegattaUpdates NotificationCategory = "regatta-updates"
	CategoryGroupUpdates   NotificationCategory = "group-updates"
	CategoryBoatActivity   NotificationCategory = "boat-activity"
	CategoryEventLive      NotificationCategory = "event-live"
)

// AllNotificationCategories lists every category, in the order the app shows
// the preference toggles.
func AllNotificationCategories() []NotificationCategory {
	return []NotificationCategory{
		CategoryReminders,
		CategoryRegattaUpdates,
		CategoryGroupUpdates,
		CategoryBoatActivity,
		CategoryEventLive,
	}
}

// Valid reports whether the category is one we store notifications for.
func (c NotificationCategory) Valid() bool {
	switch c {
	case CategoryReminders, CategoryRegattaUpdates, CategoryGroupUpdates,
		CategoryBoatActivity, CategoryEventLive:
		return true
	default:
		return false
	}
}

// Notification is one delivered notification, kept so the app can show a
// history (the bell icon) independently of whether the push itself arrived.
type Notification struct {
	ID       string
	UserID   string
	Category NotificationCategory
	Title    string
	Body     string
	// LinkType and LinkID are the deep-link target for the tap, mirroring the
	// {type, id} pair carried in the push payload. Empty means "no target".
	LinkType  string
	LinkID    string
	ReadAt    *time.Time
	CreatedAt time.Time
}

// Read reports whether the notification has been read.
func (n Notification) Read() bool { return n.ReadAt != nil }

// CategoryPreference is one category and whether the user wants to receive it.
type CategoryPreference struct {
	Category NotificationCategory
	Enabled  bool
}
