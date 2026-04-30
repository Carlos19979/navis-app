package domain

import "time"

// Platform values.
const (
	PlatformIOS     Platform = "ios"
	PlatformAndroid Platform = "android"
)

// Platform represents the mobile OS of a device.
type Platform string

// DeviceToken represents a registered push notification token.
type DeviceToken struct {
	ID        string
	UserID    string
	Token     string
	Platform  Platform
	CreatedAt time.Time
	UpdatedAt time.Time
}
