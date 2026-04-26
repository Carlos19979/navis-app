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

// PushNotifier abstracts push notification delivery (e.g. FCM).
type PushNotifier interface {
	Send(ctx context.Context, deviceToken, title, body string) error
}
