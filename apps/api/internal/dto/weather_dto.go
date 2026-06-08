package dto

import "github.com/Carlos19979/navis-app/apps/api/internal/port"

// WeatherResponse represents current weather conditions.
type WeatherResponse struct {
	Temperature   float64  `json:"temperature"`
	WindSpeed     float64  `json:"wind_speed"`
	WindDirection float64  `json:"wind_direction"`
	WaveHeight    *float64 `json:"wave_height"`
	WavePeriod    *float64 `json:"wave_period"`
	Humidity      *int     `json:"humidity"`
	WeatherCode   int      `json:"weather_code"`
	Description   string   `json:"description"`
	Date          string   `json:"date,omitempty"`
}

// WeatherFromPort converts port weather data to a response DTO.
func WeatherFromPort(d *port.WeatherData) WeatherResponse {
	r := WeatherResponse{
		Temperature:   d.Temp,
		WindSpeed:     d.WindSpeed,
		WindDirection: d.WindDir,
		Humidity:      d.Humidity,
		WeatherCode:   d.WeatherCode,
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

// ForecastResponse wraps a list of weather forecasts.
type ForecastResponse struct {
	Forecast []WeatherResponse `json:"forecast"`
}

// ForecastFromPort converts a slice of port weather data to a forecast response.
func ForecastFromPort(data []port.WeatherData) ForecastResponse {
	items := make([]WeatherResponse, len(data))
	for i := range data {
		items[i] = WeatherFromPort(&data[i])
	}
	return ForecastResponse{Forecast: items}
}

// HourlyPointResponse is a single hour in an hourly forecast.
type HourlyPointResponse struct {
	Time                     string   `json:"time"`
	Temperature              float64  `json:"temperature"`
	WindSpeed                float64  `json:"wind_speed"`
	WindDirection            float64  `json:"wind_direction"`
	WaveHeight               *float64 `json:"wave_height"`
	WeatherCode              int      `json:"weather_code"`
	PrecipitationProbability *int     `json:"precipitation_probability"`
}

// DailyPointResponse is a single day in a multi-day forecast.
type DailyPointResponse struct {
	Date           string   `json:"date"`
	TemperatureMax float64  `json:"temperature_max"`
	TemperatureMin float64  `json:"temperature_min"`
	WindSpeed      float64  `json:"wind_speed"`
	WindDirection  float64  `json:"wind_direction"`
	WaveHeight     *float64 `json:"wave_height"`
	WeatherCode    int      `json:"weather_code"`
}

// HourlyResponse wraps a list of hourly forecast points for a single day.
type HourlyResponse struct {
	Hourly []HourlyPointResponse `json:"hourly"`
}

// HourlyFromPort converts a slice of port hourly points to a response DTO.
func HourlyFromPort(points []port.HourlyPoint) HourlyResponse {
	items := make([]HourlyPointResponse, len(points))
	for i := range points {
		p := &points[i]
		items[i] = HourlyPointResponse{
			Time:                     p.Time.Format("2006-01-02T15:04:05Z"),
			Temperature:              p.Temp,
			WindSpeed:                p.WindSpeed,
			WindDirection:            p.WindDir,
			WaveHeight:               p.WaveHeight,
			WeatherCode:              p.WeatherCode,
			PrecipitationProbability: p.Precipitation,
		}
	}
	return HourlyResponse{Hourly: items}
}

// OverviewResponse bundles current conditions with hourly and daily forecasts.
type OverviewResponse struct {
	Current      WeatherResponse       `json:"current"`
	Hourly       []HourlyPointResponse `json:"hourly"`
	Daily        []DailyPointResponse  `json:"daily"`
	Tides        []TidePointResponse   `json:"tides"`
	TideExtremes []TideExtremeResponse `json:"tide_extremes"`
}

// TidePointResponse is an hourly sea-level reading.
type TidePointResponse struct {
	Time   string  `json:"time"`
	Height float64 `json:"height"`
}

// TideExtremeResponse is a high/low tide turning point.
type TideExtremeResponse struct {
	Time   string  `json:"time"`
	Height float64 `json:"height"`
	Kind   string  `json:"kind"`
}

// OverviewFromPort converts a port weather overview to a response DTO.
func OverviewFromPort(o *port.WeatherOverview) OverviewResponse {
	hourly := make([]HourlyPointResponse, len(o.Hourly))
	for i := range o.Hourly {
		h := &o.Hourly[i]
		hourly[i] = HourlyPointResponse{
			Time:                     h.Time.Format("2006-01-02T15:04:05Z"),
			Temperature:              h.Temp,
			WindSpeed:                h.WindSpeed,
			WindDirection:            h.WindDir,
			WaveHeight:               h.WaveHeight,
			WeatherCode:              h.WeatherCode,
			PrecipitationProbability: h.Precipitation,
		}
	}

	daily := make([]DailyPointResponse, len(o.Daily))
	for i := range o.Daily {
		d := &o.Daily[i]
		daily[i] = DailyPointResponse{
			Date:           d.Date.Format("2006-01-02"),
			TemperatureMax: d.TempMax,
			TemperatureMin: d.TempMin,
			WindSpeed:      d.WindSpeed,
			WindDirection:  d.WindDir,
			WaveHeight:     d.WaveHeight,
			WeatherCode:    d.WeatherCode,
		}
	}

	tides := make([]TidePointResponse, len(o.Tides))
	for i := range o.Tides {
		tides[i] = TidePointResponse{
			Time:   o.Tides[i].Time.Format("2006-01-02T15:04:05Z"),
			Height: o.Tides[i].Height,
		}
	}
	extremes := make([]TideExtremeResponse, len(o.TideExtremes))
	for i := range o.TideExtremes {
		extremes[i] = TideExtremeResponse{
			Time:   o.TideExtremes[i].Time.Format("2006-01-02T15:04:05Z"),
			Height: o.TideExtremes[i].Height,
			Kind:   o.TideExtremes[i].Kind,
		}
	}

	current := WeatherFromPort(&o.Current)
	return OverviewResponse{
		Current:      current,
		Hourly:       hourly,
		Daily:        daily,
		Tides:        tides,
		TideExtremes: extremes,
	}
}
