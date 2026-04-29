package dto

import "github.com/Carlos19979/navis-app/apps/api/internal/port"

type WeatherResponse struct {
	Temperature   float64  `json:"temperature"`
	WindSpeed     float64  `json:"wind_speed"`
	WindDirection float64  `json:"wind_direction"`
	WaveHeight    *float64 `json:"wave_height"`
	WavePeriod    *float64 `json:"wave_period"`
	Description   string   `json:"description"`
	Date          string   `json:"date,omitempty"`
}

func WeatherFromPort(d *port.WeatherData) WeatherResponse {
	r := WeatherResponse{
		Temperature:   d.Temp,
		WindSpeed:     d.WindSpeed,
		WindDirection: d.WindDir,
		Description:   d.Description,
		Date:          d.Time.Format("2006-01-02T15:04:05Z"),
	}
	if d.WaveHeight != 0 {
		r.WaveHeight = &d.WaveHeight
	}
	if d.WavePeriod != 0 {
		r.WavePeriod = &d.WavePeriod
	}
	return r
}

type ForecastResponse struct {
	Forecast []WeatherResponse `json:"forecast"`
}

func ForecastFromPort(data []port.WeatherData) ForecastResponse {
	items := make([]WeatherResponse, len(data))
	for i := range data {
		items[i] = WeatherFromPort(&data[i])
	}
	return ForecastResponse{Forecast: items}
}
