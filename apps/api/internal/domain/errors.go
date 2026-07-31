package domain

import (
	"errors"
	"fmt"
)

// Sentinel errors for the domain layer.
var (
	ErrNotFound              = errors.New("not found")
	ErrBoatNotFound          = errors.New("boat not found")
	ErrDocumentNotFound      = errors.New("document not found")
	ErrTripNotFound          = errors.New("trip not found")
	ErrEventNotFound         = errors.New("event not found")
	ErrPortNotFound          = errors.New("port not found")
	ErrGroupNotFound         = errors.New("group not found")
	ErrMembershipNotFound    = errors.New("membership not found")
	ErrInvalidInviteCode     = errors.New("invalid invite code")
	ErrUnauthorized          = errors.New("unauthorized")
	ErrForbidden             = errors.New("forbidden")
	ErrValidation            = errors.New("validation error")
	ErrDuplicateRegistration = errors.New("duplicate registration")
	ErrConflict              = errors.New("conflict")
	// ErrBookingOverlap is returned when a new booking overlaps an existing
	// one for the same boat and the client did not ask to force it.
	ErrBookingOverlap = errors.New("booking overlaps an existing one")
	// ErrPlanLimit is returned when an action exceeds the user's plan quota
	// (e.g. creating more boats than the plan allows).
	ErrPlanLimit = errors.New("plan limit reached")
	// ErrPlanForbidden is returned when the user's plan does not allow an
	// action at all (e.g. a normal user creating a group).
	ErrPlanForbidden = errors.New("not allowed on current plan")
	// ErrSelfBlock is returned when a user tries to block themselves.
	ErrSelfBlock = errors.New("cannot block yourself")
	// ErrObjectionableContent is returned when user-generated text fails the
	// moderation content filter (App Store guideline 1.2).
	ErrObjectionableContent = errors.New("content contains objectionable language")
	// ErrNotificationMuted is returned instead of delivering a notification the
	// user opted out of. It is NOT a failure, but it must not read as success
	// either: callers that record dedup state (the crons) have to leave the
	// reminder pending, so that unmuting still delivers it.
	ErrNotificationMuted = errors.New("notification category muted by user")
)

// ValidationError represents a field-level validation failure.
type ValidationError struct {
	Field   string
	Message string
}

// Error implements the error interface.
func (e *ValidationError) Error() string {
	return fmt.Sprintf("validation error: field %q — %s", e.Field, e.Message)
}

// Unwrap allows errors.Is to match against ErrValidation.
func (e *ValidationError) Unwrap() error {
	return ErrValidation
}
