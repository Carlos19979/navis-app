package pagination

import (
	"encoding/base64"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const (
	defaultLimit = 20
	// maxLimit caps page size API-wide. Handlers and services share this cap
	// (previously 50 in services vs 100 here — reconciled to 50).
	maxLimit = 50
)

// ParseCursor extracts the opaque cursor and a clamped limit from query
// parameters. The cursor is passed through verbatim — repositories decode it
// with DecodeKeysetTime/Text and treat undecodable (legacy or corrupt)
// cursors as "start from the first page".
func ParseCursor(r *http.Request) (cursor string, limit int) {
	cursor = r.URL.Query().Get("cursor")

	limit = defaultLimit
	if l := r.URL.Query().Get("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	return cursor, ClampLimit(limit)
}

// ClampLimit normalizes a page size into [1, maxLimit], defaulting when zero
// or negative.
func ClampLimit(limit int) int {
	if limit <= 0 {
		return defaultLimit
	}
	if limit > maxLimit {
		return maxLimit
	}
	return limit
}

// keysetSeparator joins the sort key and id inside a keyset cursor. IDs are
// UUIDs, so splitting at the LAST separator is unambiguous even when the sort
// key contains the separator (e.g. a port name).
const keysetSeparator = "|"

// EncodeKeysetTime encodes a (timestamp, id) keyset position as an opaque
// cursor for listings ordered by a time column. Keyset cursors make every
// page a single query: WHERE (created_at, id) < ($1, $2).
func EncodeKeysetTime(t time.Time, id string) string {
	return encode(t.UTC().Format(time.RFC3339Nano), id)
}

// DecodeKeysetTime parses a time-ordered keyset cursor. ok is false for
// empty, legacy (plain base64 ID) or corrupt cursors — callers start from the
// first page, matching the previous invalid-cursor behavior.
func DecodeKeysetTime(cursor string) (t time.Time, id string, ok bool) {
	key, id, ok := decode(cursor)
	if !ok {
		return time.Time{}, "", false
	}
	t, err := time.Parse(time.RFC3339Nano, key)
	if err != nil {
		return time.Time{}, "", false
	}
	return t, id, true
}

// EncodeKeysetText encodes a (text, id) keyset position for listings ordered
// by a text column (e.g. ports by name).
func EncodeKeysetText(key, id string) string {
	return encode(key, id)
}

// DecodeKeysetText parses a text-ordered keyset cursor.
func DecodeKeysetText(cursor string) (key, id string, ok bool) {
	return decode(cursor)
}

func encode(key, id string) string {
	return base64.URLEncoding.EncodeToString([]byte(key + keysetSeparator + id))
}

func decode(cursor string) (key, id string, ok bool) {
	if cursor == "" {
		return "", "", false
	}
	raw, err := base64.URLEncoding.DecodeString(cursor)
	if err != nil {
		return "", "", false
	}
	s := string(raw)
	i := strings.LastIndex(s, keysetSeparator)
	if i < 0 || i == len(s)-1 {
		return "", "", false
	}
	return s[:i], s[i+1:], true
}
