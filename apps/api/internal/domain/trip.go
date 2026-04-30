package domain

import "time"

// TripStatus represents the current status of a trip.
type TripStatus string

// TripStatus values.
const (
	TripStatusRecording TripStatus = "recording"
	TripStatusCompleted TripStatus = "completed"
)

// Trip represents a sailing trip or passage.
type Trip struct {
	ID                string
	BoatID            string
	UserID            string
	DeparturePort     string
	ArrivalPort       *string
	DepartureTime     time.Time
	ArrivalTime       *time.Time
	DistanceNM        *float64
	MaxSpeedKnots     *float64
	AvgSpeedKnots     *float64
	EngineHours       *float64
	FuelConsumedL     *float64
	DurationMinutes   *int
	CrewMembers       []string
	WeatherConditions map[string]any
	Notes             *string
	Photos            []string
	Status            TripStatus
	CreatedAt         time.Time
	UpdatedAt         time.Time
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
