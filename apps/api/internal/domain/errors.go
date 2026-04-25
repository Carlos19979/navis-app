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
	ErrUnauthorized          = errors.New("unauthorized")
	ErrForbidden             = errors.New("forbidden")
	ErrValidation            = errors.New("validation error")
	ErrDuplicateRegistration = errors.New("duplicate registration")
	ErrConflict              = errors.New("conflict")
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
