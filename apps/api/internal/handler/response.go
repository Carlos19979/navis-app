package handler

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
)

// APIResponse is the standard JSON envelope for all API responses.
type APIResponse struct {
	Data  any       `json:"data,omitempty"`
	Error *APIError `json:"error,omitempty"`
	Meta  *Meta     `json:"meta,omitempty"`
}

// APIError represents a structured error in the API response.
type APIError struct {
	Message string              `json:"message"`
	Code    string              `json:"code"`
	Details []validator.FieldError `json:"details,omitempty"`
}

// Meta holds pagination metadata.
type Meta struct {
	NextCursor *string `json:"next_cursor,omitempty"`
	Count      *int    `json:"count,omitempty"`
}

// JSON writes a success response with the given status code and data.
func JSON(w http.ResponseWriter, status int, data any) {
	writeJSON(w, status, APIResponse{Data: data})
}

// JSONWithMeta writes a success response with data and pagination metadata.
func JSONWithMeta(w http.ResponseWriter, status int, data any, meta *Meta) {
	writeJSON(w, status, APIResponse{Data: data, Meta: meta})
}

// Error writes an error response with the given status code, message, and error code.
func Error(w http.ResponseWriter, status int, message, code string) {
	writeJSON(w, status, APIResponse{
		Error: &APIError{
			Message: message,
			Code:    code,
		},
	})
}

// ValidationError writes a 422 response with field-level validation errors.
func ValidationError(w http.ResponseWriter, fieldErrors []validator.FieldError) {
	writeJSON(w, http.StatusUnprocessableEntity, APIResponse{
		Error: &APIError{
			Message: "validation failed",
			Code:    "VALIDATION_ERROR",
			Details: fieldErrors,
		},
	})
}

// MapDomainError maps domain errors to appropriate HTTP status codes and writes the response.
func MapDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, domain.ErrBoatNotFound),
		errors.Is(err, domain.ErrDocumentNotFound),
		errors.Is(err, domain.ErrTripNotFound),
		errors.Is(err, domain.ErrEventNotFound),
		errors.Is(err, domain.ErrNotFound):
		Error(w, http.StatusNotFound, err.Error(), "NOT_FOUND")

	case errors.Is(err, domain.ErrUnauthorized):
		Error(w, http.StatusUnauthorized, err.Error(), "UNAUTHORIZED")

	case errors.Is(err, domain.ErrForbidden):
		Error(w, http.StatusForbidden, err.Error(), "FORBIDDEN")

	case errors.Is(err, domain.ErrValidation):
		Error(w, http.StatusUnprocessableEntity, err.Error(), "VALIDATION_ERROR")

	case errors.Is(err, domain.ErrDuplicateRegistration):
		Error(w, http.StatusConflict, err.Error(), "DUPLICATE")

	case errors.Is(err, domain.ErrConflict):
		Error(w, http.StatusConflict, err.Error(), "CONFLICT")

	default:
		slog.Error("unhandled error", slog.String("error", err.Error()))
		Error(w, http.StatusInternalServerError, "internal server error", "INTERNAL_ERROR")
	}
}

// writeJSON marshals the response and writes it to the response writer.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("failed to encode JSON response", slog.String("error", err.Error()))
	}
}
