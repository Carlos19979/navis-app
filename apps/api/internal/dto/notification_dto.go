package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// NotificationResponse is one entry of the notification feed.
type NotificationResponse struct {
	ID       string `json:"id"`
	Category string `json:"category"`
	Title    string `json:"title"`
	Body     string `json:"body"`
	// LinkType and LinkID are the deep-link target for the tap; omitted when
	// the notification has no destination.
	LinkType  *string   `json:"link_type"`
	LinkID    *string   `json:"link_id"`
	Read      bool      `json:"read"`
	ReadAt    *string   `json:"read_at"`
	CreatedAt time.Time `json:"created_at"`
}

// NotificationResponseFromDomain converts a domain notification.
func NotificationResponseFromDomain(n domain.Notification) NotificationResponse {
	resp := NotificationResponse{
		ID:        n.ID,
		Category:  string(n.Category),
		Title:     n.Title,
		Body:      n.Body,
		Read:      n.Read(),
		CreatedAt: n.CreatedAt,
	}
	if n.LinkType != "" {
		resp.LinkType = &n.LinkType
	}
	if n.LinkID != "" {
		resp.LinkID = &n.LinkID
	}
	if n.ReadAt != nil {
		readAt := n.ReadAt.Format(time.RFC3339)
		resp.ReadAt = &readAt
	}
	return resp
}

// NotificationListResponse converts a page of notifications.
func NotificationListResponse(items []domain.Notification) []NotificationResponse {
	out := make([]NotificationResponse, 0, len(items))
	for _, n := range items {
		out = append(out, NotificationResponseFromDomain(n))
	}
	return out
}

// UnreadCountResponse is the bell badge value.
type UnreadCountResponse struct {
	Count int `json:"count"`
}

// NotificationPreference is one category toggle.
type NotificationPreference struct {
	Category string `json:"category" validate:"required,oneof=reminders regatta-updates group-updates boat-activity event-live"`
	Enabled  bool   `json:"enabled"`
}

// NotificationPreferencesResponse lists every category with the user's choice,
// in the order the app shows them.
type NotificationPreferencesResponse struct {
	Categories []NotificationPreference `json:"categories"`
}

// NotificationPreferencesResponseFromDomain converts service preferences.
func NotificationPreferencesResponseFromDomain(prefs []domain.CategoryPreference) NotificationPreferencesResponse {
	categories := make([]NotificationPreference, 0, len(prefs))
	for _, p := range prefs {
		categories = append(categories, NotificationPreference{
			Category: string(p.Category),
			Enabled:  p.Enabled,
		})
	}
	return NotificationPreferencesResponse{Categories: categories}
}

// UpdateNotificationPreferencesRequest replaces the caller's preferences. Any
// category left out of the list stays enabled.
type UpdateNotificationPreferencesRequest struct {
	Categories []NotificationPreference `json:"categories" validate:"required,max=5,dive"`
}

// ToDomain converts the request to the domain representation.
func (r *UpdateNotificationPreferencesRequest) ToDomain() []domain.CategoryPreference {
	prefs := make([]domain.CategoryPreference, 0, len(r.Categories))
	for _, c := range r.Categories {
		prefs = append(prefs, domain.CategoryPreference{
			Category: domain.NotificationCategory(c.Category),
			Enabled:  c.Enabled,
		})
	}
	return prefs
}
