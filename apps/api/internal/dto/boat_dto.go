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
	HomePort     *string         `json:"home_port"    validate:"omitempty,min=1,max=100"`
	HomePortLat  *float64        `json:"home_port_lat" validate:"omitempty,latitude"`
	HomePortLon  *float64        `json:"home_port_lon" validate:"omitempty,longitude"`
	PhotoURL     *string         `json:"photo_url"    validate:"omitempty,url"`
	PhotoURLs    []string        `json:"photo_urls"   validate:"omitempty,max=10,dive,url"`
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
		PhotoURLs:    r.PhotoURLs,
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
	PhotoURLs    []string         `json:"photo_urls"   validate:"omitempty,max=10,dive,url"`
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
		boat.HomePort = r.HomePort
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
	// nil = field omitted (keep current gallery); [] = clear it.
	if r.PhotoURLs != nil {
		boat.PhotoURLs = r.PhotoURLs
	}
	if r.EngineHours != nil {
		boat.EngineHours = *r.EngineHours
	}
}

// BoatResponse is the API response for a boat.
type BoatResponse struct {
	ID           string                  `json:"id"`
	Name         string                  `json:"name"`
	Registration string                  `json:"registration"`
	Type         domain.BoatType         `json:"type"`
	LengthM      float64                 `json:"length_m"`
	HomePort     *string                 `json:"home_port"`
	HomePortLat  *float64                `json:"home_port_lat,omitempty"`
	HomePortLon  *float64                `json:"home_port_lon,omitempty"`
	PhotoURL     *string                 `json:"photo_url,omitempty"`
	PhotoURLs    []string                `json:"photo_urls"`
	EngineHours  float64                 `json:"engine_hours"`
	IsOwner      bool                    `json:"is_owner"`
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

// BoatEffectivePermissionsResponse is the caller's own permission set on a boat,
// as served by GET /boats/{id}/permissions. It exists so a client can gate the
// UI before the user does any work: the same flags are enforced on the write
// paths, where a denial arrives as a 403 on save.
//
// Callers with no access get 404, so a 200 always describes real access.
// Ownership is not repeated here — it belongs to the boat resource
// (BoatResponse.IsOwner).
type BoatEffectivePermissionsResponse struct {
	BoatID      string                  `json:"boat_id"`
	Permissions BoatPermissionsResponse `json:"permissions"`
}

// BoatEffectivePermissionsResponseFromDomain builds the permissions response for
// a boat.
func BoatEffectivePermissionsResponseFromDomain(boatID string, p domain.BoatPermissions) BoatEffectivePermissionsResponse {
	return BoatEffectivePermissionsResponse{
		BoatID:      boatID,
		Permissions: BoatPermissionsResponseFromDomain(p),
	}
}

// BoatResponseFromDomain builds a BoatResponse for a given viewer. IsOwner and
// Permissions are always filled from viewerID and perms — never left at their
// zero value, which would tell the client the user may do nothing.
func BoatResponseFromDomain(b *domain.Boat, viewerID string, perms domain.BoatPermissions) *BoatResponse {
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
		PhotoURLs:    emptyIfNil(b.PhotoURLs),
		EngineHours:  b.EngineHours,
		IsOwner:      b.UserID == viewerID,
		Permissions:  BoatPermissionsResponseFromDomain(perms),
		CreatedAt:    b.CreatedAt,
		UpdatedAt:    b.UpdatedAt,
	}
}

// OwnedBoatResponseFromDomain builds the response for a boat the caller owns
// (the owner-scoped paths: create, update, list). Owners hold every permission,
// so no lookup is needed.
func OwnedBoatResponseFromDomain(b *domain.Boat) *BoatResponse {
	return BoatResponseFromDomain(b, b.UserID, domain.OwnerPermissions())
}

// OwnedBoatListResponseFromDomain converts a slice of boats the caller owns to
// response DTOs.
func OwnedBoatListResponseFromDomain(boats []domain.Boat) []BoatResponse {
	out := make([]BoatResponse, len(boats))
	for i := range boats {
		out[i] = *OwnedBoatResponseFromDomain(&boats[i])
	}
	return out
}

// SharedBoatResponseFromDomain builds the response for a boat reached through a
// membership, carrying that membership's permissions.
func SharedBoatResponseFromDomain(s *domain.SharedBoat, viewerID string) *BoatResponse {
	return BoatResponseFromDomain(&s.Boat, viewerID, s.Permissions)
}

// SharedBoatListResponseFromDomain converts shared boats to response DTOs.
func SharedBoatListResponseFromDomain(shared []domain.SharedBoat, viewerID string) []BoatResponse {
	out := make([]BoatResponse, len(shared))
	for i := range shared {
		out[i] = *SharedBoatResponseFromDomain(&shared[i], viewerID)
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
