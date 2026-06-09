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
	ID                   string            `json:"id"`
	BoatID               string            `json:"boat_id"`
	OwnerID              string            `json:"owner_id"`
	GroupID              *string           `json:"group_id,omitempty"`
	Title                *string           `json:"title,omitempty"`
	Kind                 domain.TripKind   `json:"kind"`
	ScheduledAt          *time.Time        `json:"scheduled_at,omitempty"`
	ChecklistCompletedAt *time.Time        `json:"checklist_completed_at,omitempty"`
	DeparturePort        string            `json:"departure_port"`
	ArrivalPort          *string           `json:"arrival_port,omitempty"`
	DepartureTime        time.Time         `json:"departure_time"`
	ArrivalTime          *time.Time        `json:"arrival_time,omitempty"`
	DistanceNM           *float64          `json:"distance_nm,omitempty"`
	MaxSpeedKnots        *float64          `json:"max_speed_knots,omitempty"`
	AvgSpeedKnots        *float64          `json:"avg_speed_knots,omitempty"`
	EngineHours          *float64          `json:"engine_hours,omitempty"`
	FuelConsumedL        *float64          `json:"fuel_consumed_l,omitempty"`
	DurationMinutes      *int              `json:"duration_minutes,omitempty"`
	CrewMembers          []string          `json:"crew_members"`
	WeatherConditions    map[string]any    `json:"weather_conditions,omitempty"`
	Notes                *string           `json:"notes,omitempty"`
	Photos               []string          `json:"photos"`
	Status               domain.TripStatus `json:"status"`
	ShareToken           *string           `json:"share_token"`
	CreatedAt            time.Time         `json:"created_at"`
	UpdatedAt            time.Time         `json:"updated_at"`
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
	kind := t.Kind
	if kind == "" {
		kind = domain.TripKindTrip
	}
	return &TripResponse{
		ID:                   t.ID,
		BoatID:               t.BoatID,
		OwnerID:              t.UserID,
		GroupID:              t.GroupID,
		Title:                t.Title,
		Kind:                 kind,
		ScheduledAt:          t.ScheduledAt,
		ChecklistCompletedAt: t.ChecklistCompletedAt,
		DeparturePort:        t.DeparturePort,
		ArrivalPort:          t.ArrivalPort,
		DepartureTime:        t.DepartureTime,
		ArrivalTime:          t.ArrivalTime,
		DistanceNM:           t.DistanceNM,
		MaxSpeedKnots:        t.MaxSpeedKnots,
		AvgSpeedKnots:        t.AvgSpeedKnots,
		EngineHours:          t.EngineHours,
		FuelConsumedL:        t.FuelConsumedL,
		DurationMinutes:      t.DurationMinutes,
		CrewMembers:          crew,
		WeatherConditions:    t.WeatherConditions,
		Notes:                t.Notes,
		Photos:               photos,
		Status:               t.Status,
		ShareToken:           t.ShareToken,
		CreatedAt:            t.CreatedAt,
		UpdatedAt:            t.UpdatedAt,
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

// ScheduleRegattaRequest is the payload for scheduling a group regatta/outing.
type ScheduleRegattaRequest struct {
	BoatID        string     `json:"boat_id"        validate:"required,uuid"`
	Title         *string    `json:"title"          validate:"omitempty,max=120"`
	DeparturePort string     `json:"departure_port" validate:"required,min=1,max=100"`
	ScheduledAt   *time.Time `json:"scheduled_at"`
	CrewMembers   []string   `json:"crew_members"   validate:"omitempty,dive,min=1,max=100"`
	Notes         *string    `json:"notes"          validate:"omitempty,max=1000"`
}

// ToDomain converts the request DTO to a partial domain Trip (group/status are
// set by the service).
func (r *ScheduleRegattaRequest) ToDomain() *domain.Trip {
	crew := r.CrewMembers
	if crew == nil {
		crew = []string{}
	}
	return &domain.Trip{
		BoatID:        r.BoatID,
		Title:         r.Title,
		DeparturePort: r.DeparturePort,
		ScheduledAt:   r.ScheduledAt,
		CrewMembers:   crew,
		Notes:         r.Notes,
		Photos:        []string{},
	}
}

// RSVPRequest is the payload for answering attendance to a regatta.
type RSVPRequest struct {
	RSVP string `json:"rsvp" validate:"required,oneof=going maybe not_going"`
}

// ChecklistAddItemRequest is the payload for adding a custom checklist item.
type ChecklistAddItemRequest struct {
	Label string `json:"label" validate:"required,min=1,max=200"`
}

// ChecklistSetCheckedRequest is the payload for toggling a checklist item.
type ChecklistSetCheckedRequest struct {
	IsChecked bool `json:"is_checked"`
}

// ChecklistItemResponse is the API response for a checklist item.
type ChecklistItemResponse struct {
	ID        string `json:"id"`
	Label     string `json:"label"`
	IsChecked bool   `json:"is_checked"`
	Position  int    `json:"position"`
}

// ChecklistItemResponseFromDomain builds a ChecklistItemResponse from a domain item.
func ChecklistItemResponseFromDomain(i *domain.ChecklistItem) *ChecklistItemResponse {
	return &ChecklistItemResponse{
		ID:        i.ID,
		Label:     i.Label,
		IsChecked: i.IsChecked,
		Position:  i.Position,
	}
}

// ChecklistItemListResponseFromDomain converts a slice of domain items to response DTOs.
func ChecklistItemListResponseFromDomain(items []domain.ChecklistItem) []ChecklistItemResponse {
	out := make([]ChecklistItemResponse, len(items))
	for i := range items {
		out[i] = *ChecklistItemResponseFromDomain(&items[i])
	}
	return out
}

// TripParticipantResponse is the API response for a regatta RSVP.
type TripParticipantResponse struct {
	UserID      string      `json:"user_id"`
	Name        string      `json:"name"`
	RSVP        domain.RSVP `json:"rsvp"`
	RespondedAt time.Time   `json:"responded_at"`
}

// TripParticipantResponseFromDomain builds a response from a domain participant.
func TripParticipantResponseFromDomain(p *domain.TripParticipant) *TripParticipantResponse {
	return &TripParticipantResponse{
		UserID:      p.UserID,
		Name:        p.Name,
		RSVP:        p.RSVP,
		RespondedAt: p.RespondedAt,
	}
}

// TripParticipantListResponseFromDomain converts a slice of participants to DTOs.
func TripParticipantListResponseFromDomain(participants []domain.TripParticipant) []TripParticipantResponse {
	out := make([]TripParticipantResponse, len(participants))
	for i := range participants {
		out[i] = *TripParticipantResponseFromDomain(&participants[i])
	}
	return out
}

// ShareTripResponse is returned when a trip's public link is created.
type ShareTripResponse struct {
	Token string `json:"token"`
	URL   string `json:"url"`
}

// PublicTrackPoint is a single lat/lon on a public trip's route.
type PublicTrackPoint struct {
	Lat float64 `json:"lat"`
	Lon float64 `json:"lon"`
}

// PublicTripResponse is the public (unauthenticated) view of a shared trip.
type PublicTripResponse struct {
	DeparturePort   string             `json:"departure_port"`
	ArrivalPort     *string            `json:"arrival_port"`
	DepartureTime   time.Time          `json:"departure_time"`
	ArrivalTime     *time.Time         `json:"arrival_time"`
	DistanceNM      *float64           `json:"distance_nm"`
	DurationMinutes *int               `json:"duration_minutes"`
	Track           []PublicTrackPoint `json:"track"`
}

// PublicTripResponseFromDomain builds the public view from a trip and its track.
func PublicTripResponseFromDomain(t *domain.Trip, track []domain.TripTrack) PublicTripResponse {
	pts := make([]PublicTrackPoint, len(track))
	for i := range track {
		pts[i] = PublicTrackPoint{Lat: track[i].Lat, Lon: track[i].Lon}
	}
	return PublicTripResponse{
		DeparturePort:   t.DeparturePort,
		ArrivalPort:     t.ArrivalPort,
		DepartureTime:   t.DepartureTime,
		ArrivalTime:     t.ArrivalTime,
		DistanceNM:      t.DistanceNM,
		DurationMinutes: t.DurationMinutes,
		Track:           pts,
	}
}
