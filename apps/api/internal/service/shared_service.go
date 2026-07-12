package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// SharedService handles shared-boat coordination: bookings and expense
// splitting. All operations require the Pro plan (CanUseSharedCoordination).
type SharedService struct {
	bookings port.BookingRepository
	splits   port.ExpenseSplitRepository
	expenses port.ExpenseRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
}

// NewSharedService creates a new SharedService.
func NewSharedService(
	bookings port.BookingRepository,
	splits port.ExpenseSplitRepository,
	expenses port.ExpenseRepository,
	boats port.BoatRepository,
	profiles port.ProfileRepository,
) *SharedService {
	return &SharedService{bookings: bookings, splits: splits, expenses: expenses, boats: boats, profiles: profiles}
}

// assertPro verifies the user's plan unlocks shared coordination.
func (s *SharedService) assertPro(ctx context.Context, userID string) error {
	if s.profiles == nil {
		return nil
	}
	profile, err := s.profiles.GetOrCreate(ctx, userID)
	if err != nil {
		return err
	}
	if !profile.Plan.CanUseSharedCoordination() {
		return domain.ErrPlanForbidden
	}
	return nil
}

// assertAccess verifies the user owns or is a member of the boat.
func (s *SharedService) assertAccess(ctx context.Context, userID, boatID string) error {
	_, err := s.boats.GetByIDAccessible(ctx, userID, boatID)
	return err
}

// ─── Bookings ───────────────────────────────────────────────────────────────

// ListBookings returns a boat's bookings (any member; Pro).
func (s *SharedService) ListBookings(ctx context.Context, userID, boatID string) ([]domain.Booking, error) {
	if err := s.assertPro(ctx, userID); err != nil {
		return nil, fmt.Errorf("list bookings: %w", err)
	}
	if err := s.assertAccess(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("list bookings: %w", err)
	}
	return s.bookings.ListByBoat(ctx, boatID)
}

// CreateBooking reserves boat time (any member; Pro).
func (s *SharedService) CreateBooking(ctx context.Context, b *domain.Booking) (*domain.Booking, error) {
	if err := s.assertPro(ctx, b.UserID); err != nil {
		return nil, fmt.Errorf("create booking: %w", err)
	}
	if err := s.assertAccess(ctx, b.UserID, b.BoatID); err != nil {
		return nil, fmt.Errorf("create booking: %w", err)
	}
	if !b.EndsAt.After(b.StartsAt) {
		return nil, &domain.ValidationError{Field: "ends_at", Message: "ends_at must be after starts_at"}
	}
	if b.Status == "" {
		b.Status = domain.BookingConfirmed
	}
	return s.bookings.Create(ctx, b)
}

// DeleteBooking removes a booking (owner of the row; Pro).
func (s *SharedService) DeleteBooking(ctx context.Context, userID, boatID, id string) error {
	if err := s.assertPro(ctx, userID); err != nil {
		return fmt.Errorf("delete booking: %w", err)
	}
	if err := s.assertAccess(ctx, userID, boatID); err != nil {
		return fmt.Errorf("delete booking: %w", err)
	}
	return s.bookings.Delete(ctx, boatID, id)
}

// ─── Expense splits ───────────────────────────────────────────────────────────

// SetSplits replaces the splits for an expense (requires manage-expenses; Pro).
func (s *SharedService) SetSplits(ctx context.Context, userID, boatID, expenseID string, splits []domain.ExpenseSplit) ([]domain.ExpenseSplit, error) {
	if err := s.assertPro(ctx, userID); err != nil {
		return nil, fmt.Errorf("set splits: %w", err)
	}
	perms, ok, err := s.boats.GetPermissions(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("set splits: %w", err)
	}
	if !ok || !perms.CanManageExpenses {
		return nil, fmt.Errorf("set splits: %w", domain.ErrForbidden)
	}
	// Verify the expense belongs to this boat.
	if _, err := s.expenses.GetByID(ctx, boatID, expenseID); err != nil {
		return nil, fmt.Errorf("set splits: %w", err)
	}
	if err := s.splits.ReplaceForExpense(ctx, expenseID, splits); err != nil {
		return nil, fmt.Errorf("set splits: %w", err)
	}
	return s.splits.ListByExpense(ctx, expenseID)
}

// ListSplits returns the splits for an expense (any member; Pro).
func (s *SharedService) ListSplits(ctx context.Context, userID, boatID, expenseID string) ([]domain.ExpenseSplit, error) {
	if err := s.assertPro(ctx, userID); err != nil {
		return nil, fmt.Errorf("list splits: %w", err)
	}
	if err := s.assertAccess(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("list splits: %w", err)
	}
	if _, err := s.expenses.GetByID(ctx, boatID, expenseID); err != nil {
		return nil, fmt.Errorf("list splits: %w", err)
	}
	return s.splits.ListByExpense(ctx, expenseID)
}

// SettleSplit toggles a split's settled state (requires manage-expenses; Pro).
func (s *SharedService) SettleSplit(ctx context.Context, userID, boatID, splitID string, settled bool) error {
	if err := s.assertPro(ctx, userID); err != nil {
		return fmt.Errorf("settle split: %w", err)
	}
	perms, ok, err := s.boats.GetPermissions(ctx, userID, boatID)
	if err != nil {
		return fmt.Errorf("settle split: %w", err)
	}
	if !ok || !perms.CanManageExpenses {
		return fmt.Errorf("settle split: %w", domain.ErrForbidden)
	}
	return s.splits.SetSettled(ctx, splitID, settled)
}
