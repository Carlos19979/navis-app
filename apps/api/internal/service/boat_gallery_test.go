package service

import (
	"context"
	"errors"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

func galleryBoatRepo() *mockBoatRepo {
	return &mockBoatRepo{
		createFn: func(_ context.Context, b *domain.Boat) (*domain.Boat, error) {
			b.ID = "boat-1"
			return b, nil
		},
		updateFn: func(_ context.Context, _ string, b *domain.Boat) (*domain.Boat, error) {
			return b, nil
		},
	}
}

func TestBoatService_Create_FreeGalleryPhotoHitsPlanLimit(t *testing.T) {
	t.Parallel()

	svc := NewBoatService(galleryBoatRepo(), &testutil.FakeProfileRepo{Plan: domain.PlanFree})
	boat := newTestBoat()
	boat.PhotoURLs = urls(1)

	_, err := svc.Create(context.Background(), boat)
	if !errors.Is(err, domain.ErrPlanLimit) {
		t.Fatalf("expected ErrPlanLimit, got %v", err)
	}
}

func TestBoatService_Create_ProGalleryWithinLimit(t *testing.T) {
	t.Parallel()

	svc := NewBoatService(galleryBoatRepo(), &testutil.FakeProfileRepo{Plan: domain.PlanPro})
	boat := newTestBoat()
	boat.PhotoURLs = urls(9) // cover + 9 extras = GalleryLimit(10)

	created, err := svc.Create(context.Background(), boat)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(created.PhotoURLs) != 9 {
		t.Errorf("expected 9 gallery photos, got %d", len(created.PhotoURLs))
	}
}

func TestBoatService_Update_ProGalleryOverLimit(t *testing.T) {
	t.Parallel()

	svc := NewBoatService(galleryBoatRepo(), &testutil.FakeProfileRepo{Plan: domain.PlanPro})
	boat := newTestBoat()
	boat.PhotoURLs = urls(10) // cover + 10 extras exceeds GalleryLimit(10)

	_, err := svc.Update(context.Background(), "user-1", boat)
	if !errors.Is(err, domain.ErrPlanLimit) {
		t.Fatalf("expected ErrPlanLimit, got %v", err)
	}
}

func TestBoatService_Update_NormalizesNilGallery(t *testing.T) {
	t.Parallel()

	svc := NewBoatService(galleryBoatRepo(), &testutil.FakeProfileRepo{Plan: domain.PlanFree})
	boat := newTestBoat()
	boat.PhotoURLs = nil

	updated, err := svc.Update(context.Background(), "user-1", boat)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if updated.PhotoURLs == nil {
		t.Error("expected photo urls normalized to an empty slice, got nil")
	}
}

func TestBoatService_Update_GalleryHardCap(t *testing.T) {
	t.Parallel()

	svc := NewBoatService(galleryBoatRepo(), &testutil.FakeProfileRepo{Plan: domain.PlanPro})
	boat := newTestBoat()
	boat.PhotoURLs = urls(11)

	_, err := svc.Update(context.Background(), "user-1", boat)
	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
	if ve.Field != "photo_urls" {
		t.Errorf("expected field %q, got %q", "photo_urls", ve.Field)
	}
}
