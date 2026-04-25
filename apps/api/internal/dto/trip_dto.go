package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// CreateTripRequest is the payload for starting a new trip.
type CreateTripRequest struct {
	BoatID        string   `json:"boat_id"        validate:"required,uuid"`
	DeparturePort string   `json:"departure_port" validate:"required,min=1,max=100"`
	CrewMembers   []string `json:"crew_members"   validate:"omitempty,dive,min=1,max=100"`
	Notes         *string  `json:"notes"          validate:"omitempty,max=1000"`
}

// ToDomain converts the request DTO to a domain Trip.
func (r *CreateTripRequest) ToDomain(userID string) *domain.Trip {
	crew := r.CrewMembers
	if crew == nil {
		crew = []string{}
	}
	return &domain.Trip{
		BoatID:        r.BoatID,
		UserID:        userID,
		DeparturePort: r.DeparturePort,
		DepartureTime: time.Now().UTC(),
		CrewMembers:   crew,
		Notes:         r.Notes,
		Photos:        []string{},
		Status:        domain.TripStatusRecording,
	}
}

// CompleteTripRequest is the payload for completing a trip.
type CompleteTripRequest struct {
	ArrivalPort   *string  `json:"arrival_port"    validate:"omitempty,min=1,max=100"`
	DistanceNM    *float64 `json:"distance_nm"     validate:"omitempty,gte=0"`
	EngineHours   *float64 `json:"engine_hours"    validate:"omitempty,gte=0"`
	FuelConsumedL *float64 `json:"fuel_consumed_l" validate:"omitempty,gte=0"`
}

// TrackPointRequest represents a single GPS track point in a batch upload.
type TrackPointRequest struct {
	Lat        float64  `json:"lat"         validate:"required,latitude"`
	Lon        float64  `json:"lon"         validate:"required,longitude"`
	SpeedKnots *float64 `json:"speed_knots" validate:"omitempty,gte=0"`
	Heading    *float64 `json:"heading"     validate:"omitempty,gte=0,lte=360"`
	RecordedAt string   `json:"recorded_at" validate:"required"`
}

// BatchTrackRequest is the payload for uploading multiple track points.
type BatchTrackRequest struct {
	Points []TrackPointRequest `json:"points" validate:"required,min=1,dive"`
}

// ToDomain converts the batch of track point DTOs to domain TripTracks.
func (r *BatchTrackRequest) ToDomain(tripID string) ([]domain.TripTrack, error) {
	tracks := make([]domain.TripTrack, 0, len(r.Points))
	for _, p := range r.Points {
		t, err := time.Parse(time.RFC3339, p.RecordedAt)
		if err != nil {
			return nil, &domain.ValidationError{
				Field:   "recorded_at",
				Message: "must be a valid RFC3339 timestamp",
			}
		}
		tracks = append(tracks, domain.TripTrack{
			TripID:     tripID,
			Lat:        p.Lat,
			Lon:        p.Lon,
			SpeedKnots: p.SpeedKnots,
			Heading:    p.Heading,
			RecordedAt: t,
		})
	}
	return tracks, nil
}

// TripResponse is the API response for a trip.
type TripResponse struct {
	ID                string            `json:"id"`
	BoatID            string            `json:"boat_id"`
	DeparturePort     string            `json:"departure_port"`
	ArrivalPort       *string           `json:"arrival_port,omitempty"`
	DepartureTime     time.Time         `json:"departure_time"`
	ArrivalTime       *time.Time        `json:"arrival_time,omitempty"`
	DistanceNM        *float64          `json:"distance_nm,omitempty"`
	EngineHours       *float64          `json:"engine_hours,omitempty"`
	FuelConsumedL     *float64          `json:"fuel_consumed_l,omitempty"`
	DurationMinutes   *int              `json:"duration_minutes,omitempty"`
	CrewMembers       []string          `json:"crew_members"`
	WeatherConditions map[string]any    `json:"weather_conditions,omitempty"`
	Notes             *string           `json:"notes,omitempty"`
	Photos            []string          `json:"photos"`
	Status            domain.TripStatus `json:"status"`
	CreatedAt         time.Time         `json:"created_at"`
	UpdatedAt         time.Time         `json:"updated_at"`
}

// TripResponseFromDomain builds a TripResponse from a domain Trip.
func TripResponseFromDomain(t *domain.Trip) *TripResponse {
	crew := t.CrewMembers
	if crew == nil {
		crew = []string{}
	}
	photos := t.Photos
	if photos == nil {
		photos = []string{}
	}
	return &TripResponse{
		ID:                t.ID,
		BoatID:            t.BoatID,
		DeparturePort:     t.DeparturePort,
		ArrivalPort:       t.ArrivalPort,
		DepartureTime:     t.DepartureTime,
		ArrivalTime:       t.ArrivalTime,
		DistanceNM:        t.DistanceNM,
		EngineHours:       t.EngineHours,
		FuelConsumedL:     t.FuelConsumedL,
		DurationMinutes:   t.DurationMinutes,
		CrewMembers:       crew,
		WeatherConditions: t.WeatherConditions,
		Notes:             t.Notes,
		Photos:            photos,
		Status:            t.Status,
		CreatedAt:         t.CreatedAt,
		UpdatedAt:         t.UpdatedAt,
	}
}

// TripListResponseFromDomain converts a slice of domain trips to response DTOs.
func TripListResponseFromDomain(trips []domain.Trip) []TripResponse {
	out := make([]TripResponse, len(trips))
	for i := range trips {
		out[i] = *TripResponseFromDomain(&trips[i])
	}
	return out
}

// TrackPointResponse is the API response for a single track point.
type TrackPointResponse struct {
	ID         string   `json:"id"`
	Lat        float64  `json:"lat"`
	Lon        float64  `json:"lon"`
	SpeedKnots *float64 `json:"speed_knots,omitempty"`
	Heading    *float64 `json:"heading,omitempty"`
	RecordedAt string   `json:"recorded_at"`
}

// TrackPointResponseFromDomain builds a TrackPointResponse from a domain TripTrack.
func TrackPointResponseFromDomain(t *domain.TripTrack) *TrackPointResponse {
	return &TrackPointResponse{
		ID:         t.ID,
		Lat:        t.Lat,
		Lon:        t.Lon,
		SpeedKnots: t.SpeedKnots,
		Heading:    t.Heading,
		RecordedAt: t.RecordedAt.Format(time.RFC3339),
	}
}

// TrackPointListResponseFromDomain converts a slice of domain tracks to response DTOs.
func TrackPointListResponseFromDomain(tracks []domain.TripTrack) []TrackPointResponse {
	out := make([]TrackPointResponse, len(tracks))
	for i := range tracks {
		out[i] = *TrackPointResponseFromDomain(&tracks[i])
	}
	return out
}
