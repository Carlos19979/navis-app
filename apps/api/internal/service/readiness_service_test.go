package service

import (
	"context"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/testutil"
)

// mockMaintenanceRepo is a minimal port.MaintenanceRepository for readiness tests.
type mockMaintenanceRepo struct {
	logs []domain.MaintenanceLog
	err  error
}

func (m *mockMaintenanceRepo) Create(_ context.Context, l *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	return l, nil
}

func (m *mockMaintenanceRepo) Update(_ context.Context, l *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	return l, nil
}

func (m *mockMaintenanceRepo) Delete(_ context.Context, _, _ string) error { return nil }

func (m *mockMaintenanceRepo) ListByBoat(_ context.Context, _ string) ([]domain.MaintenanceLog, error) {
	return m.logs, m.err
}

func daysFromNow(days int) time.Time {
	return time.Now().Add(time.Duration(days) * 24 * time.Hour)
}

func readinessDocs(docs ...domain.Document) *mockDocumentRepo {
	return &mockDocumentRepo{
		listByBoatFn: func(_ context.Context, _, _, _ string, _ int) ([]domain.Document, string, error) {
			return docs, "", nil
		},
	}
}

func TestReadinessService_Get_ReadyWhenAllValid(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)},
		domain.Document{Type: domain.DocumentTypeFlares, ExpiryDate: daysFromNow(200)},
	)
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{{PerformedAt: daysFromNow(-30)}}}
	svc := NewReadinessService(docs, maint, &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessReady {
		t.Errorf("status = %q, want ready", r.Status)
	}
	if r.Score != 100 {
		t.Errorf("score = %d, want 100", r.Score)
	}
	if !r.Full {
		t.Error("Full = false, want true for Pro")
	}
	if len(r.Attention) != 0 {
		t.Errorf("attention = %d items, want 0", len(r.Attention))
	}
}

func TestReadinessService_Get_NotReadyWhenGearExpired(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeExtinguisher, ExpiryDate: daysFromNow(-5)},
	)
	maint := &mockMaintenanceRepo{logs: []domain.MaintenanceLog{{PerformedAt: daysFromNow(-30)}}}
	svc := NewReadinessService(docs, maint, &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanPro})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Status != domain.ReadinessNotReady {
		t.Errorf("status = %q, want not_ready", r.Status)
	}
	if len(r.Attention) != 1 || r.Attention[0].Ref != string(domain.DocumentTypeExtinguisher) {
		t.Errorf("attention = %+v, want one extinguisher item", r.Attention)
	}
}

func TestReadinessService_Get_FreePlanIsDocumentsOnly(t *testing.T) {
	t.Parallel()
	docs := readinessDocs(
		domain.Document{Type: domain.DocumentTypeITB, ExpiryDate: daysFromNow(200)},
	)
	// No maintenance logs: on Pro this would flag attention, but Free must not
	// even include the maintenance category.
	maint := &mockMaintenanceRepo{}
	svc := NewReadinessService(docs, maint, &mockBoatRepo{}, &testutil.FakeProfileRepo{Plan: domain.PlanFree})

	r, err := svc.Get(context.Background(), "user-1", "boat-1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.Full {
		t.Error("Full = true, want false for Free")
	}
	for _, c := range r.Categories {
		if c.Key == domain.ReadinessCatMaintenance {
			t.Error("Free plan must not include the maintenance category")
		}
	}
}
