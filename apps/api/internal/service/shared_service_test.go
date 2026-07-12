package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

type mockBookingRepo struct {
	created *domain.Booking
}

func (m *mockBookingRepo) Create(_ context.Context, b *domain.Booking) (*domain.Booking, error) {
	b.ID = "booking-1"
	m.created = b
	return b, nil
}
func (m *mockBookingRepo) ListByBoat(_ context.Context, _ string) ([]domain.Booking, error) {
	return nil, nil
}
func (m *mockBookingRepo) Delete(_ context.Context, _, _ string) error { return nil }

type mockSplitRepo struct{}

func (m *mockSplitRepo) ReplaceForExpense(_ context.Context, _ string, _ []domain.ExpenseSplit) error {
	return nil
}
func (m *mockSplitRepo) ListByExpense(_ context.Context, _ string) ([]domain.ExpenseSplit, error) {
	return nil, nil
}
func (m *mockSplitRepo) SetSettled(_ context.Context, _ string, _ bool) error { return nil }
func (m *mockSplitRepo) SummaryByBoat(_ context.Context, _, _ string) ([]domain.ExpenseSplitSummary, error) {
	return nil, nil
}

func TestSharedService_CreateBooking_ForbiddenOnFree(t *testing.T) {
	t.Parallel()
	svc := NewSharedService(&mockBookingRepo{}, &mockSplitRepo{}, &mockExpenseRepo{},
		&mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanFree}, nil)

	_, err := svc.CreateBooking(context.Background(), &domain.Booking{
		BoatID: "boat-1", UserID: "user-1",
		StartsAt: time.Now(), EndsAt: time.Now().Add(time.Hour),
	})
	if !errors.Is(err, domain.ErrPlanForbidden) {
		t.Errorf("err = %v, want ErrPlanForbidden", err)
	}
}

func TestSharedService_CreateBooking_Pro(t *testing.T) {
	t.Parallel()
	repo := &mockBookingRepo{}
	svc := NewSharedService(repo, &mockSplitRepo{}, &mockExpenseRepo{},
		&mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro}, nil)

	out, err := svc.CreateBooking(context.Background(), &domain.Booking{
		BoatID: "boat-1", UserID: "user-1",
		StartsAt: time.Now(), EndsAt: time.Now().Add(time.Hour),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Status != domain.BookingConfirmed {
		t.Errorf("status = %q, want confirmed (default)", out.Status)
	}
}

func TestSharedService_CreateBooking_RejectsBadTimes(t *testing.T) {
	t.Parallel()
	svc := NewSharedService(&mockBookingRepo{}, &mockSplitRepo{}, &mockExpenseRepo{},
		&mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro}, nil)

	_, err := svc.CreateBooking(context.Background(), &domain.Booking{
		BoatID: "boat-1", UserID: "user-1",
		StartsAt: time.Now(), EndsAt: time.Now().Add(-time.Hour), // ends before start
	})
	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Errorf("err = %v, want ValidationError", err)
	}
}

func TestSharedService_SetSplits_RequiresManageExpenses(t *testing.T) {
	t.Parallel()
	boats := &mockBoatRepo{
		getPermissionsFn: func(_ context.Context, _, _ string) (domain.BoatPermissions, bool, error) {
			return domain.BoatPermissions{CanManageExpenses: false}, true, nil
		},
	}
	svc := NewSharedService(&mockBookingRepo{}, &mockSplitRepo{}, &mockExpenseRepo{},
		boats, &testutil.FakeProfileRepo{Plan: domain.PlanPro}, nil)

	_, err := svc.SetSplits(context.Background(), "user-1", "boat-1", "exp-1", nil)
	if !errors.Is(err, domain.ErrForbidden) {
		t.Errorf("err = %v, want ErrForbidden", err)
	}
}
