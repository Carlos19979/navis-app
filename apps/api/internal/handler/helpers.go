package handler

import (
	"encoding/json"
	"net/http"

	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
)

// requireUserID extracts the authenticated user from the request context,
// writing a 401 response when absent. Callers must return when ok is false.
func requireUserID(w http.ResponseWriter, r *http.Request) (string, bool) {
	uid, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
	}
	return uid, ok
}

// decodeAndValidate decodes the JSON body into T, trims string fields, and
// runs struct validation, writing the error response on failure. Callers must
// return when ok is false.
func decodeAndValidate[T any](w http.ResponseWriter, r *http.Request) (T, bool) {
	var req T
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return req, false
	}

	validator.TrimStrings(&req)

	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
		return req, false
	}
	return req, true
}

// metaFromCursor builds pagination metadata from a repo's next cursor. Repos
// return opaque keyset cursors, so no further encoding happens here.
func metaFromCursor(next string) *Meta {
	if next == "" {
		return nil
	}
	return &Meta{NextCursor: &next}
}
