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
	provider      port.WeatherProvider
	mu            sync.RWMutex
	cache         map[string]weatherCacheEntry
	overviewCache map[string]overviewCacheEntry
	hourlyCache   map[string]hourlyCacheEntry
	ttl           time.Duration
}

type weatherCacheEntry struct {
	data      *port.WeatherData
	fetchedAt time.Time
}

type overviewCacheEntry struct {
	data      *port.WeatherOverview
	fetchedAt time.Time
}

type hourlyCacheEntry struct {
	data      []port.HourlyPoint
	fetchedAt time.Time
}

// NewWeatherService creates a new WeatherService with a default cache TTL of 10 minutes.
func NewWeatherService(provider port.WeatherProvider) *WeatherService {
	return &WeatherService{
		provider:      provider,
		cache:         make(map[string]weatherCacheEntry),
		overviewCache: make(map[string]overviewCacheEntry),
		hourlyCache:   make(map[string]hourlyCacheEntry),
		ttl:           10 * time.Minute,
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

// GetOverview returns current conditions plus hourly and daily forecasts,
// using a cached value if one was fetched within the TTL.
func (s *WeatherService) GetOverview(ctx context.Context, lat, lon float64) (*port.WeatherOverview, error) {
	key := cacheKey(lat, lon)

	s.mu.RLock()
	entry, ok := s.overviewCache[key]
	s.mu.RUnlock()

	if ok && time.Since(entry.fetchedAt) < s.ttl {
		return entry.data, nil
	}

	data, err := s.provider.GetOverview(ctx, lat, lon)
	if err != nil {
		return nil, fmt.Errorf("fetching overview for %.4f,%.4f: %w", lat, lon, err)
	}

	s.mu.Lock()
	s.overviewCache[key] = overviewCacheEntry{data: data, fetchedAt: time.Now()}
	s.mu.Unlock()

	return data, nil
}

// GetHourly returns the hourly forecast for a single day (YYYY-MM-DD), using a
// cached value if one was fetched within the TTL.
func (s *WeatherService) GetHourly(ctx context.Context, lat, lon float64, date string) ([]port.HourlyPoint, error) {
	key := cacheKey(lat, lon) + ":" + date

	s.mu.RLock()
	entry, ok := s.hourlyCache[key]
	s.mu.RUnlock()

	if ok && time.Since(entry.fetchedAt) < s.ttl {
		return entry.data, nil
	}

	data, err := s.provider.GetHourly(ctx, lat, lon, date)
	if err != nil {
		return nil, fmt.Errorf("fetching hourly for %.4f,%.4f on %s: %w", lat, lon, date, err)
	}

	s.mu.Lock()
	s.hourlyCache[key] = hourlyCacheEntry{data: data, fetchedAt: time.Now()}
	s.mu.Unlock()

	return data, nil
}
