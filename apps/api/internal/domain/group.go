package domain

import "time"

// GroupVisibility represents whether a group is publicly discoverable or private.
type GroupVisibility string

// GroupVisibility values.
const (
	GroupVisibilityPublic  GroupVisibility = "public"
	GroupVisibilityPrivate GroupVisibility = "private"
)

// GroupMemberRole represents a member's role within a group.
type GroupMemberRole string

// GroupMemberRole values.
const (
	GroupRoleOwner  GroupMemberRole = "owner"
	GroupRoleMember GroupMemberRole = "member"
)

// GroupMemberStatus represents whether a membership is pending approval or active.
type GroupMemberStatus string

// GroupMemberStatus values.
const (
	GroupMemberStatusPending GroupMemberStatus = "pending"
	GroupMemberStatusActive  GroupMemberStatus = "active"
)

// MembershipNone is the sentinel returned for a viewer who is not related to a group.
const MembershipNone = "none"

// Group represents a club or crew created by an owner (armador). Public groups are
// join-by-request (owner approval); private groups are joined with an invite code.
type Group struct {
	ID          string
	OwnerID     string
	Name        string
	Description *string
	PhotoURL    *string
	Visibility  GroupVisibility
	InviteCode  *string
	CreatedAt   time.Time
	UpdatedAt   time.Time

	// Derived fields populated by repository reads (not stored on the groups row).
	MemberCount        int
	PendingCount       int
	MyMembershipStatus string // "none" | "pending" | "active"
	MyRole             string // "" | "owner" | "member"
}

// GroupMember represents a user's membership in a group.
type GroupMember struct {
	GroupID  string
	UserID   string
	Role     GroupMemberRole
	Status   GroupMemberStatus
	JoinedAt time.Time
}
