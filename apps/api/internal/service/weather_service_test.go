package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// --- mock WeatherProvider ---

type mockWeatherProvider struct {
	getCurrentFn  func(ctx context.Context, lat, lon float64) (*port.WeatherData, error)
	getForecastFn func(ctx context.Context, lat, lon float64, days int) ([]port.WeatherData, error)
}

func (m *mockWeatherProvider) GetCurrent(ctx context.Context, lat, lon float64) (*port.WeatherData, error) {
	return m.getCurrentFn(ctx, lat, lon)
}

func (m *mockWeatherProvider) GetForecast(ctx context.Context, lat, lon float64, days int) ([]port.WeatherData, error) {
	return m.getForecastFn(ctx, lat, lon, days)
}

// --- helpers ---

func newTestWeatherData() *port.WeatherData {
	return &port.WeatherData{
		Temp:        22.5,
		WindSpeed:   12.3,
		WindDir:     180,
		WaveHeight:  1.2,
		WavePeriod:  6.5,
		Description: "Partly cloudy",
		Time:        time.Now(),
	}
}

// --- GetCurrent tests ---

func TestWeatherService_GetCurrent_Success(t *testing.T) {
	t.Parallel()

	weather := newTestWeatherData()
	provider := &mockWeatherProvider{
		getCurrentFn: func(_ context.Context, _, _ float64) (*port.WeatherData, error) {
			return weather, nil
		},
	}
	svc := NewWeatherService(provider)

	result, err := svc.GetCurrent(context.Background(), 39.47, -0.38)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if result.Temp != 22.5 {
		t.Errorf("expected temp 22.5, got %f", result.Temp)
	}
	if result.Description != "Partly cloudy" {
		t.Errorf("expected description %q, got %q", "Partly cloudy", result.Description)
	}
}

func TestWeatherService_GetCurrent_ProviderError(t *testing.T) {
	t.Parallel()

	providerErr := errors.New("API unavailable")
	provider := &mockWeatherProvider{
		getCurrentFn: func(_ context.Context, _, _ float64) (*port.WeatherData, error) {
			return nil, providerErr
		},
	}
	svc := NewWeatherService(provider)

	_, err := svc.GetCurrent(context.Background(), 39.47, -0.38)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, providerErr) {
		t.Errorf("expected underlying error %v, got %v", providerErr, err)
	}
}

func TestWeatherService_GetCurrent_CacheHit(t *testing.T) {
	t.Parallel()

	callCount := 0
	weather := newTestWeatherData()
	provider := &mockWeatherProvider{
		getCurrentFn: func(_ context.Context, _, _ float64) (*port.WeatherData, error) {
			callCount++
			return weather, nil
		},
	}
	svc := NewWeatherService(provider)

	// First call: should hit the provider.
	result1, err := svc.GetCurrent(context.Background(), 39.47, -0.38)
	if err != nil {
		t.Fatalf("first call: expected no error, got %v", err)
	}
	if callCount != 1 {
		t.Fatalf("expected 1 provider call, got %d", callCount)
	}

	// Second call with same coordinates: should use cache.
	result2, err := svc.GetCurrent(context.Background(), 39.47, -0.38)
	if err != nil {
		t.Fatalf("second call: expected no error, got %v", err)
	}
	if callCount != 1 {
		t.Errorf("expected provider to be called only once (cache hit), got %d calls", callCount)
	}
	if result1.Temp != result2.Temp {
		t.Errorf("expected same cached data, got different temps: %f vs %f", result1.Temp, result2.Temp)
	}
}

func TestWeatherService_GetCurrent_CacheMissDifferentCoords(t *testing.T) {
	t.Parallel()

	callCount := 0
	provider := &mockWeatherProvider{
		getCurrentFn: func(_ context.Context, _, _ float64) (*port.WeatherData, error) {
			callCount++
			return newTestWeatherData(), nil
		},
	}
	svc := NewWeatherService(provider)

	// First call.
	_, err := svc.GetCurrent(context.Background(), 39.47, -0.38)
	if err != nil {
		t.Fatalf("first call: expected no error, got %v", err)
	}

	// Second call with different coordinates: should miss cache.
	_, err = svc.GetCurrent(context.Background(), 40.00, -1.00)
	if err != nil {
		t.Fatalf("second call: expected no error, got %v", err)
	}
	if callCount != 2 {
		t.Errorf("expected 2 provider calls for different coords, got %d", callCount)
	}
}

func TestWeatherService_GetCurrent_CacheExpiry(t *testing.T) {
	t.Parallel()

	callCount := 0
	provider := &mockWeatherProvider{
		getCurrentFn: func(_ context.Context, _, _ float64) (*port.WeatherData, error) {
			callCount++
			return newTestWeatherData(), nil
		},
	}
	svc := NewWeatherService(provider)
	// Set a very short TTL for testing.
	svc.ttl = 1 * time.Millisecond

	// First call.
	_, err := svc.GetCurrent(context.Background(), 39.47, -0.38)
	if err != nil {
		t.Fatalf("first call: expected no error, got %v", err)
	}

	// Wait for cache to expire.
	time.Sleep(5 * time.Millisecond)

	// Second call: cache should be expired.
	_, err = svc.GetCurrent(context.Background(), 39.47, -0.38)
	if err != nil {
		t.Fatalf("second call: expected no error, got %v", err)
	}
	if callCount != 2 {
		t.Errorf("expected 2 provider calls after cache expiry, got %d", callCount)
	}
}

// --- GetForecast tests ---

func TestWeatherService_GetForecast_Success(t *testing.T) {
	t.Parallel()

	forecast := []port.WeatherData{
		*newTestWeatherData(),
		*newTestWeatherData(),
		*newTestWeatherData(),
	}
	provider := &mockWeatherProvider{
		getForecastFn: func(_ context.Context, _, _ float64, days int) ([]port.WeatherData, error) {
			if days != 3 {
				t.Errorf("expected 3 days, got %d", days)
			}
			return forecast, nil
		},
	}
	svc := NewWeatherService(provider)

	result, err := svc.GetForecast(context.Background(), 39.47, -0.38, 3)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(result) != 3 {
		t.Errorf("expected 3 forecast points, got %d", len(result))
	}
}

func TestWeatherService_GetForecast_ProviderError(t *testing.T) {
	t.Parallel()

	providerErr := errors.New("forecast unavailable")
	provider := &mockWeatherProvider{
		getForecastFn: func(_ context.Context, _, _ float64, _ int) ([]port.WeatherData, error) {
			return nil, providerErr
		},
	}
	svc := NewWeatherService(provider)

	_, err := svc.GetForecast(context.Background(), 39.47, -0.38, 3)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !errors.Is(err, providerErr) {
		t.Errorf("expected underlying error %v, got %v", providerErr, err)
	}
}

func TestWeatherService_GetForecast_DefaultDays(t *testing.T) {
	t.Parallel()

	var capturedDays int
	provider := &mockWeatherProvider{
		getForecastFn: func(_ context.Context, _, _ float64, days int) ([]port.WeatherData, error) {
			capturedDays = days
			return []port.WeatherData{}, nil
		},
	}
	svc := NewWeatherService(provider)

	tests := []struct {
		name         string
		inputDays    int
		expectedDays int
	}{
		{"zero days defaults to 3", 0, 3},
		{"negative days defaults to 3", -1, 3},
		{"over 7 capped to 7", 14, 7},
		{"valid days preserved", 5, 5},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _ = svc.GetForecast(context.Background(), 39.47, -0.38, tt.inputDays)
			if capturedDays != tt.expectedDays {
				t.Errorf("expected days %d, got %d", tt.expectedDays, capturedDays)
			}
		})
	}
}

func TestWeatherService_GetForecast_NotCached(t *testing.T) {
	t.Parallel()

	callCount := 0
	provider := &mockWeatherProvider{
		getForecastFn: func(_ context.Context, _, _ float64, _ int) ([]port.WeatherData, error) {
			callCount++
			return []port.WeatherData{*newTestWeatherData()}, nil
		},
	}
	svc := NewWeatherService(provider)

	// Two calls with same coordinates should both hit the provider
	// (forecasts are not cached).
	_, _ = svc.GetForecast(context.Background(), 39.47, -0.38, 3)
	_, _ = svc.GetForecast(context.Background(), 39.47, -0.38, 3)

	if callCount != 2 {
		t.Errorf("expected 2 provider calls (no caching), got %d", callCount)
	}
}

// --- cacheKey tests ---

func TestCacheKey_Deterministic(t *testing.T) {
	t.Parallel()

	key1 := cacheKey(39.4699, -0.3763)
	key2 := cacheKey(39.4699, -0.3763)
	if key1 != key2 {
		t.Errorf("expected same key for same coords, got %q and %q", key1, key2)
	}
}

func TestCacheKey_DifferentCoords(t *testing.T) {
	t.Parallel()

	key1 := cacheKey(39.4699, -0.3763)
	key2 := cacheKey(40.0000, -1.0000)
	if key1 == key2 {
		t.Errorf("expected different keys for different coords, both got %q", key1)
	}
}

func TestCacheKey_PrecisionRounding(t *testing.T) {
	t.Parallel()

	// Coords that differ only in the 5th+ decimal place and round to the same
	// 4-decimal value should produce the same key.
	key1 := cacheKey(39.46991, -0.37631)
	key2 := cacheKey(39.46994, -0.37634)
	if key1 != key2 {
		t.Errorf("expected same key for coords within 4-decimal precision, got %q and %q", key1, key2)
	}
}
