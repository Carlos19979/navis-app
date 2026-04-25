package validator

import (
	"fmt"
	"strings"
	"sync"

	v10 "github.com/go-playground/validator/v10"
)

// FieldError represents a single field validation failure.
type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

var (
	validate *v10.Validate
	once     sync.Once
)

// instance returns the singleton validator, initializing it on first call.
func instance() *v10.Validate {
	once.Do(func() {
		validate = v10.New(v10.WithRequiredStructEnabled())
	})
	return validate
}

// Validate validates a struct and returns a slice of field errors.
// Returns nil if the struct is valid.
func Validate(s any) []FieldError {
	err := instance().Struct(s)
	if err == nil {
		return nil
	}

	var validationErrors v10.ValidationErrors
	if ok := errors_As(err, &validationErrors); !ok {
		return []FieldError{{Field: "unknown", Message: err.Error()}}
	}

	fieldErrors := make([]FieldError, 0, len(validationErrors))
	for _, fe := range validationErrors {
		fieldErrors = append(fieldErrors, FieldError{
			Field:   toSnakeCase(fe.Field()),
			Message: msgForTag(fe),
		})
	}

	return fieldErrors
}

// errors_As is a helper to avoid importing errors package just for As.
func errors_As(err error, target any) bool {
	// Use type assertion instead of errors.As to keep imports minimal.
	if ve, ok := err.(v10.ValidationErrors); ok {
		if t, ok2 := target.(*v10.ValidationErrors); ok2 {
			*t = ve
			return true
		}
	}
	return false
}

// msgForTag returns a human-readable message for a validation tag.
func msgForTag(fe v10.FieldError) string {
	switch fe.Tag() {
	case "required":
		return "this field is required"
	case "min":
		return fmt.Sprintf("must be at least %s characters", fe.Param())
	case "max":
		return fmt.Sprintf("must be at most %s characters", fe.Param())
	case "gt":
		return fmt.Sprintf("must be greater than %s", fe.Param())
	case "gte":
		return fmt.Sprintf("must be greater than or equal to %s", fe.Param())
	case "lte":
		return fmt.Sprintf("must be less than or equal to %s", fe.Param())
	case "oneof":
		return fmt.Sprintf("must be one of: %s", fe.Param())
	case "url":
		return "must be a valid URL"
	case "uuid":
		return "must be a valid UUID"
	case "latitude":
		return "must be a valid latitude (-90 to 90)"
	case "longitude":
		return "must be a valid longitude (-180 to 180)"
	case "required_if":
		return "this field is required"
	default:
		return fmt.Sprintf("failed validation: %s", fe.Tag())
	}
}

// toSnakeCase converts a PascalCase field name to snake_case.
func toSnakeCase(s string) string {
	var result strings.Builder
	for i, r := range s {
		if r >= 'A' && r <= 'Z' {
			if i > 0 {
				result.WriteByte('_')
			}
			result.WriteRune(r + 32) // lowercase
		} else {
			result.WriteRune(r)
		}
	}
	return result.String()
}
