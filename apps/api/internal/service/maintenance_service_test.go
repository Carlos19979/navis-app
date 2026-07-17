package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

func newTestLog(photos []string) *domain.MaintenanceLog {
	return &domain.MaintenanceLog{
		BoatID:      "boat-1",
		UserID:      "user-1",
		Type:        "oil change",
		PerformedAt: time.Now(),
		PhotoURLs:   photos,
	}
}

func newMaintSvc(plan domain.Plan) *MaintenanceService {
	return NewMaintenanceService(
		&mockMaintenanceRepo{},
		&mockMaintenanceTaskRepo{},
		&mockExpenseRepo{},
		&mockBoatRepo{},
		&testutil.FakeProfileRepo{Plan: plan},
	)
}

func urls(n int) []string {
	out := make([]string, n)
	for i := range n {
		out[i] = "https://storage.example.com/p.jpg"
	}
	return out
}

func TestMaintenanceService_AddLog_NormalizesNilPhotos(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	created, err := svc.AddLog(context.Background(), newTestLog(nil))
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if created.PhotoURLs == nil {
		t.Error("expected photo urls normalized to an empty slice, got nil")
	}
}

func TestMaintenanceService_AddLog_FreeAllowsOnePhoto(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	created, err := svc.AddLog(context.Background(), newTestLog(urls(1)))
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(created.PhotoURLs) != 1 {
		t.Errorf("expected 1 photo, got %d", len(created.PhotoURLs))
	}
}

func TestMaintenanceService_AddLog_FreeSecondPhotoHitsPlanLimit(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	_, err := svc.AddLog(context.Background(), newTestLog(urls(2)))
	if !errors.Is(err, domain.ErrPlanLimit) {
		t.Fatalf("expected ErrPlanLimit, got %v", err)
	}
}

func TestMaintenanceService_AddLog_ProAllowsManyPhotos(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanPro)
	created, err := svc.AddLog(context.Background(), newTestLog(urls(10)))
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(created.PhotoURLs) != 10 {
		t.Errorf("expected 10 photos, got %d", len(created.PhotoURLs))
	}
}

func TestMaintenanceService_AddLog_HardCapOverflow(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanPro)
	_, err := svc.AddLog(context.Background(), newTestLog(urls(11)))
	var ve *domain.ValidationError
	if !errors.As(err, &ve) {
		t.Fatalf("expected ValidationError, got %T: %v", err, err)
	}
	if ve.Field != "photo_urls" {
		t.Errorf("expected field %q, got %q", "photo_urls", ve.Field)
	}
}

func TestMaintenanceService_UpdateLog_FreeSecondPhotoHitsPlanLimit(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanFree)
	log := newTestLog(urls(2))
	log.ID = "log-1"
	_, err := svc.UpdateLog(context.Background(), "user-1", log)
	if !errors.Is(err, domain.ErrPlanLimit) {
		t.Fatalf("expected ErrPlanLimit, got %v", err)
	}
}

func TestMaintenanceService_UpdateLog_ProPhotosOK(t *testing.T) {
	t.Parallel()

	svc := newMaintSvc(domain.PlanPro)
	log := newTestLog(urls(4))
	log.ID = "log-1"
	updated, err := svc.UpdateLog(context.Background(), "user-1", log)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(updated.PhotoURLs) != 4 {
		t.Errorf("expected 4 photos, got %d", len(updated.PhotoURLs))
	}
}
