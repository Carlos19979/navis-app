package handler

import (
	"context"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// sharedService is the service surface the shared-coordination handlers consume.
type sharedService interface {
	ListBookings(ctx context.Context, userID, boatID string) ([]domain.Booking, error)
	CreateBooking(ctx context.Context, b *domain.Booking) (*domain.Booking, error)
	DeleteBooking(ctx context.Context, userID, boatID, id string) error
	ListSplits(ctx context.Context, userID, boatID, expenseID string) ([]domain.ExpenseSplit, error)
	SetSplits(ctx context.Context, userID, boatID, expenseID string, splits []domain.ExpenseSplit) ([]domain.ExpenseSplit, error)
	SettleSplit(ctx context.Context, userID, boatID, splitID string, settled bool) error
	ListSplitSummary(ctx context.Context, userID, boatID string) ([]domain.ExpenseSplitSummary, error)
}

// SharedHandler handles bookings and expense-splitting endpoints.
type SharedHandler struct {
	svc sharedService
}

// NewSharedHandler creates a new SharedHandler.
func NewSharedHandler(svc sharedService) *SharedHandler {
	return &SharedHandler{svc: svc}
}

// ListBookings handles GET /boats/{id}/bookings.
func (h *SharedHandler) ListBookings(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	bookings, err := h.svc.ListBookings(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.BookingListFromDomain(bookings))
}

// CreateBooking handles POST /boats/{id}/bookings.
func (h *SharedHandler) CreateBooking(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.CreateBookingRequest](w, r)
	if !ok {
		return
	}
	startsAt, err := time.Parse(time.RFC3339, req.StartsAt)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid starts_at", "BAD_REQUEST")
		return
	}
	endsAt, err := time.Parse(time.RFC3339, req.EndsAt)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid ends_at", "BAD_REQUEST")
		return
	}
	created, err := h.svc.CreateBooking(r.Context(), &domain.Booking{
		BoatID:   chi.URLParam(r, "id"),
		UserID:   userID,
		StartsAt: startsAt,
		EndsAt:   endsAt,
		Purpose:  req.Purpose,
	})
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusCreated, dto.BookingResponseFromDomain(created))
}

// DeleteBooking handles DELETE /boats/{id}/bookings/{bookingId}.
func (h *SharedHandler) DeleteBooking(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	err := h.svc.DeleteBooking(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "bookingId"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ListSplits handles GET /boats/{id}/expenses/{expenseId}/splits.
func (h *SharedHandler) ListSplits(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	splits, err := h.svc.ListSplits(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "expenseId"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.ExpenseSplitListFromDomain(splits))
}

// SetSplits handles PUT /boats/{id}/expenses/{expenseId}/splits.
func (h *SharedHandler) SetSplits(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.SetSplitsRequest](w, r)
	if !ok {
		return
	}
	splits := make([]domain.ExpenseSplit, len(req.Splits))
	for i, s := range req.Splits {
		splits[i] = domain.ExpenseSplit{UserID: s.UserID, ShareAmount: s.ShareAmount}
	}
	out, err := h.svc.SetSplits(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "expenseId"), splits)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.ExpenseSplitListFromDomain(out))
}

// ListSplitSummary handles GET /boats/{id}/expense-splits-summary.
func (h *SharedHandler) ListSplitSummary(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	summary, err := h.svc.ListSplitSummary(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.ExpenseSplitSummaryListFromDomain(summary))
}

// SettleSplit handles PUT /boats/{id}/expenses/{expenseId}/splits/{splitId}/settle.
func (h *SharedHandler) SettleSplit(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	req, ok := decodeAndValidate[dto.SettleSplitRequest](w, r)
	if !ok {
		return
	}
	err := h.svc.SettleSplit(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "splitId"), req.Settled)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
