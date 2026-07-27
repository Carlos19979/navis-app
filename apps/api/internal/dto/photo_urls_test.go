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
		UserID:    "user-1",
		Name:      "Sea Breeze",
		PhotoURLs: []string{"https://x.test/g1.jpg"},
	}
	resp := OwnedBoatResponseFromDomain(boat)
	if len(resp.PhotoURLs) != 1 {
		t.Fatalf("expected 1 photo url, got %d", len(resp.PhotoURLs))
	}

	boat.PhotoURLs = nil
	resp = OwnedBoatResponseFromDomain(boat)
	if resp.PhotoURLs == nil {
		t.Error("expected empty slice for nil gallery, got nil")
	}
}

// The permission block is the client's gate for recording trips, documents,
// maintenance and expenses. A response built for the owner must say so; the
// zero value would read as "this owner may do nothing".
func TestOwnedBoatResponseFromDomain_OwnerGetsEveryPermission(t *testing.T) {
	t.Parallel()

	resp := OwnedBoatResponseFromDomain(&domain.Boat{ID: "boat-1", UserID: "user-1"})

	if !resp.IsOwner {
		t.Error("is_owner = false, want true for the boat's own user")
	}
	want := BoatPermissionsResponseFromDomain(domain.OwnerPermissions())
	if resp.Permissions != want {
		t.Errorf("permissions = %+v, want all granted %+v", resp.Permissions, want)
	}
}

func TestSharedBoatResponseFromDomain_CarriesMemberPermissions(t *testing.T) {
	t.Parallel()

	shared := &domain.SharedBoat{
		Boat:        domain.Boat{ID: "boat-1", UserID: "owner-1"},
		Permissions: domain.BoatPermissions{CanViewDocuments: true},
	}

	resp := SharedBoatResponseFromDomain(shared, "member-1")

	if resp.IsOwner {
		t.Error("is_owner = true, want false for a member")
	}
	if !resp.Permissions.CanViewDocuments {
		t.Error("can_view_documents = false, want the member's granted flag")
	}
	if resp.Permissions.CanRecordTrips {
		t.Error("can_record_trips = true, want the member's denied flag")
	}
}

func TestBoatEffectivePermissionsResponseFromDomain(t *testing.T) {
	t.Parallel()

	resp := BoatEffectivePermissionsResponseFromDomain("boat-1",
		domain.BoatPermissions{CanRecordTrips: true})

	if resp.BoatID != "boat-1" {
		t.Errorf("boat_id = %q, want boat-1", resp.BoatID)
	}
	if !resp.Permissions.CanRecordTrips {
		t.Error("can_record_trips = false, want true")
	}
	if resp.Permissions.CanManageExpenses {
		t.Error("can_manage_expenses = true, want false")
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
