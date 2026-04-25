package pagination

import (
	"encoding/base64"
	"net/http"
	"strconv"
)

const (
	defaultLimit = 20
	maxLimit     = 100
)

// ParseCursor extracts cursor and limit from query parameters.
// Default limit is 20, max is 100.
func ParseCursor(r *http.Request) (cursor string, limit int) {
	cursor = r.URL.Query().Get("cursor")
	if cursor != "" {
		decoded, err := DecodeCursor(cursor)
		if err == nil {
			cursor = decoded
		}
	}

	limit = defaultLimit
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	if limit > maxLimit {
		limit = maxLimit
	}

	return cursor, limit
}

// EncodeCursor encodes an ID as a base64 cursor string.
func EncodeCursor(id string) string {
	if id == "" {
		return ""
	}
	return base64.URLEncoding.EncodeToString([]byte(id))
}

// DecodeCursor decodes a base64 cursor string back to an ID.
func DecodeCursor(cursor string) (string, error) {
	b, err := base64.URLEncoding.DecodeString(cursor)
	if err != nil {
		return "", err
	}
	return string(b), nil
}
