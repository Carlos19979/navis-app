package service

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// exportPageSize is the page size used when draining paginated listings for
// the GDPR export. Every listing is followed until its cursor is exhausted —
// no silent caps.
const exportPageSize = 200

// storageBuckets are the buckets that hold user files under "<userID>/...".
var storageBuckets = []string{"boats", "documents"}

// UserService implements GDPR account deletion and data export.
type UserService struct {
	admin        port.SupabaseAdmin
	boats        port.BoatRepository
	docs         port.DocumentRepository
	trips        port.TripRepository
	tracks       port.TripTrackRepository
	participants port.TripParticipantRepository
	checklists   port.TripChecklistRepository
	maintenance  port.MaintenanceRepository
	expenses     port.ExpenseRepository
	groups       port.GroupRepository
	devices      port.DeviceTokenRepository
	profiles     port.ProfileRepository
	logger       *slog.Logger
}

// NewUserService creates a new UserService.
func NewUserService(
	admin port.SupabaseAdmin,
	boats port.BoatRepository,
	docs port.DocumentRepository,
	trips port.TripRepository,
	tracks port.TripTrackRepository,
	participants port.TripParticipantRepository,
	checklists port.TripChecklistRepository,
	maintenance port.MaintenanceRepository,
	expenses port.ExpenseRepository,
	groups port.GroupRepository,
	devices port.DeviceTokenRepository,
	profiles port.ProfileRepository,
	logger *slog.Logger,
) *UserService {
	return &UserService{
		admin:        admin,
		boats:        boats,
		docs:         docs,
		trips:        trips,
		tracks:       tracks,
		participants: participants,
		checklists:   checklists,
		maintenance:  maintenance,
		expenses:     expenses,
		groups:       groups,
		devices:      devices,
		profiles:     profiles,
		logger:       logger,
	}
}

// DeleteAccount permanently removes the user: Storage files first (their paths
// are derived from DB rows, but the "<userID>/" folder convention makes them
// discoverable without the rows), then the auth.users row, whose ON DELETE
// CASCADE foreign keys remove every app row atomically. After this the user
// cannot log in again.
func (s *UserService) DeleteAccount(ctx context.Context, userID string) error {
	for _, bucket := range storageBuckets {
		if err := s.admin.DeleteUserFiles(ctx, bucket, userID); err != nil {
			return fmt.Errorf("user_service.DeleteAccount: purge bucket %q: %w", bucket, err)
		}
	}

	if err := s.admin.DeleteAuthUser(ctx, userID); err != nil {
		return fmt.Errorf("user_service.DeleteAccount: %w", err)
	}

	s.logger.Info("account deleted", slog.String("user_id", userID))
	return nil
}

// ExportData assembles the user's complete data set for a GDPR export. Every
// paginated listing is drained to its last cursor.
func (s *UserService) ExportData(ctx context.Context, userID string) (map[string]any, error) {
	profile, err := s.profiles.GetOrCreate(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user_service.ExportData: profile: %w", err)
	}

	boats, err := s.allBoats(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user_service.ExportData: boats: %w", err)
	}

	sharedBoats, err := s.boats.ListShared(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user_service.ExportData: shared boats: %w", err)
	}

	docs, err := s.allDocuments(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user_service.ExportData: documents: %w", err)
	}

	trips, err := s.allTrips(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user_service.ExportData: trips: %w", err)
	}

	tracksByTrip := make(map[string][]domain.TripTrack)
	checklistsByTrip := make(map[string][]domain.ChecklistItem)
	participantsByTrip := make(map[string][]domain.TripParticipant)
	for _, trip := range trips {
		tracks, err := s.tracks.ListByTrip(ctx, trip.ID)
		if err != nil {
			return nil, fmt.Errorf("user_service.ExportData: tracks for trip %s: %w", trip.ID, err)
		}
		if len(tracks) > 0 {
			tracksByTrip[trip.ID] = tracks
		}

		items, err := s.checklists.ListByTrip(ctx, trip.ID)
		if err != nil {
			return nil, fmt.Errorf("user_service.ExportData: checklist for trip %s: %w", trip.ID, err)
		}
		if len(items) > 0 {
			checklistsByTrip[trip.ID] = items
		}

		parts, err := s.participants.ListByTrip(ctx, trip.ID)
		if err != nil {
			return nil, fmt.Errorf("user_service.ExportData: participants for trip %s: %w", trip.ID, err)
		}
		if len(parts) > 0 {
			participantsByTrip[trip.ID] = parts
		}
	}

	maintenanceByBoat := make(map[string][]domain.MaintenanceLog)
	expensesByBoat := make(map[string][]domain.Expense)
	membersByBoat := make(map[string][]domain.BoatMember)
	for _, boat := range boats {
		logs, err := s.maintenance.ListByBoat(ctx, boat.ID)
		if err != nil {
			return nil, fmt.Errorf("user_service.ExportData: maintenance for boat %s: %w", boat.ID, err)
		}
		if len(logs) > 0 {
			maintenanceByBoat[boat.ID] = logs
		}

		exps, err := s.expenses.ListByBoat(ctx, boat.ID)
		if err != nil {
			return nil, fmt.Errorf("user_service.ExportData: expenses for boat %s: %w", boat.ID, err)
		}
		if len(exps) > 0 {
			expensesByBoat[boat.ID] = exps
		}

		members, err := s.boats.ListMembers(ctx, boat.ID)
		if err != nil {
			return nil, fmt.Errorf("user_service.ExportData: members for boat %s: %w", boat.ID, err)
		}
		if len(members) > 0 {
			membersByBoat[boat.ID] = members
		}
	}

	groups, err := s.allGroups(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user_service.ExportData: groups: %w", err)
	}

	devices, err := s.devices.GetByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user_service.ExportData: devices: %w", err)
	}

	return map[string]any{
		"user_id":           userID,
		"profile":           profile,
		"boats":             boats,
		"shared_boats":      sharedBoats,
		"boat_members":      membersByBoat,
		"documents":         docs,
		"trips":             trips,
		"tracks":            tracksByTrip,
		"trip_checklists":   checklistsByTrip,
		"trip_participants": participantsByTrip,
		"maintenance_logs":  maintenanceByBoat,
		"expenses":          expensesByBoat,
		"groups":            groups,
		"devices":           devices,
	}, nil
}

func (s *UserService) allBoats(ctx context.Context, userID string) ([]domain.Boat, error) {
	var all []domain.Boat
	cursor := ""
	for {
		page, next, err := s.boats.List(ctx, userID, cursor, exportPageSize)
		if err != nil {
			return nil, err
		}
		all = append(all, page...)
		if next == "" {
			return all, nil
		}
		cursor = next
	}
}

func (s *UserService) allDocuments(ctx context.Context, userID string) ([]domain.Document, error) {
	var all []domain.Document
	cursor := ""
	for {
		page, next, err := s.docs.List(ctx, userID, cursor, exportPageSize)
		if err != nil {
			return nil, err
		}
		all = append(all, page...)
		if next == "" {
			return all, nil
		}
		cursor = next
	}
}

func (s *UserService) allTrips(ctx context.Context, userID string) ([]domain.Trip, error) {
	var all []domain.Trip
	cursor := ""
	for {
		page, next, err := s.trips.List(ctx, userID, "", cursor, exportPageSize)
		if err != nil {
			return nil, err
		}
		all = append(all, page...)
		if next == "" {
			return all, nil
		}
		cursor = next
	}
}

func (s *UserService) allGroups(ctx context.Context, userID string) ([]domain.Group, error) {
	var all []domain.Group
	cursor := ""
	for {
		page, next, err := s.groups.List(ctx, userID, cursor, exportPageSize)
		if err != nil {
			return nil, err
		}
		all = append(all, page...)
		if next == "" {
			return all, nil
		}
		cursor = next
	}
}
