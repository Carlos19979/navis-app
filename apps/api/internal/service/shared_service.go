package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// SharedService handles shared-boat coordination. Expense splitting is available
// on all tiers (the viral hook: crews divide costs for free); bookings remain a
// Pro feature (CanUseSharedCoordination).
type SharedService struct {
	bookings port.BookingRepository
	splits   port.ExpenseSplitRepository
	expenses port.ExpenseRepository
	boats    port.BoatRepository
	profiles port.ProfileRepository
	notifier *Notifier
}

// NewSharedService creates a new SharedService.
func NewSharedService(
	bookings port.BookingRepository,
	splits port.ExpenseSplitRepository,
	expenses port.ExpenseRepository,
	boats port.BoatRepository,
	profiles port.ProfileRepository,
	notifier *Notifier,
) *SharedService {
	return &SharedService{bookings: bookings, splits: splits, expenses: expenses, boats: boats, profiles: profiles, notifier: notifier}
}

// assertPro verifies the user's plan unlocks Pro shared coordination (bookings).
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

// notifyBoatCrew notifies everyone with access to a boat (owner + members)
// except the acting user, about a shared-boat event. Best-effort.
func (s *SharedService) notifyBoatCrew(ctx context.Context, boatID, actorID, workflow, title, body string) {
	if s.notifier == nil {
		return
	}
	boat, err := s.boats.GetByIDAccessible(ctx, actorID, boatID)
	if err != nil {
		return
	}
	ids := []string{boat.UserID}
	if members, mErr := s.boats.ListMembers(ctx, boatID); mErr == nil {
		for i := range members {
			ids = append(ids, members[i].UserID)
		}
	}
	s.notifier.SendMany(ctx, ids, actorID, workflow, title, body, "boat", boatID)
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
func (s *SharedService) CreateBooking(ctx context.Context, b *domain.Booking, force bool) (*domain.Booking, error) {
	if err := s.assertPro(ctx, b.UserID); err != nil {
		return nil, fmt.Errorf("create booking: %w", err)
	}
	if err := s.assertAccess(ctx, b.UserID, b.BoatID); err != nil {
		return nil, fmt.Errorf("create booking: %w", err)
	}
	if !b.EndsAt.After(b.StartsAt) {
		return nil, &domain.ValidationError{Field: "ends_at", Message: "ends_at must be after starts_at"}
	}
	// Overlaps are advisory, not forbidden (a shared boat may want a joint
	// outing): without force the API rejects with 409 so the client can
	// confirm; with force the booking is created anyway. Checking here (not
	// in the client) closes the two-users-book-at-once race.
	if !force {
		clash, err := s.bookings.HasOverlap(ctx, b.BoatID, b.StartsAt, b.EndsAt)
		if err != nil {
			return nil, fmt.Errorf("create booking: %w", err)
		}
		if clash {
			return nil, domain.ErrBookingOverlap
		}
	}
	if b.Status == "" {
		b.Status = domain.BookingConfirmed
	}
	created, err := s.bookings.Create(ctx, b)
	if err != nil {
		return nil, err
	}
	// Notify the rest of the crew that the boat has been reserved.
	name := s.notifier.UserName(ctx, b.UserID)
	s.notifyBoatCrew(ctx, b.BoatID, b.UserID, WorkflowBookingCreated,
		"Reserva creada", fmt.Sprintf("%s ha reservado el barco", name))
	return created, nil
}

// DeleteBooking removes a booking (owner of the row; Pro).
func (s *SharedService) DeleteBooking(ctx context.Context, userID, boatID, id string) error {
	if err := s.assertPro(ctx, userID); err != nil {
		return fmt.Errorf("delete booking: %w", err)
	}
	if err := s.assertAccess(ctx, userID, boatID); err != nil {
		return fmt.Errorf("delete booking: %w", err)
	}
	if err := s.bookings.Delete(ctx, boatID, id); err != nil {
		return err
	}
	// Notify the rest of the crew that a reservation was cancelled.
	name := s.notifier.UserName(ctx, userID)
	s.notifyBoatCrew(ctx, boatID, userID, WorkflowBookingCancelled,
		"Reserva cancelada", fmt.Sprintf("%s ha cancelado una reserva", name))
	return nil
}

// ─── Expense splits ───────────────────────────────────────────────────────────

// SetSplits replaces the splits for an expense (requires manage-expenses; all
// tiers — expense splitting is the free viral hook, scoped by boat membership).
func (s *SharedService) SetSplits(ctx context.Context, userID, boatID, expenseID string, splits []domain.ExpenseSplit) ([]domain.ExpenseSplit, error) {
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
	// Notify each assigned member (except the person doing the split) that they
	// owe a share. Best-effort; members are Navis users with device tokens.
	if s.notifier != nil {
		for _, sp := range splits {
			if sp.UserID == userID || sp.ShareAmount <= 0 {
				continue
			}
			s.notifier.Send(ctx, sp.UserID, WorkflowExpenseSplit,
				"Gasto compartido",
				fmt.Sprintf("Te toca %.0f € de un gasto en tu barco", sp.ShareAmount),
				"boat", boatID)
		}
	}
	return s.splits.ListByExpense(ctx, expenseID)
}

// ListSplitSummary returns per-expense split rollups for a boat from the
// caller's perspective (their share + settled). Any member; all tiers.
func (s *SharedService) ListSplitSummary(ctx context.Context, userID, boatID string) ([]domain.ExpenseSplitSummary, error) {
	if err := s.assertAccess(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("split summary: %w", err)
	}
	return s.splits.SummaryByBoat(ctx, boatID, userID)
}

// ListSplits returns the splits for an expense (any member; all tiers).
func (s *SharedService) ListSplits(ctx context.Context, userID, boatID, expenseID string) ([]domain.ExpenseSplit, error) {
	if err := s.assertAccess(ctx, userID, boatID); err != nil {
		return nil, fmt.Errorf("list splits: %w", err)
	}
	if _, err := s.expenses.GetByID(ctx, boatID, expenseID); err != nil {
		return nil, fmt.Errorf("list splits: %w", err)
	}
	return s.splits.ListByExpense(ctx, expenseID)
}

// SettleSplit toggles a split's settled state (requires manage-expenses; all tiers).
func (s *SharedService) SettleSplit(ctx context.Context, userID, boatID, splitID string, settled bool) error {
	perms, ok, err := s.boats.GetPermissions(ctx, userID, boatID)
	if err != nil {
		return fmt.Errorf("settle split: %w", err)
	}
	if !ok || !perms.CanManageExpenses {
		return fmt.Errorf("settle split: %w", domain.ErrForbidden)
	}
	if err := s.splits.SetSettled(ctx, splitID, settled); err != nil {
		return err
	}
	// Tell the member their share was marked as paid (only on settle, not unsettle).
	if settled && s.notifier != nil {
		if sp, gErr := s.splits.GetByID(ctx, splitID); gErr == nil && sp.UserID != userID {
			s.notifier.Send(ctx, sp.UserID, WorkflowExpenseSettled,
				"Gasto saldado",
				"Tu parte de un gasto compartido se ha marcado como pagada",
				"boat", boatID)
		}
	}
	return nil
}
