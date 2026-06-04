package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// CreateGroupRequest is the payload for creating a new group.
type CreateGroupRequest struct {
	Name        string  `json:"name"        validate:"required,min=1,max=100"`
	Description *string `json:"description" validate:"omitempty,max=500"`
	PhotoURL    *string `json:"photo_url"   validate:"omitempty,url"`
	Visibility  string  `json:"visibility"  validate:"required,oneof=public private"`
}

// ToDomain converts the request DTO to a domain Group.
func (r *CreateGroupRequest) ToDomain(ownerID string) *domain.Group {
	return &domain.Group{
		OwnerID:     ownerID,
		Name:        r.Name,
		Description: r.Description,
		PhotoURL:    r.PhotoURL,
		Visibility:  domain.GroupVisibility(r.Visibility),
	}
}

// UpdateGroupRequest is the payload for updating an existing group.
type UpdateGroupRequest struct {
	Name        *string `json:"name"        validate:"omitempty,min=1,max=100"`
	Description *string `json:"description" validate:"omitempty,max=500"`
	PhotoURL    *string `json:"photo_url"   validate:"omitempty,url"`
	Visibility  *string `json:"visibility"  validate:"omitempty,oneof=public private"`
}

// ApplyTo merges non-nil fields from the request into the given domain Group.
func (r *UpdateGroupRequest) ApplyTo(group *domain.Group) {
	if r.Name != nil {
		group.Name = *r.Name
	}
	if r.Description != nil {
		group.Description = r.Description
	}
	if r.PhotoURL != nil {
		group.PhotoURL = r.PhotoURL
	}
	if r.Visibility != nil {
		group.Visibility = domain.GroupVisibility(*r.Visibility)
	}
}

// JoinByCodeRequest is the payload for joining a private group with an invite code.
type JoinByCodeRequest struct {
	Code string `json:"code" validate:"required,min=4,max=32"`
}

// GroupResponse is the API response for a group.
type GroupResponse struct {
	ID                 string                 `json:"id"`
	OwnerID            string                 `json:"owner_id"`
	Name               string                 `json:"name"`
	Description        *string                `json:"description,omitempty"`
	PhotoURL           *string                `json:"photo_url,omitempty"`
	Visibility         domain.GroupVisibility `json:"visibility"`
	InviteCode         *string                `json:"invite_code,omitempty"`
	MemberCount        int                    `json:"member_count"`
	PendingCount       int                    `json:"pending_count"`
	MyMembershipStatus string                 `json:"my_membership_status"`
	MyRole             string                 `json:"my_role,omitempty"`
	CreatedAt          time.Time              `json:"created_at"`
	UpdatedAt          time.Time              `json:"updated_at"`
}

// GroupResponseFromDomain builds a GroupResponse from a domain Group.
// The invite code is only exposed to the group owner.
func GroupResponseFromDomain(g *domain.Group) *GroupResponse {
	resp := &GroupResponse{
		ID:                 g.ID,
		OwnerID:            g.OwnerID,
		Name:               g.Name,
		Description:        g.Description,
		PhotoURL:           g.PhotoURL,
		Visibility:         g.Visibility,
		MemberCount:        g.MemberCount,
		PendingCount:       g.PendingCount,
		MyMembershipStatus: g.MyMembershipStatus,
		MyRole:             g.MyRole,
		CreatedAt:          g.CreatedAt,
		UpdatedAt:          g.UpdatedAt,
	}
	if g.MyRole == string(domain.GroupRoleOwner) {
		resp.InviteCode = g.InviteCode
	}
	return resp
}

// GroupListResponseFromDomain converts a slice of domain groups to response DTOs.
func GroupListResponseFromDomain(groups []domain.Group) []GroupResponse {
	out := make([]GroupResponse, len(groups))
	for i := range groups {
		out[i] = *GroupResponseFromDomain(&groups[i])
	}
	return out
}

// GroupMemberResponse is the API response for a group membership.
type GroupMemberResponse struct {
	UserID   string                   `json:"user_id"`
	Role     domain.GroupMemberRole   `json:"role"`
	Status   domain.GroupMemberStatus `json:"status"`
	JoinedAt time.Time                `json:"joined_at"`
}

// GroupMemberResponseFromDomain builds a GroupMemberResponse from a domain GroupMember.
func GroupMemberResponseFromDomain(m *domain.GroupMember) *GroupMemberResponse {
	return &GroupMemberResponse{
		UserID:   m.UserID,
		Role:     m.Role,
		Status:   m.Status,
		JoinedAt: m.JoinedAt,
	}
}

// GroupMemberListResponseFromDomain converts a slice of domain members to response DTOs.
func GroupMemberListResponseFromDomain(members []domain.GroupMember) []GroupMemberResponse {
	out := make([]GroupMemberResponse, len(members))
	for i := range members {
		out[i] = *GroupMemberResponseFromDomain(&members[i])
	}
	return out
}
