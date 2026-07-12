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

	MaintenanceIntervalMonths *int     `json:"maintenance_interval_months" validate:"omitempty,gt=0"`
	MaintenanceIntervalHours  *float64 `json:"maintenance_interval_hours" validate:"omitempty,gt=0"`
}

// ToDomain converts the request DTO to a domain Boat.
func (r *CreateBoatRequest) ToDomain(userID string) *domain.Boat {
	return &domain.Boat{
		UserID:                    userID,
		Name:                      r.Name,
		Registration:              r.Registration,
		Type:                      r.Type,
		LengthM:                   r.LengthM,
		HomePort:                  r.HomePort,
		HomePortLat:               r.HomePortLat,
		HomePortLon:               r.HomePortLon,
		PhotoURL:                  r.PhotoURL,
		EngineHours:               r.EngineHours,
		MaintenanceIntervalMonths: r.MaintenanceIntervalMonths,
		MaintenanceIntervalHours:  r.MaintenanceIntervalHours,
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

	MaintenanceIntervalMonths *int     `json:"maintenance_interval_months" validate:"omitempty,gte=0"`
	MaintenanceIntervalHours  *float64 `json:"maintenance_interval_hours" validate:"omitempty,gte=0"`
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
	// A value of 0 clears the interval (no schedule); >0 sets it.
	if r.MaintenanceIntervalMonths != nil {
		if *r.MaintenanceIntervalMonths == 0 {
			boat.MaintenanceIntervalMonths = nil
		} else {
			boat.MaintenanceIntervalMonths = r.MaintenanceIntervalMonths
		}
	}
	if r.MaintenanceIntervalHours != nil {
		if *r.MaintenanceIntervalHours == 0 {
			boat.MaintenanceIntervalHours = nil
		} else {
			boat.MaintenanceIntervalHours = r.MaintenanceIntervalHours
		}
	}
}

// BoatResponse is the API response for a boat.
type BoatResponse struct {
	ID           string                  `json:"id"`
	Name         string                  `json:"name"`
	Registration string                  `json:"registration"`
	Type         domain.BoatType         `json:"type"`
	LengthM      float64                 `json:"length_m"`
	HomePort     string                  `json:"home_port"`
	HomePortLat  *float64                `json:"home_port_lat,omitempty"`
	HomePortLon  *float64                `json:"home_port_lon,omitempty"`
	PhotoURL     *string                 `json:"photo_url,omitempty"`
	EngineHours  float64                 `json:"engine_hours"`

	MaintenanceIntervalMonths *int     `json:"maintenance_interval_months,omitempty"`
	MaintenanceIntervalHours  *float64 `json:"maintenance_interval_hours,omitempty"`

	IsOwner     bool                    `json:"is_owner"`
	Permissions  BoatPermissionsResponse `json:"permissions"`
	CreatedAt    time.Time               `json:"created_at"`
	UpdatedAt    time.Time               `json:"updated_at"`
}

// BoatPermissionsResponse is the granular permission set for the current user
// on a boat (all true for the owner).
type BoatPermissionsResponse struct {
	CanRecordTrips       bool `json:"can_record_trips"`
	CanManageExpenses    bool `json:"can_manage_expenses"`
	CanManageMaintenance bool `json:"can_manage_maintenance"`
	CanViewDocuments     bool `json:"can_view_documents"`
	CanManageDocuments   bool `json:"can_manage_documents"`
}

// BoatPermissionsResponseFromDomain converts domain permissions to a response.
func BoatPermissionsResponseFromDomain(p domain.BoatPermissions) BoatPermissionsResponse {
	return BoatPermissionsResponse{
		CanRecordTrips:       p.CanRecordTrips,
		CanManageExpenses:    p.CanManageExpenses,
		CanManageMaintenance: p.CanManageMaintenance,
		CanViewDocuments:     p.CanViewDocuments,
		CanManageDocuments:   p.CanManageDocuments,
	}
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
		MaintenanceIntervalMonths: b.MaintenanceIntervalMonths,
		MaintenanceIntervalHours:  b.MaintenanceIntervalHours,
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

// BoatMemberResponse is a shared member of a boat, with their permissions.
type BoatMemberResponse struct {
	UserID      string                  `json:"user_id"`
	Name        string                  `json:"name"`
	Permissions BoatPermissionsResponse `json:"permissions"`
}

// BoatMemberListFromDomain converts domain boat members to responses.
func BoatMemberListFromDomain(members []domain.BoatMember) []BoatMemberResponse {
	out := make([]BoatMemberResponse, len(members))
	for i := range members {
		out[i] = BoatMemberResponse{
			UserID:      members[i].UserID,
			Name:        members[i].Name,
			Permissions: BoatPermissionsResponseFromDomain(members[i].Permissions),
		}
	}
	return out
}

// UpdateBoatMemberPermissionsRequest sets a member's granular permissions.
type UpdateBoatMemberPermissionsRequest struct {
	CanRecordTrips       bool `json:"can_record_trips"`
	CanManageExpenses    bool `json:"can_manage_expenses"`
	CanManageMaintenance bool `json:"can_manage_maintenance"`
	CanViewDocuments     bool `json:"can_view_documents"`
	CanManageDocuments   bool `json:"can_manage_documents"`
}

// ToDomain converts the request to a domain permission set.
func (r *UpdateBoatMemberPermissionsRequest) ToDomain() domain.BoatPermissions {
	return domain.BoatPermissions{
		CanRecordTrips:       r.CanRecordTrips,
		CanManageExpenses:    r.CanManageExpenses,
		CanManageMaintenance: r.CanManageMaintenance,
		CanViewDocuments:     r.CanViewDocuments,
		CanManageDocuments:   r.CanManageDocuments,
	}
}
