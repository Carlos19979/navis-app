package port

import (
	"context"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// BoatRepository defines persistence operations for boats.
type BoatRepository interface {
	Create(ctx context.Context, boat *domain.Boat) (*domain.Boat, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Boat, error)
	List(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error)
	Count(ctx context.Context, userID string) (int, error)
	Update(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error)
	Delete(ctx context.Context, userID, id string) error
	// Shared access (crew / co-owners).
	GetByIDAccessible(ctx context.Context, userID, id string) (*domain.Boat, error)
	HasAccess(ctx context.Context, userID, boatID string) (bool, error)
	// GetPermissions resolves a user's permissions for a boat; access=false if none.
	GetPermissions(ctx context.Context, userID, boatID string) (domain.BoatPermissions, bool, error)
	SetPermissions(ctx context.Context, ownerID, boatID, memberUserID string, p domain.BoatPermissions) error
	ListShared(ctx context.Context, userID string) ([]domain.Boat, error)
	EnsureShareCode(ctx context.Context, userID, boatID, candidate string) (string, error)
	GetIDByShareCode(ctx context.Context, code string) (boatID, ownerID string, err error)
	AddMember(ctx context.Context, boatID, userID, role string) error
	ListMembers(ctx context.Context, boatID string) ([]domain.BoatMember, error)
	RemoveMember(ctx context.Context, ownerID, boatID, memberUserID string) error
	Leave(ctx context.Context, userID, boatID string) error
}

// ProfileRepository persists per-user account data (subscription plan).
type ProfileRepository interface {
	// GetOrCreate returns the user's profile, creating a default one if absent.
	GetOrCreate(ctx context.Context, userID string) (*domain.Profile, error)
	SetPlan(ctx context.Context, userID string, plan domain.Plan) (*domain.Profile, error)
}

// MaintenanceRepository persists boat maintenance/service logs.
type MaintenanceRepository interface {
	Create(ctx context.Context, log *domain.MaintenanceLog) (*domain.MaintenanceLog, error)
	Update(ctx context.Context, log *domain.MaintenanceLog) (*domain.MaintenanceLog, error)
	// ListByBoat returns all logs on a boat (caller enforces access).
	ListByBoat(ctx context.Context, boatID string) ([]domain.MaintenanceLog, error)
	Delete(ctx context.Context, boatID, id string) error
}

// ExpenseRepository persists boat expenses.
type ExpenseRepository interface {
	Create(ctx context.Context, e *domain.Expense) (*domain.Expense, error)
	Update(ctx context.Context, e *domain.Expense) (*domain.Expense, error)
	// ListByBoat returns all expenses on a boat (caller enforces access).
	ListByBoat(ctx context.Context, boatID string) ([]domain.Expense, error)
	Delete(ctx context.Context, boatID, id string) error
	// TotalsByCategory returns summed amounts per category for a boat.
	TotalsByCategory(ctx context.Context, boatID string) (map[string]float64, error)
}

// DocumentRepository defines persistence operations for documents.
type DocumentRepository interface {
	Create(ctx context.Context, doc *domain.Document) (*domain.Document, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Document, error)
	GetByIDUnscoped(ctx context.Context, id string) (*domain.Document, error)
	List(ctx context.Context, userID, cursor string, limit int) ([]domain.Document, string, error)
	ListByBoat(ctx context.Context, boatID, cursor string, limit int) ([]domain.Document, string, error)
	ListExpiring(ctx context.Context, withinDays int) ([]domain.Document, error)
	Update(ctx context.Context, doc *domain.Document) (*domain.Document, error)
	Delete(ctx context.Context, boatID, id string) error
}

// TripRepository defines persistence operations for trips.
type TripRepository interface {
	Create(ctx context.Context, trip *domain.Trip) (*domain.Trip, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Trip, error)
	GetByIDUnscoped(ctx context.Context, id string) (*domain.Trip, error)
	List(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Trip, string, error)
	ListByBoatAll(ctx context.Context, boatID, cursor string, limit int) ([]domain.Trip, string, error)
	ListByGroup(ctx context.Context, groupID, cursor string, limit int) ([]domain.Trip, string, error)
	// ListUpcomingRegattas returns planned group regattas scheduled in [from, to).
	ListUpcomingRegattas(ctx context.Context, from, to time.Time) ([]domain.Trip, error)
	Update(ctx context.Context, userID string, trip *domain.Trip) (*domain.Trip, error)
	Delete(ctx context.Context, userID, id string) error
	// SetShareToken / ClearShareToken manage a trip's public share link.
	SetShareToken(ctx context.Context, userID, tripID, token string) error
	ClearShareToken(ctx context.Context, userID, tripID string) error
	// GetByShareToken returns a trip by its public token (no user scoping).
	GetByShareToken(ctx context.Context, token string) (*domain.Trip, error)
}

// TripParticipantRepository tracks RSVP answers to planned group trips/regattas.
type TripParticipantRepository interface {
	SetRSVP(ctx context.Context, tripID, userID string, rsvp domain.RSVP) error
	Remove(ctx context.Context, tripID, userID string) error
	ListByTrip(ctx context.Context, tripID string) ([]domain.TripParticipant, error)
}

// TripChecklistRepository manages a trip's pre-departure safety checklist.
type TripChecklistRepository interface {
	CopyDefaults(ctx context.Context, tripID string) error
	Count(ctx context.Context, tripID string) (int, error)
	ListByTrip(ctx context.Context, tripID string) ([]domain.ChecklistItem, error)
	AddItem(ctx context.Context, tripID, label string, position int) (*domain.ChecklistItem, error)
	SetChecked(ctx context.Context, tripID, itemID string, checked bool) (*domain.ChecklistItem, error)
	RemoveItem(ctx context.Context, tripID, itemID string) error
}

// TripTrackRepository defines persistence operations for trip GPS track points.
type TripTrackRepository interface {
	BatchCreate(ctx context.Context, tracks []domain.TripTrack) error
	ListByTrip(ctx context.Context, tripID string) ([]domain.TripTrack, error)
}

// NauticalPortRepository defines persistence operations for ports.
type NauticalPortRepository interface {
	GetByID(ctx context.Context, id string) (*domain.Port, error)
	NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Port, string, error)
}

// EventRepository defines persistence operations for events.
type EventRepository interface {
	GetByID(ctx context.Context, id string) (*domain.Event, error)
	List(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error)
	ListUpcoming(ctx context.Context, cursor string, limit int) ([]domain.Event, string, error)
	NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Event, string, error)
	// ListStartingBetween returns events whose start_date is in [from, to).
	ListStartingBetween(ctx context.Context, from, to time.Time) ([]domain.Event, error)
}

// EventInterestRepository tracks user interest (bookmarks) in events.
type EventInterestRepository interface {
	Toggle(ctx context.Context, userID, eventID string) (bool, error)
	IsInterested(ctx context.Context, userID, eventID string) (bool, error)
	// ListInterestedUsers returns the user IDs interested in an event.
	ListInterestedUsers(ctx context.Context, eventID string) ([]string, error)
	// InterestedIn returns, for the given user, which of eventIDs they like.
	InterestedIn(ctx context.Context, userID string, eventIDs []string) (map[string]bool, error)
}

// UserRepository resolves user profile data (e.g. display names) for
// notification messages. Backed by Supabase auth.users metadata.
type UserRepository interface {
	DisplayName(ctx context.Context, userID string) (string, error)
}

// SentNotificationRepository is a generic dedup log for scheduled notifications.
type SentNotificationRepository interface {
	Exists(ctx context.Context, userID, kind, refID, dedupKey string) (bool, error)
	Record(ctx context.Context, userID, kind, refID, dedupKey string) error
}

// GroupRepository defines persistence operations for groups (clubs/crews).
type GroupRepository interface {
	Create(ctx context.Context, group *domain.Group) (*domain.Group, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Group, error)
	GetByInviteCode(ctx context.Context, userID, code string) (*domain.Group, error)
	List(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error)
	ListPublic(ctx context.Context, userID, cursor string, limit int) ([]domain.Group, string, error)
	Update(ctx context.Context, userID string, group *domain.Group) (*domain.Group, error)
	Delete(ctx context.Context, userID, id string) error
}

// GroupMemberRepository defines persistence operations for group membership.
type GroupMemberRepository interface {
	Add(ctx context.Context, groupID, userID string, role domain.GroupMemberRole, status domain.GroupMemberStatus) error
	Get(ctx context.Context, groupID, userID string) (*domain.GroupMember, error)
	SetStatus(ctx context.Context, groupID, userID string, status domain.GroupMemberStatus) error
	Remove(ctx context.Context, groupID, userID string) error
	ListMembers(ctx context.Context, groupID string) ([]domain.GroupMember, error)
	ListPending(ctx context.Context, groupID string) ([]domain.GroupMember, error)
}

// NotificationLogRepository tracks sent document-expiry notifications to avoid duplicates.
type NotificationLogRepository interface {
	Exists(ctx context.Context, userID, documentID string, daysBefore int) (bool, error)
	Create(ctx context.Context, userID, documentID string, daysBefore int) error
}

// DeviceTokenRepository defines persistence operations for push notification device tokens.
type DeviceTokenRepository interface {
	Upsert(ctx context.Context, userID, token string, platform domain.Platform) error
	// Delete removes a token owned by userID (scoped to prevent IDOR).
	Delete(ctx context.Context, userID, token string) error
	GetByUserID(ctx context.Context, userID string) ([]domain.DeviceToken, error)
}
