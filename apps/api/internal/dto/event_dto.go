package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// EventListParams captures query parameters for listing events.
type EventListParams struct {
	Cursor   string  `query:"cursor"`
	Limit    int     `query:"limit"    validate:"omitempty,gte=1,lte=50"`
	Lat      *float64 `query:"lat"      validate:"omitempty,latitude"`
	Lon      *float64 `query:"lon"      validate:"omitempty,longitude"`
	RadiusKM *float64 `query:"radius_km" validate:"omitempty,gt=0"`
}

// EventResponse is the API response for an event.
type EventResponse struct {
	ID               string           `json:"id"`
	Name             string           `json:"name"`
	Organizer        string           `json:"organizer"`
	OrganizerLogoURL *string          `json:"organizer_logo_url,omitempty"`
	Description      *string          `json:"description,omitempty"`
	EventType        domain.EventType `json:"event_type"`
	LocationName     string           `json:"location_name"`
	Lat              *float64         `json:"lat,omitempty"`
	Lon              *float64         `json:"lon,omitempty"`
	StartDate        time.Time        `json:"start_date"`
	EndDate          *time.Time       `json:"end_date,omitempty"`
	BoatClasses      []string         `json:"boat_classes"`
	RegistrationURL  *string          `json:"registration_url,omitempty"`
	DocumentsURL     *string          `json:"documents_url,omitempty"`
	IsFeatured       bool             `json:"is_featured"`
	IsInterested     bool             `json:"is_interested"`
	CreatedAt        time.Time        `json:"created_at"`
	UpdatedAt        time.Time        `json:"updated_at"`
}

// EventResponseFromDomain builds an EventResponse from a domain Event.
// isInterested must be resolved by the caller (handler or service layer).
func EventResponseFromDomain(e *domain.Event, isInterested bool) *EventResponse {
	classes := e.BoatClasses
	if classes == nil {
		classes = []string{}
	}
	return &EventResponse{
		ID:               e.ID,
		Name:             e.Name,
		Organizer:        e.Organizer,
		OrganizerLogoURL: e.OrganizerLogoURL,
		Description:      e.Description,
		EventType:        e.EventType,
		LocationName:     e.LocationName,
		Lat:              e.Lat,
		Lon:              e.Lon,
		StartDate:        e.StartDate,
		EndDate:          e.EndDate,
		BoatClasses:      classes,
		RegistrationURL:  e.RegistrationURL,
		DocumentsURL:     e.DocumentsURL,
		IsFeatured:       e.IsFeatured,
		IsInterested:     isInterested,
		CreatedAt:        e.CreatedAt,
		UpdatedAt:        e.UpdatedAt,
	}
}

// EventListResponseFromDomain converts a slice of domain events to response DTOs.
// The interested map should contain event IDs the current user has bookmarked.
func EventListResponseFromDomain(events []domain.Event, interested map[string]bool) []EventResponse {
	out := make([]EventResponse, len(events))
	for i := range events {
		out[i] = *EventResponseFromDomain(&events[i], interested[events[i].ID])
	}
	return out
}
