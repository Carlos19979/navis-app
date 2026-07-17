package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// CreateBookingRequest is the payload to reserve boat time.
type CreateBookingRequest struct {
	StartsAt string  `json:"starts_at" validate:"required"`
	EndsAt   string  `json:"ends_at" validate:"required"`
	Purpose  *string `json:"purpose"`
	// Force creates the booking even when it overlaps an existing one
	// (the client confirmed the 409 BOOKING_OVERLAP warning).
	Force bool `json:"force"`
}

// BookingResponse mirrors a domain.Booking.
type BookingResponse struct {
	ID       string  `json:"id"`
	BoatID   string  `json:"boat_id"`
	UserID   string  `json:"user_id"`
	StartsAt string  `json:"starts_at"`
	EndsAt   string  `json:"ends_at"`
	Purpose  *string `json:"purpose"`
	Status   string  `json:"status"`
}

// BookingResponseFromDomain converts a booking.
func BookingResponseFromDomain(b *domain.Booking) BookingResponse {
	return BookingResponse{
		ID:       b.ID,
		BoatID:   b.BoatID,
		UserID:   b.UserID,
		StartsAt: b.StartsAt.Format(time.RFC3339),
		EndsAt:   b.EndsAt.Format(time.RFC3339),
		Purpose:  b.Purpose,
		Status:   string(b.Status),
	}
}

// BookingListFromDomain converts a slice of bookings.
func BookingListFromDomain(bs []domain.Booking) []BookingResponse {
	out := make([]BookingResponse, len(bs))
	for i := range bs {
		out[i] = BookingResponseFromDomain(&bs[i])
	}
	return out
}

// SplitInput is one person's share in a set-splits request.
type SplitInput struct {
	UserID      string  `json:"user_id" validate:"required"`
	ShareAmount float64 `json:"share_amount" validate:"required"`
}

// SetSplitsRequest replaces all splits for an expense.
type SetSplitsRequest struct {
	Splits []SplitInput `json:"splits" validate:"required,dive"`
}

// SettleSplitRequest toggles a split's settled state.
type SettleSplitRequest struct {
	Settled bool `json:"settled"`
}

// ExpenseSplitResponse mirrors a domain.ExpenseSplit.
type ExpenseSplitResponse struct {
	ID          string  `json:"id"`
	ExpenseID   string  `json:"expense_id"`
	UserID      string  `json:"user_id"`
	ShareAmount float64 `json:"share_amount"`
	Settled     bool    `json:"settled"`
}

// ExpenseSplitSummaryResponse mirrors a domain.ExpenseSplitSummary.
type ExpenseSplitSummaryResponse struct {
	ExpenseID string   `json:"expense_id"`
	Count     int      `json:"count"`
	MyShare   *float64 `json:"my_share"`
	MySettled bool     `json:"my_settled"`
}

// ExpenseSplitSummaryListFromDomain converts a slice of summaries.
func ExpenseSplitSummaryListFromDomain(ss []domain.ExpenseSplitSummary) []ExpenseSplitSummaryResponse {
	out := make([]ExpenseSplitSummaryResponse, len(ss))
	for i, s := range ss {
		out[i] = ExpenseSplitSummaryResponse{
			ExpenseID: s.ExpenseID,
			Count:     s.Count,
			MyShare:   s.MyShare,
			MySettled: s.MySettled,
		}
	}
	return out
}

// ExpenseSplitListFromDomain converts a slice of splits.
func ExpenseSplitListFromDomain(ss []domain.ExpenseSplit) []ExpenseSplitResponse {
	out := make([]ExpenseSplitResponse, len(ss))
	for i, s := range ss {
		out[i] = ExpenseSplitResponse{
			ID:          s.ID,
			ExpenseID:   s.ExpenseID,
			UserID:      s.UserID,
			ShareAmount: s.ShareAmount,
			Settled:     s.SettledAt != nil,
		}
	}
	return out
}
