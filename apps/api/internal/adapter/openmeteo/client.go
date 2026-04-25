package openmeteo

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

const baseURL = "https://api.open-meteo.com/v1/forecast"

// Client implements port.WeatherProvider using the free Open-Meteo API.
type Client struct {
	http *http.Client
}

// New creates a new Open-Meteo client.
func New() *Client {
	return &Client{
		http: &http.Client{Timeout: 10 * time.Second},
	}
}

// currentResponse represents the Open-Meteo API response for current weather.
type currentResponse struct {
	Current struct {
		Temperature   float64 `json:"temperature_2m"`
		WindSpeed     float64 `json:"wind_speed_10m"`
		WindDirection float64 `json:"wind_direction_10m"`
		Time          string  `json:"time"`
	} `json:"current"`
}

// forecastResponse represents the Open-Meteo API response for daily forecasts.
type forecastResponse struct {
	Daily struct {
		Time              []string  `json:"time"`
		Temperature2mMax  []float64 `json:"temperature_2m_max"`
		Temperature2mMin  []float64 `json:"temperature_2m_min"`
		WindSpeed10mMax   []float64 `json:"wind_speed_10m_max"`
		WindDirection10m  []float64 `json:"wind_direction_10m_dominant"`
	} `json:"daily"`
}

// GetCurrent returns the current weather at the given coordinates.
func (c *Client) GetCurrent(ctx context.Context, lat, lon float64) (*port.WeatherData, error) {
	url := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f&current=temperature_2m,wind_speed_10m,wind_direction_10m&timezone=UTC",
		baseURL, lat, lon,
	)

	body, err := c.doGet(ctx, url)
	if err != nil {
		return nil, err
	}

	var resp currentResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("decoding current weather response: %w", err)
	}

	t, _ := time.Parse("2006-01-02T15:04", resp.Current.Time)

	return &port.WeatherData{
		Temp:      resp.Current.Temperature,
		WindSpeed: resp.Current.WindSpeed,
		WindDir:   resp.Current.WindDirection,
		Time:      t,
	}, nil
}

// GetForecast returns a multi-day weather forecast at the given coordinates.
func (c *Client) GetForecast(ctx context.Context, lat, lon float64, days int) ([]port.WeatherData, error) {
	url := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f&daily=temperature_2m_max,temperature_2m_min,wind_speed_10m_max,wind_direction_10m_dominant&timezone=UTC&forecast_days=%d",
		baseURL, lat, lon, days,
	)

	body, err := c.doGet(ctx, url)
	if err != nil {
		return nil, err
	}

	var resp forecastResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("decoding forecast response: %w", err)
	}

	forecasts := make([]port.WeatherData, 0, len(resp.Daily.Time))
	for i, dateStr := range resp.Daily.Time {
		t, _ := time.Parse("2006-01-02", dateStr)

		wd := port.WeatherData{
			Temp:    (resp.Daily.Temperature2mMax[i] + resp.Daily.Temperature2mMin[i]) / 2,
			WindDir: safeIndex(resp.Daily.WindDirection10m, i),
			Time:    t,
		}
		if i < len(resp.Daily.WindSpeed10mMax) {
			wd.WindSpeed = resp.Daily.WindSpeed10mMax[i]
		}
		forecasts = append(forecasts, wd)
	}

	return forecasts, nil
}

// doGet performs an HTTP GET request and returns the response body.
func (c *Client) doGet(ctx context.Context, url string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("reading response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("open-meteo API returned status %d: %s", resp.StatusCode, string(body))
	}

	return body, nil
}

// safeIndex returns the value at index i, or 0 if out of bounds.
func safeIndex(s []float64, i int) float64 {
	if i < len(s) {
		return s[i]
	}
	return 0
}
