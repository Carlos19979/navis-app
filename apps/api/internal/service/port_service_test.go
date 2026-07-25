package service

import (
	"context"
	"errors"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// mockPortRepo is a hand-rolled fake for port.NauticalPortRepository. Each
// method delegates to a func field so tests wire only what they need.
type mockPortRepo struct {
	withinBBoxFn func(ctx context.Context, minLon, minLat, maxLon, maxLat float64, cursor string, limit int) ([]domain.Port, string, error)
	searchFn     func(ctx context.Context, query string, nearLat, nearLon *float64, cursor string, limit int) ([]domain.Port, string, error)
}

func (m *mockPortRepo) GetByID(_ context.Context, _ string) (*domain.Port, error) {
	return nil, domain.ErrPortNotFound
}

func (m *mockPortRepo) NearLocation(_ context.Context, _, _, _ float64, _ string, _ int) ([]domain.Port, string, error) {
	return nil, "", nil
}

func (m *mockPortRepo) WithinBBox(ctx context.Context, minLon, minLat, maxLon, maxLat float64, cursor string, limit int) ([]domain.Port, string, error) {
	return m.withinBBoxFn(ctx, minLon, minLat, maxLon, maxLat, cursor, limit)
}

func (m *mockPortRepo) Search(ctx context.Context, query string, nearLat, nearLon *float64, cursor string, limit int) ([]domain.Port, string, error) {
	return m.searchFn(ctx, query, nearLat, nearLon, cursor, limit)
}

func TestPortService_WithinBBox_ClampsLimit(t *testing.T) {
	t.Parallel()

	var gotLimit int
	repo := &mockPortRepo{
		withinBBoxFn: func(_ context.Context, _, _, _, _ float64, _ string, limit int) ([]domain.Port, string, error) {
			gotLimit = limit
			return []domain.Port{{ID: "p1", Name: "Alpha"}}, "", nil
		},
	}
	svc := NewPortService(repo)

	// A page size above the API cap (50) must be clamped before the repo call.
	ports, _, err := svc.WithinBBox(context.Background(), 2.0, 39.0, 3.0, 40.0, "", 500)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gotLimit != 50 {
		t.Errorf("limit = %d, want 50 (clamped)", gotLimit)
	}
	if len(ports) != 1 {
		t.Errorf("ports = %d, want 1", len(ports))
	}
}

func TestPortService_WithinBBox_Invalid(t *testing.T) {
	t.Parallel()

	repo := &mockPortRepo{
		withinBBoxFn: func(_ context.Context, _, _, _, _ float64, _ string, _ int) ([]domain.Port, string, error) {
			t.Helper()
			t.Fatal("repo must not be called for an invalid bbox")
			return nil, "", nil
		},
	}
	svc := NewPortService(repo)

	cases := map[string]struct {
		minLon, minLat, maxLon, maxLat float64
	}{
		"min_lon_not_less_than_max": {3.0, 39.0, 3.0, 40.0},
		"min_lat_not_less_than_max": {2.0, 40.0, 3.0, 40.0},
		"lon_out_of_range":          {-200.0, 39.0, 3.0, 40.0},
		"lat_out_of_range":          {2.0, 39.0, 3.0, 120.0},
		"span_too_large":            {-100.0, 0.0, 100.0, 1.0},
	}

	for name, tc := range cases {
		tc := tc
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			_, _, err := svc.WithinBBox(context.Background(), tc.minLon, tc.minLat, tc.maxLon, tc.maxLat, "", 20)
			if !errors.Is(err, domain.ErrValidation) {
				t.Errorf("err = %v, want ErrValidation", err)
			}
		})
	}
}

func TestPortService_Search_ClampsLimitAndTrims(t *testing.T) {
	t.Parallel()

	var (
		gotLimit int
		gotQuery string
	)
	repo := &mockPortRepo{
		searchFn: func(_ context.Context, query string, _, _ *float64, _ string, limit int) ([]domain.Port, string, error) {
			gotQuery = query
			gotLimit = limit
			return []domain.Port{{ID: "p1", Name: "Palma"}}, "", nil
		},
	}
	svc := NewPortService(repo)

	_, _, err := svc.Search(context.Background(), "  Palma  ", nil, nil, "", 500)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gotQuery != "Palma" {
		t.Errorf("query = %q, want trimmed Palma", gotQuery)
	}
	if gotLimit != 50 {
		t.Errorf("limit = %d, want 50 (clamped)", gotLimit)
	}
}

func TestPortService_Search_Invalid(t *testing.T) {
	t.Parallel()

	lat := 39.0
	repo := &mockPortRepo{
		searchFn: func(_ context.Context, _ string, _, _ *float64, _ string, _ int) ([]domain.Port, string, error) {
			t.Helper()
			t.Fatal("repo must not be called for invalid search input")
			return nil, "", nil
		},
	}
	svc := NewPortService(repo)

	cases := map[string]struct {
		query   string
		nearLat *float64
		nearLon *float64
	}{
		"too_short":       {"a", nil, nil},
		"blank":           {"   ", nil, nil},
		"near_incomplete": {"Palma", &lat, nil},
	}

	for name, tc := range cases {
		tc := tc
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			_, _, err := svc.Search(context.Background(), tc.query, tc.nearLat, tc.nearLon, "", 20)
			if !errors.Is(err, domain.ErrValidation) {
				t.Errorf("err = %v, want ErrValidation", err)
			}
		})
	}
}

func TestPortService_Search_PassesNear(t *testing.T) {
	t.Parallel()

	lat, lon := 39.5, 2.6
	var gotLat, gotLon *float64
	repo := &mockPortRepo{
		searchFn: func(_ context.Context, _ string, nearLat, nearLon *float64, _ string, _ int) ([]domain.Port, string, error) {
			gotLat, gotLon = nearLat, nearLon
			return nil, "", nil
		},
	}
	svc := NewPortService(repo)

	_, _, err := svc.Search(context.Background(), "Marina", &lat, &lon, "", 20)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if gotLat == nil || gotLon == nil || *gotLat != lat || *gotLon != lon {
		t.Errorf("near = %v,%v, want %v,%v", gotLat, gotLon, lat, lon)
	}
}

func TestPortService_WithinBBox_PassesThroughCursor(t *testing.T) {
	t.Parallel()

	repo := &mockPortRepo{
		withinBBoxFn: func(_ context.Context, minLon, minLat, maxLon, maxLat float64, cursor string, _ int) ([]domain.Port, string, error) {
			if cursor != "opaque-cursor" {
				t.Errorf("cursor = %q, want opaque-cursor", cursor)
			}
			if minLon != 2.0 || minLat != 39.0 || maxLon != 3.0 || maxLat != 40.0 {
				t.Errorf("bbox = %v,%v,%v,%v, want 2,39,3,40", minLon, minLat, maxLon, maxLat)
			}
			return nil, "next", nil
		},
	}
	svc := NewPortService(repo)

	_, next, err := svc.WithinBBox(context.Background(), 2.0, 39.0, 3.0, 40.0, "opaque-cursor", 20)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if next != "next" {
		t.Errorf("next cursor = %q, want next", next)
	}
}
