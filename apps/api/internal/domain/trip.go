package domain

import "time"

// TripStatus represents the current status of a trip.
type TripStatus string

// TripStatus values.
const (
	TripStatusPlanned   TripStatus = "planned"
	TripStatusRecording TripStatus = "recording"
	TripStatusCompleted TripStatus = "completed"
	TripStatusCancelled TripStatus = "cancelled"
)

// TripKind distinguishes a regular trip from a group regatta.
type TripKind string

// TripKind values.
const (
	TripKindTrip    TripKind = "trip"
	TripKindRegatta TripKind = "regatta"
)

// RSVP represents a participant's attendance answer to a planned group trip.
type RSVP string

// RSVP values.
const (
	RSVPGoing    RSVP = "going"
	RSVPMaybe    RSVP = "maybe"
	RSVPNotGoing RSVP = "not_going"
)

// Trip represents a sailing trip, passage, or group regatta.
type Trip struct {
	ID                   string
	BoatID               string
	UserID               string
	GroupID              *string
	Title                *string
	Kind                 TripKind
	ScheduledAt          *time.Time
	ChecklistCompletedAt *time.Time
	DeparturePort        string
	ArrivalPort          *string
	DepartureTime        time.Time
	ArrivalTime          *time.Time
	DistanceNM           *float64
	MaxSpeedKnots        *float64
	AvgSpeedKnots        *float64
	EngineHours          *float64
	FuelConsumedL        *float64
	DurationMinutes      *int
	CrewMembers          []string
	WeatherConditions    map[string]any
	Notes                *string
	Photos               []string
	Status               TripStatus
	CreatedAt            time.Time
	UpdatedAt            time.Time
}

// TripParticipant represents a user's RSVP to a planned group trip/regatta.
type TripParticipant struct {
	TripID      string
	UserID      string
	RSVP        RSVP
	RespondedAt time.Time
}

// ChecklistItem represents a single safety-checklist entry attached to a trip.
type ChecklistItem struct {
	ID        string
	TripID    string
	Label     string
	IsChecked bool
	Position  int
	CreatedAt time.Time
	UpdatedAt time.Time
}

// TripTrack represents a single GPS track point recorded during a trip.
type TripTrack struct {
	ID         string
	TripID     string
	Lat        float64
	Lon        float64
	SpeedKnots *float64
	Heading    *float64
	RecordedAt time.Time
}
