package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// CreateBoatRequest is the payload for creating a new boat.
type CreateBoatRequest struct {
	Name         string          `json:"name"         validate:"required,min=1,max=100"`
	Registration string          `json:"registration" validate:"required,min=1,max=50"`
	Type         domain.BoatType `json:"type"         validate:"required,oneof=sailboat motorboat catamaran rib jetski other"`
	LengthM      float64         `json:"length_m"     validate:"required,gt=0"`
	HomePort     string          `json:"home_port"    validate:"required,min=1,max=100"`
	HomePortLat  *float64        `json:"home_port_lat" validate:"omitempty,latitude"`
	HomePortLon  *float64        `json:"home_port_lon" validate:"omitempty,longitude"`
	PhotoURL     *string         `json:"photo_url"    validate:"omitempty,url"`
	EngineHours  float64         `json:"engine_hours" validate:"gte=0"`
}

// ToDomain converts the request DTO to a domain Boat.
func (r *CreateBoatRequest) ToDomain(userID string) *domain.Boat {
	return &domain.Boat{
		UserID:       userID,
		Name:         r.Name,
		Registration: r.Registration,
		Type:         r.Type,
		LengthM:      r.LengthM,
		HomePort:     r.HomePort,
		HomePortLat:  r.HomePortLat,
		HomePortLon:  r.HomePortLon,
		PhotoURL:     r.PhotoURL,
		EngineHours:  r.EngineHours,
	}
}

// UpdateBoatRequest is the payload for updating an existing boat.
type UpdateBoatRequest struct {
	Name         *string          `json:"name"         validate:"omitempty,min=1,max=100"`
	Registration *string          `json:"registration" validate:"omitempty,min=1,max=50"`
	Type         *domain.BoatType `json:"type"         validate:"omitempty,oneof=sailboat motorboat catamaran rib jetski other"`
	LengthM      *float64         `json:"length_m"     validate:"omitempty,gt=0"`
	HomePort     *string          `json:"home_port"    validate:"omitempty,min=1,max=100"`
	HomePortLat  *float64         `json:"home_port_lat" validate:"omitempty,latitude"`
	HomePortLon  *float64         `json:"home_port_lon" validate:"omitempty,longitude"`
	PhotoURL     *string          `json:"photo_url"    validate:"omitempty,url"`
	EngineHours  *float64         `json:"engine_hours" validate:"omitempty,gte=0"`
}

// ApplyTo merges non-nil fields from the request into the given domain Boat.
func (r *UpdateBoatRequest) ApplyTo(boat *domain.Boat) {
	if r.Name != nil {
		boat.Name = *r.Name
	}
	if r.Registration != nil {
		boat.Registration = *r.Registration
	}
	if r.Type != nil {
		boat.Type = *r.Type
	}
	if r.LengthM != nil {
		boat.LengthM = *r.LengthM
	}
	if r.HomePort != nil {
		boat.HomePort = *r.HomePort
	}
	if r.HomePortLat != nil {
		boat.HomePortLat = r.HomePortLat
	}
	if r.HomePortLon != nil {
		boat.HomePortLon = r.HomePortLon
	}
	if r.PhotoURL != nil {
		boat.PhotoURL = r.PhotoURL
	}
	if r.EngineHours != nil {
		boat.EngineHours = *r.EngineHours
	}
}

// BoatResponse is the API response for a boat.
type BoatResponse struct {
	ID           string          `json:"id"`
	Name         string          `json:"name"`
	Registration string          `json:"registration"`
	Type         domain.BoatType `json:"type"`
	LengthM      float64         `json:"length_m"`
	HomePort     string          `json:"home_port"`
	HomePortLat  *float64        `json:"home_port_lat,omitempty"`
	HomePortLon  *float64        `json:"home_port_lon,omitempty"`
	PhotoURL     *string         `json:"photo_url,omitempty"`
	EngineHours  float64         `json:"engine_hours"`
	IsOwner      bool            `json:"is_owner"`
	CanRecord    bool            `json:"can_record"`
	CreatedAt    time.Time       `json:"created_at"`
	UpdatedAt    time.Time       `json:"updated_at"`
}

// BoatResponseFromDomain builds a BoatResponse from a domain Boat.
func BoatResponseFromDomain(b *domain.Boat) *BoatResponse {
	return &BoatResponse{
		ID:           b.ID,
		Name:         b.Name,
		Registration: b.Registration,
		Type:         b.Type,
		LengthM:      b.LengthM,
		HomePort:     b.HomePort,
		HomePortLat:  b.HomePortLat,
		HomePortLon:  b.HomePortLon,
		PhotoURL:     b.PhotoURL,
		EngineHours:  b.EngineHours,
		CreatedAt:    b.CreatedAt,
		UpdatedAt:    b.UpdatedAt,
	}
}

// BoatListResponseFromDomain converts a slice of domain boats to response DTOs.
func BoatListResponseFromDomain(boats []domain.Boat) []BoatResponse {
	out := make([]BoatResponse, len(boats))
	for i := range boats {
		out[i] = *BoatResponseFromDomain(&boats[i])
	}
	return out
}

// BoatShareCodeResponse carries a boat's invite code.
type BoatShareCodeResponse struct {
	Code string `json:"code"`
}

// JoinBoatRequest is the payload to join a boat by its share code.
type JoinBoatRequest struct {
	Code string `json:"code" validate:"required"`
}

// BoatMemberResponse is a shared member of a boat.
type BoatMemberResponse struct {
	UserID string `json:"user_id"`
	Name   string `json:"name"`
	Role   string `json:"role"`
}

// BoatMemberListFromDomain converts domain boat members to responses.
func BoatMemberListFromDomain(members []domain.BoatMember) []BoatMemberResponse {
	out := make([]BoatMemberResponse, len(members))
	for i := range members {
		out[i] = BoatMemberResponse{
			UserID: members[i].UserID,
			Name:   members[i].Name,
			Role:   members[i].Role,
		}
	}
	return out
}

// UpdateBoatMemberRoleRequest changes a shared member's role.
type UpdateBoatMemberRoleRequest struct {
	Role string `json:"role" validate:"required,oneof=viewer editor"`
}
