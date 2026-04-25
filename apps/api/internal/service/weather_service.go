package service

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// WeatherService wraps a WeatherProvider with in-memory caching.
type WeatherService struct {
	provider port.WeatherProvider
	mu       sync.RWMutex
	cache    map[string]weatherCacheEntry
	ttl      time.Duration
}

type weatherCacheEntry struct {
	data      *port.WeatherData
	fetchedAt time.Time
}

// NewWeatherService creates a new WeatherService with a default cache TTL of 10 minutes.
func NewWeatherService(provider port.WeatherProvider) *WeatherService {
	return &WeatherService{
		provider: provider,
		cache:    make(map[string]weatherCacheEntry),
		ttl:      10 * time.Minute,
	}
}

// cacheKey builds a deterministic key from coordinates.
func cacheKey(lat, lon float64) string {
	return fmt.Sprintf("%.4f:%.4f", lat, lon)
}

// GetCurrent returns the current weather, using a cached value if available.
func (s *WeatherService) GetCurrent(ctx context.Context, lat, lon float64) (*port.WeatherData, error) {
	key := cacheKey(lat, lon)

	s.mu.RLock()
	entry, ok := s.cache[key]
	s.mu.RUnlock()

	if ok && time.Since(entry.fetchedAt) < s.ttl {
		return entry.data, nil
	}

	data, err := s.provider.GetCurrent(ctx, lat, lon)
	if err != nil {
		return nil, fmt.Errorf("fetching current weather for %.4f,%.4f: %w", lat, lon, err)
	}

	s.mu.Lock()
	s.cache[key] = weatherCacheEntry{data: data, fetchedAt: time.Now()}
	s.mu.Unlock()

	return data, nil
}

// GetForecast returns a multi-day forecast from the provider. Forecasts are
// not cached because they contain multiple time points.
func (s *WeatherService) GetForecast(ctx context.Context, lat, lon float64, days int) ([]port.WeatherData, error) {
	if days <= 0 {
		days = 3
	}
	if days > 7 {
		days = 7
	}

	data, err := s.provider.GetForecast(ctx, lat, lon, days)
	if err != nil {
		return nil, fmt.Errorf("fetching forecast for %.4f,%.4f: %w", lat, lon, err)
	}
	return data, nil
}
