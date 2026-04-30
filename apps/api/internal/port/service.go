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
	Description string
	Time        time.Time
}

// WeatherProvider abstracts external weather APIs.
type WeatherProvider interface {
	GetCurrent(ctx context.Context, lat, lon float64) (*WeatherData, error)
	GetForecast(ctx context.Context, lat, lon float64, days int) ([]WeatherData, error)
}

// NotificationProvider abstracts notification delivery (e.g. Novu).
type NotificationProvider interface {
	TriggerWorkflow(ctx context.Context, workflowID, subscriberID string, payload map[string]any) error
	EnsureSubscriber(ctx context.Context, subscriberID string) error
	SetPushToken(ctx context.Context, subscriberID, token string) error
	RemovePushToken(ctx context.Context, subscriberID, token string) error
}
