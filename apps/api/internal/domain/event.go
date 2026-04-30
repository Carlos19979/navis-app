package domain

import "time"

// EventType represents the category of an event.
type EventType string

// EventType values.
const (
	EventTypeRegatta    EventType = "regatta"
	EventTypeCruise     EventType = "cruise"
	EventTypeMeetup     EventType = "meetup"
	EventTypeExhibition EventType = "exhibition"
	EventTypeCourse     EventType = "course"
	EventTypeOther      EventType = "other"
)

// Event represents a nautical event such as a regatta, meetup, or course.
type Event struct {
	ID               string
	Name             string
	Organizer        string
	OrganizerLogoURL *string
	Description      *string
	EventType        EventType
	LocationName     string
	Lat              *float64
	Lon              *float64
	StartDate        time.Time
	EndDate          *time.Time
	BoatClasses      []string
	RegistrationURL  *string
	DocumentsURL     *string
	IsFeatured       bool
	CreatedAt        time.Time
	UpdatedAt        time.Time
}
