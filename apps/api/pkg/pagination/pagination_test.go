package pagination

import (
	"encoding/base64"
	"net/http/httptest"
	"testing"
	"time"
)

func TestKeysetTime_RoundTrip(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 7, 11, 13, 45, 30, 123456789, time.UTC)
	cursor := EncodeKeysetTime(now, "0b6f5c1e-1111-2222-3333-444455556666")

	got, id, ok := DecodeKeysetTime(cursor)
	if !ok {
		t.Fatal("expected ok")
	}
	if !got.Equal(now) {
		t.Errorf("time = %v, want %v", got, now)
	}
	if id != "0b6f5c1e-1111-2222-3333-444455556666" {
		t.Errorf("id = %q", id)
	}
}

func TestKeysetText_RoundTrip_SeparatorInKey(t *testing.T) {
	t.Parallel()
	// A sort key containing the separator must survive (split at LAST '|').
	cursor := EncodeKeysetText("Port|Olímpic", "abc-123")

	key, id, ok := DecodeKeysetText(cursor)
	if !ok {
		t.Fatal("expected ok")
	}
	if key != "Port|Olímpic" || id != "abc-123" {
		t.Errorf("got (%q, %q)", key, id)
	}
}

func TestDecodeKeyset_LegacyAndCorruptCursors(t *testing.T) {
	t.Parallel()
	legacy := base64.URLEncoding.EncodeToString([]byte("plain-id-without-separator"))

	for name, cursor := range map[string]string{
		"empty":            "",
		"legacy plain id":  legacy,
		"not base64":       "%%%not-base64%%%",
		"missing id":       base64.URLEncoding.EncodeToString([]byte("2026-01-01T00:00:00Z|")),
		"garbage timeform": EncodeKeysetText("not-a-time", "id"),
	} {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			if _, _, ok := DecodeKeysetTime(cursor); ok && name != "garbage timeform" {
				t.Errorf("DecodeKeysetTime(%q) ok = true, want false", cursor)
			}
			if name == "garbage timeform" {
				if _, _, ok := DecodeKeysetTime(cursor); ok {
					t.Error("non-time key must not decode as time keyset")
				}
			}
		})
	}
}

func TestParseCursor_ClampsLimit(t *testing.T) {
	t.Parallel()
	tests := []struct {
		query string
		want  int
	}{
		{"", 20},
		{"?limit=10", 10},
		{"?limit=50", 50},
		{"?limit=999", 50},
		{"?limit=0", 20},
		{"?limit=-3", 20},
		{"?limit=abc", 20},
	}
	for _, tt := range tests {
		r := httptest.NewRequest("GET", "/x"+tt.query, nil)
		if _, limit := ParseCursor(r); limit != tt.want {
			t.Errorf("ParseCursor(%q) limit = %d, want %d", tt.query, limit, tt.want)
		}
	}
}

func TestParseCursorTo_ViewportCeiling(t *testing.T) {
	t.Parallel()
	tests := []struct {
		query string
		max   int
		want  int
	}{
		// A viewport-sized page passes through: the map needs its markers in
		// one request, not spread over cursor pages.
		{"?limit=300", MaxViewportLimit, 300},
		{"?limit=400", MaxViewportLimit, MaxViewportLimit},
		// Above the ceiling it is still clamped — the raise is not a bypass.
		{"?limit=99999", MaxViewportLimit, MaxViewportLimit},
		// The default page size is unchanged when no limit is asked for.
		{"", MaxViewportLimit, 20},
		// A zero/absurd ceiling falls back to the API-wide cap.
		{"?limit=300", 0, 50},
		// A ceiling below the default must not hand back more than it allows.
		{"", 5, 5},
	}
	for _, tt := range tests {
		r := httptest.NewRequest("GET", "/x"+tt.query, nil)
		if _, limit := ParseCursorTo(r, tt.max); limit != tt.want {
			t.Errorf("ParseCursorTo(%q, %d) limit = %d, want %d",
				tt.query, tt.max, limit, tt.want)
		}
	}
}

func TestParseCursor_PassesCursorThroughVerbatim(t *testing.T) {
	t.Parallel()
	opaque := EncodeKeysetTime(time.Now(), "id-1")
	r := httptest.NewRequest("GET", "/x?cursor="+opaque, nil)
	cursor, _ := ParseCursor(r)
	if cursor != opaque {
		t.Errorf("cursor = %q, want passthrough %q", cursor, opaque)
	}
}
