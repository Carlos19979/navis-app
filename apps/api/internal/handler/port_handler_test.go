package handler

import "testing"

func TestParseBBox_Valid(t *testing.T) {
	t.Parallel()

	minLon, minLat, maxLon, maxLat, err := parseBBox("2.1,39.4,3.2,40.1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if minLon != 2.1 || minLat != 39.4 || maxLon != 3.2 || maxLat != 40.1 {
		t.Errorf("got %v,%v,%v,%v, want 2.1,39.4,3.2,40.1", minLon, minLat, maxLon, maxLat)
	}
}

func TestParseBBox_Invalid(t *testing.T) {
	t.Parallel()

	cases := map[string]string{
		"too_few_parts":  "2.1,39.4,3.2",
		"too_many_parts": "2.1,39.4,3.2,40.1,5.0",
		"non_numeric":    "2.1,north,3.2,40.1",
		"empty":          "",
	}

	for name, raw := range cases {
		raw := raw
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			if _, _, _, _, err := parseBBox(raw); err == nil {
				t.Errorf("parseBBox(%q) = nil error, want error", raw)
			}
		})
	}
}

func TestParseNearPoint_Valid(t *testing.T) {
	t.Parallel()

	lat, lon, err := parseNearPoint("39.5, 2.6")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if lat != 39.5 || lon != 2.6 {
		t.Errorf("got %v,%v, want 39.5,2.6", lat, lon)
	}
}

func TestParseNearPoint_Invalid(t *testing.T) {
	t.Parallel()

	cases := map[string]string{
		"one_part":    "39.5",
		"three_parts": "39.5,2.6,1.0",
		"non_numeric": "north,2.6",
		"empty":       "",
	}

	for name, raw := range cases {
		raw := raw
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			if _, _, err := parseNearPoint(raw); err == nil {
				t.Errorf("parseNearPoint(%q) = nil error, want error", raw)
			}
		})
	}
}
