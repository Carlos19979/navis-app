package port

import (
	"context"
	"time"
)

// WeatherData holds a single weather observation or forecast point.
type WeatherData struct {
	Temp        float64
	WindSpeed   float64
	WindDir     float64
	WaveHeight  float64
	WavePeriod  float64
	Humidity    *int
	WeatherCode int
	Description string
	Time        time.Time
}

// HourlyPoint is a single hour in an hourly forecast.
type HourlyPoint struct {
	Time          time.Time
	Temp          float64
	WindSpeed     float64
	WindDir       float64
	WaveHeight    *float64
	WeatherCode   int
	Precipitation *int // probability of precipitation, percent
}

// DailyPoint is a single day in a multi-day forecast.
type DailyPoint struct {
	Date        time.Time
	TempMax     float64
	TempMin     float64
	WindSpeed   float64
	WindDir     float64
	WaveHeight  *float64
	WeatherCode int
}

// WeatherOverview bundles current conditions with hourly and daily forecasts,
// matching the layout of a typical weather app (now, next 24h, next days).
type WeatherOverview struct {
	Current      WeatherData
	Hourly       []HourlyPoint
	Daily        []DailyPoint
	Tides        []TidePoint
	TideExtremes []TideExtreme
}

// TidePoint is an hourly sea-level reading (metres, model-based).
type TidePoint struct {
	Time   time.Time
	Height float64
}

// TideExtreme is a high or low tide turning point.
type TideExtreme struct {
	Time   time.Time
	Height float64
	Kind   string // "high" | "low"
}

// WeatherProvider abstracts external weather APIs.
type WeatherProvider interface {
	GetCurrent(ctx context.Context, lat, lon float64) (*WeatherData, error)
	GetForecast(ctx context.Context, lat, lon float64, days int) ([]WeatherData, error)
	GetOverview(ctx context.Context, lat, lon float64) (*WeatherOverview, error)
	GetHourly(ctx context.Context, lat, lon float64, date string) ([]HourlyPoint, error)
}

// SupabaseAdmin abstracts privileged Supabase operations that require the
// service role key: deleting a user from auth.users (which cascades to every
// app table) and purging their files from Storage buckets.
type SupabaseAdmin interface {
	// DeleteUserFiles removes every object under the user's folder in a bucket.
	DeleteUserFiles(ctx context.Context, bucket, userID string) error
	// DeleteAuthUser removes the user from auth.users. Deleting an already
	// absent user is not an error (idempotent).
	DeleteAuthUser(ctx context.Context, userID string) error
}

// NotificationProvider abstracts notification delivery (e.g. Novu).
type NotificationProvider interface {
	TriggerWorkflow(ctx context.Context, workflowID, subscriberID string, payload map[string]any) error
	EnsureSubscriber(ctx context.Context, subscriberID string) error
	SetPushToken(ctx context.Context, subscriberID, token string) error
	RemovePushToken(ctx context.Context, subscriberID, token string) error
}
