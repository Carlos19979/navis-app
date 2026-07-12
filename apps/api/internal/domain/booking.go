package domain

import "time"

// BookingStatus is the state of a boat-time reservation.
type BookingStatus string

// BookingStatus values.
const (
	BookingPending   BookingStatus = "pending"
	BookingConfirmed BookingStatus = "confirmed"
	BookingCancelled BookingStatus = "cancelled"
)

// Booking is a reservation of boat time by an owner or crew member.
type Booking struct {
	ID        string
	BoatID    string
	UserID    string
	StartsAt  time.Time
	EndsAt    time.Time
	Purpose   *string
	Status    BookingStatus
	CreatedAt time.Time
	UpdatedAt time.Time
}

// ExpenseSplit is one person's share of an expense.
type ExpenseSplit struct {
	ID          string
	ExpenseID   string
	UserID      string
	ShareAmount float64
	SettledAt   *time.Time
	CreatedAt   time.Time
}
