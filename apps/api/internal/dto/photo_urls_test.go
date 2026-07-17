package dto

import (
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

func TestMaintenanceResponseFromDomain_PhotoURLs(t *testing.T) {
	t.Parallel()

	log := &domain.MaintenanceLog{
		ID:          "log-1",
		BoatID:      "boat-1",
		Type:        "oil change",
		PerformedAt: time.Date(2026, 3, 15, 0, 0, 0, 0, time.UTC),
		PhotoURLs:   []string{"https://x.test/a.jpg", "https://x.test/b.jpg"},
	}
	resp := MaintenanceResponseFromDomain(log)
	if len(resp.PhotoURLs) != 2 {
		t.Fatalf("expected 2 photo urls, got %d", len(resp.PhotoURLs))
	}

	log.PhotoURLs = nil
	resp = MaintenanceResponseFromDomain(log)
	if resp.PhotoURLs == nil {
		t.Error("expected empty slice for nil photos (serializes as []), got nil")
	}
}

func TestBoatResponseFromDomain_PhotoURLs(t *testing.T) {
	t.Parallel()

	boat := &domain.Boat{
		ID:        "boat-1",
		Name:      "Sea Breeze",
		PhotoURLs: []string{"https://x.test/g1.jpg"},
	}
	resp := BoatResponseFromDomain(boat)
	if len(resp.PhotoURLs) != 1 {
		t.Fatalf("expected 1 photo url, got %d", len(resp.PhotoURLs))
	}

	boat.PhotoURLs = nil
	resp = BoatResponseFromDomain(boat)
	if resp.PhotoURLs == nil {
		t.Error("expected empty slice for nil gallery, got nil")
	}
}

func TestUpdateBoatRequest_ApplyTo_PhotoURLs(t *testing.T) {
	t.Parallel()

	boat := &domain.Boat{PhotoURLs: []string{"https://x.test/keep.jpg"}}

	// Omitted (nil) keeps the existing gallery.
	(&UpdateBoatRequest{}).ApplyTo(boat)
	if len(boat.PhotoURLs) != 1 {
		t.Fatalf("expected gallery kept, got %d entries", len(boat.PhotoURLs))
	}

	// Explicit empty list clears it.
	(&UpdateBoatRequest{PhotoURLs: []string{}}).ApplyTo(boat)
	if len(boat.PhotoURLs) != 0 {
		t.Fatalf("expected gallery cleared, got %d entries", len(boat.PhotoURLs))
	}
}
