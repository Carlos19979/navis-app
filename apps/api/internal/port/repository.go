package port

import (
	"context"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// BoatRepository defines persistence operations for boats.
type BoatRepository interface {
	Create(ctx context.Context, boat *domain.Boat) (*domain.Boat, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Boat, error)
	List(ctx context.Context, userID, cursor string, limit int) ([]domain.Boat, string, error)
	Update(ctx context.Context, userID string, boat *domain.Boat) (*domain.Boat, error)
	Delete(ctx context.Context, userID, id string) error
}

// DocumentRepository defines persistence operations for documents.
type DocumentRepository interface {
	Create(ctx context.Context, doc *domain.Document) (*domain.Document, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Document, error)
	List(ctx context.Context, userID, cursor string, limit int) ([]domain.Document, string, error)
	ListByBoat(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Document, string, error)
	ListExpiring(ctx context.Context, withinDays int) ([]domain.Document, error)
	Update(ctx context.Context, userID string, doc *domain.Document) (*domain.Document, error)
	Delete(ctx context.Context, userID, id string) error
}

// TripRepository defines persistence operations for trips.
type TripRepository interface {
	Create(ctx context.Context, trip *domain.Trip) (*domain.Trip, error)
	GetByID(ctx context.Context, userID, id string) (*domain.Trip, error)
	List(ctx context.Context, userID, boatID, cursor string, limit int) ([]domain.Trip, string, error)
	Update(ctx context.Context, userID string, trip *domain.Trip) (*domain.Trip, error)
	Delete(ctx context.Context, userID, id string) error
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
}

// EventInterestRepository tracks user interest (bookmarks) in events.
type EventInterestRepository interface {
	Toggle(ctx context.Context, userID, eventID string) (bool, error)
	IsInterested(ctx context.Context, userID, eventID string) (bool, error)
}

// NotificationLogRepository tracks sent document-expiry notifications to avoid duplicates.
type NotificationLogRepository interface {
	Exists(ctx context.Context, userID, documentID string, daysBefore int) (bool, error)
	Create(ctx context.Context, userID, documentID string, daysBefore int) error
}

// DeviceTokenRepository defines persistence operations for push notification device tokens.
type DeviceTokenRepository interface {
	Upsert(ctx context.Context, userID, token string, platform domain.Platform) error
	Delete(ctx context.Context, token string) error
	GetByUserID(ctx context.Context, userID string) ([]domain.DeviceToken, error)
}
