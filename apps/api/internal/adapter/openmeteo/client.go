package openmeteo

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"golang.org/x/sync/errgroup"

	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

const (
	baseURL   = "https://api.open-meteo.com/v1/forecast"
	marineURL = "https://marine-api.open-meteo.com/v1/marine"
	// hoursAhead is how many hourly points the overview returns, starting from
	// the current hour (one rolling day, like the iOS weather app).
	hoursAhead = 24
	// overviewDays is how many daily points the overview returns (today + 6).
	overviewDays = 7
	timeLayout   = "2006-01-02T15:04"
	dateLayout   = "2006-01-02"
)

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
		Humidity      *int    `json:"relative_humidity_2m"`
		WeatherCode   int     `json:"weather_code"`
		WindSpeed     float64 `json:"wind_speed_10m"`
		WindDirection float64 `json:"wind_direction_10m"`
		Time          string  `json:"time"`
	} `json:"current"`
}

// forecastResponse represents the Open-Meteo API response for daily forecasts.
type forecastResponse struct {
	Daily struct {
		Time             []string  `json:"time"`
		Temperature2mMax []float64 `json:"temperature_2m_max"`
		Temperature2mMin []float64 `json:"temperature_2m_min"`
		WindSpeed10mMax  []float64 `json:"wind_speed_10m_max"`
		WindDirection10m []float64 `json:"wind_direction_10m_dominant"`
	} `json:"daily"`
}

// overviewResponse represents a combined current + hourly + daily payload.
type overviewResponse struct {
	Current struct {
		Temperature   float64 `json:"temperature_2m"`
		Humidity      *int    `json:"relative_humidity_2m"`
		WeatherCode   int     `json:"weather_code"`
		WindSpeed     float64 `json:"wind_speed_10m"`
		WindDirection float64 `json:"wind_direction_10m"`
		Time          string  `json:"time"`
	} `json:"current"`
	Hourly struct {
		Time          []string  `json:"time"`
		Temperature   []float64 `json:"temperature_2m"`
		WeatherCode   []int     `json:"weather_code"`
		WindSpeed     []float64 `json:"wind_speed_10m"`
		WindDirection []float64 `json:"wind_direction_10m"`
		Precipitation []int     `json:"precipitation_probability"`
	} `json:"hourly"`
	Daily struct {
		Time             []string  `json:"time"`
		WeatherCode      []int     `json:"weather_code"`
		Temperature2mMax []float64 `json:"temperature_2m_max"`
		Temperature2mMin []float64 `json:"temperature_2m_min"`
		WindSpeed10mMax  []float64 `json:"wind_speed_10m_max"`
		WindDirection10m []float64 `json:"wind_direction_10m_dominant"`
	} `json:"daily"`
}

// marineResponse represents the Open-Meteo Marine API response (wave data).
type marineResponse struct {
	Hourly struct {
		Time        []string  `json:"time"`
		WaveHeight  []float64 `json:"wave_height"`
		SeaLevelMsl []float64 `json:"sea_level_height_msl"`
	} `json:"hourly"`
	Daily struct {
		Time          []string  `json:"time"`
		WaveHeightMax []float64 `json:"wave_height_max"`
	} `json:"daily"`
}

// GetCurrent returns the current weather at the given coordinates.
func (c *Client) GetCurrent(ctx context.Context, lat, lon float64) (*port.WeatherData, error) {
	url := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m&wind_speed_unit=kn&timezone=auto",
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

	t, _ := time.Parse(timeLayout, resp.Current.Time)

	return &port.WeatherData{
		Temp:        resp.Current.Temperature,
		WindSpeed:   resp.Current.WindSpeed,
		WindDir:     resp.Current.WindDirection,
		Humidity:    resp.Current.Humidity,
		WeatherCode: resp.Current.WeatherCode,
		Description: describeWeatherCode(resp.Current.WeatherCode),
		Time:        t,
	}, nil
}

// GetForecast returns a multi-day weather forecast at the given coordinates.
func (c *Client) GetForecast(ctx context.Context, lat, lon float64, days int) ([]port.WeatherData, error) {
	url := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f&daily=weather_code,temperature_2m_max,temperature_2m_min,wind_speed_10m_max,wind_direction_10m_dominant&wind_speed_unit=kn&timezone=auto&forecast_days=%d",
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
		t, _ := time.Parse(dateLayout, dateStr)

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

// GetOverview returns current conditions plus an hourly (next 24h) and daily
// (today + 6) forecast in a single bundle. Wave data is fetched from the
// Open-Meteo Marine API on a best-effort basis — if it is unavailable (e.g.
// inland coordinates), wave fields are left nil rather than failing the call.
func (c *Client) GetOverview(ctx context.Context, lat, lon float64) (*port.WeatherOverview, error) {
	fcURL := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f"+
			"&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m"+
			"&hourly=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,precipitation_probability"+
			"&daily=weather_code,temperature_2m_max,temperature_2m_min,wind_speed_10m_max,wind_direction_10m_dominant"+
			"&wind_speed_unit=kn&timezone=auto&forecast_days=%d",
		baseURL, lat, lon, overviewDays,
	)
	mURL := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f&hourly=wave_height,sea_level_height_msl&daily=wave_height_max&timezone=auto&forecast_days=%d",
		marineURL, lat, lon, overviewDays,
	)

	var fc overviewResponse
	var marine marineResponse
	marineOK := false

	g, gctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		body, err := c.doGet(gctx, fcURL)
		if err != nil {
			return err
		}
		return json.Unmarshal(body, &fc)
	})
	g.Go(func() error {
		// Marine data is optional; never fail the overview because of it.
		body, err := c.doGet(gctx, mURL)
		if err != nil {
			return nil
		}
		if err := json.Unmarshal(body, &marine); err != nil {
			return nil
		}
		marineOK = true
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("fetching weather overview: %w", err)
	}

	// Index wave data by time/date string for alignment with the forecast.
	hourlyWaves := map[string]float64{}
	dailyWaves := map[string]float64{}
	if marineOK {
		for i, ts := range marine.Hourly.Time {
			if i < len(marine.Hourly.WaveHeight) {
				hourlyWaves[ts] = marine.Hourly.WaveHeight[i]
			}
		}
		for i, ds := range marine.Daily.Time {
			if i < len(marine.Daily.WaveHeightMax) {
				dailyWaves[ds] = marine.Daily.WaveHeightMax[i]
			}
		}
	}

	curTime, _ := time.Parse(timeLayout, fc.Current.Time)
	current := port.WeatherData{
		Temp:        fc.Current.Temperature,
		WindSpeed:   fc.Current.WindSpeed,
		WindDir:     fc.Current.WindDirection,
		Humidity:    fc.Current.Humidity,
		WeatherCode: fc.Current.WeatherCode,
		Description: describeWeatherCode(fc.Current.WeatherCode),
		Time:        curTime,
	}
	hourly := buildHourly(&fc, hourlyWaves, curTime)
	daily := buildDaily(&fc, dailyWaves)

	// Use the current hour's wave height for the "now" reading.
	if len(hourly) > 0 && hourly[0].WaveHeight != nil {
		current.WaveHeight = *hourly[0].WaveHeight
	}

	tides, extremes := buildTides(marineOK, marine.Hourly.Time, marine.Hourly.SeaLevelMsl, curTime)

	return &port.WeatherOverview{
		Current:      current,
		Hourly:       hourly,
		Daily:        daily,
		Tides:        tides,
		TideExtremes: extremes,
	}, nil
}

// buildTides converts the sea-level series into hourly tide points (from the
// current hour forward, ~2 days) and detects high/low turning points.
func buildTides(ok bool, times []string, levels []float64, now time.Time) ([]port.TidePoint, []port.TideExtreme) {
	if !ok || len(levels) == 0 {
		return nil, nil
	}
	type tp struct {
		t time.Time
		h float64
	}
	var series []tp
	for i, ts := range times {
		if i >= len(levels) {
			break
		}
		parsed, err := time.Parse(timeLayout, ts)
		if err != nil {
			continue
		}
		if parsed.Before(now.Add(-time.Hour)) {
			continue
		}
		series = append(series, tp{t: parsed, h: levels[i]})
	}
	const maxHours = 48
	if len(series) > maxHours {
		series = series[:maxHours]
	}

	points := make([]port.TidePoint, len(series))
	for i, s := range series {
		points[i] = port.TidePoint{Time: s.t, Height: s.h}
	}

	// Skip tides entirely where the range is negligible (e.g. the
	// Mediterranean, ~10cm): showing "low tide -0.6m" there is misleading.
	const minTidalRange = 0.3 // metres
	lo, hi := series[0].h, series[0].h
	for _, s := range series {
		if s.h < lo {
			lo = s.h
		}
		if s.h > hi {
			hi = s.h
		}
	}
	if hi-lo < minTidalRange {
		return nil, nil
	}

	// Detect strict local turning points (sliding three-point window).
	var raw []port.TideExtreme
	for i := range len(series) - 2 {
		prev, cur, next := series[i].h, series[i+1].h, series[i+2].h
		if cur > prev && cur > next {
			raw = append(raw, port.TideExtreme{Time: series[i+1].t, Height: cur, Kind: "high"})
		} else if cur < prev && cur < next {
			raw = append(raw, port.TideExtreme{Time: series[i+1].t, Height: cur, Kind: "low"})
		}
	}

	// Tides must strictly alternate high/low/high/low. Collapse any consecutive
	// same-kind detections (noise on near-flat Mediterranean tides) into the
	// single most extreme one, guaranteeing alternation.
	var extremes []port.TideExtreme
	for _, e := range raw {
		if n := len(extremes); n > 0 && extremes[n-1].Kind == e.Kind {
			last := &extremes[n-1]
			if (e.Kind == "high" && e.Height > last.Height) ||
				(e.Kind == "low" && e.Height < last.Height) {
				*last = e
			}
			continue
		}
		extremes = append(extremes, e)
	}
	if len(extremes) > 4 {
		extremes = extremes[:4]
	}
	return points, extremes
}

// GetHourly returns the full hourly forecast (00:00–23:00) for a single day at
// the given coordinates. The date must be in YYYY-MM-DD format. Wave data is
// fetched best-effort from the Marine API.
func (c *Client) GetHourly(ctx context.Context, lat, lon float64, date string) ([]port.HourlyPoint, error) {
	fcURL := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f"+
			"&hourly=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,precipitation_probability"+
			"&wind_speed_unit=kn&timezone=auto&start_date=%s&end_date=%s",
		baseURL, lat, lon, date, date,
	)
	mURL := fmt.Sprintf(
		"%s?latitude=%.4f&longitude=%.4f&hourly=wave_height&timezone=auto&start_date=%s&end_date=%s",
		marineURL, lat, lon, date, date,
	)

	var fc overviewResponse
	var marine marineResponse
	marineOK := false

	g, gctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		body, err := c.doGet(gctx, fcURL)
		if err != nil {
			return err
		}
		return json.Unmarshal(body, &fc)
	})
	g.Go(func() error {
		body, err := c.doGet(gctx, mURL)
		if err != nil {
			return nil
		}
		if err := json.Unmarshal(body, &marine); err != nil {
			return nil
		}
		marineOK = true
		return nil
	})
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("fetching hourly forecast: %w", err)
	}

	waves := map[string]float64{}
	if marineOK {
		for i, ts := range marine.Hourly.Time {
			if i < len(marine.Hourly.WaveHeight) {
				waves[ts] = marine.Hourly.WaveHeight[i]
			}
		}
	}

	points := make([]port.HourlyPoint, 0, len(fc.Hourly.Time))
	for i := range fc.Hourly.Time {
		points = append(points, hourlyPointAt(&fc, waves, i))
	}
	return points, nil
}

// hourlyPointAt builds a single HourlyPoint from the parsed series at index i,
// merging in wave data when available.
func hourlyPointAt(fc *overviewResponse, waves map[string]float64, i int) port.HourlyPoint {
	t, _ := time.Parse(timeLayout, fc.Hourly.Time[i])
	p := port.HourlyPoint{
		Time:        t,
		Temp:        safeIndex(fc.Hourly.Temperature, i),
		WindSpeed:   safeIndex(fc.Hourly.WindSpeed, i),
		WindDir:     safeIndex(fc.Hourly.WindDirection, i),
		WeatherCode: safeIndexInt(fc.Hourly.WeatherCode, i),
	}
	if i < len(fc.Hourly.Precipitation) {
		pp := fc.Hourly.Precipitation[i]
		p.Precipitation = &pp
	}
	if w, ok := waves[fc.Hourly.Time[i]]; ok {
		p.WaveHeight = &w
	}
	return p
}

// buildHourly slices the hourly series to start at the current hour and returns
// up to hoursAhead points.
func buildHourly(fc *overviewResponse, waves map[string]float64, now time.Time) []port.HourlyPoint {
	start := 0
	for i, ts := range fc.Hourly.Time {
		t, err := time.Parse(timeLayout, ts)
		if err != nil {
			continue
		}
		if !t.Before(now.Truncate(time.Hour)) {
			start = i
			break
		}
	}

	n := min(len(fc.Hourly.Time)-start, hoursAhead)
	points := make([]port.HourlyPoint, 0, hoursAhead)
	for i := range n {
		points = append(points, hourlyPointAt(fc, waves, start+i))
	}
	return points
}

// buildDaily converts the daily series into DailyPoint values.
func buildDaily(fc *overviewResponse, waves map[string]float64) []port.DailyPoint {
	days := make([]port.DailyPoint, 0, len(fc.Daily.Time))
	for i, ds := range fc.Daily.Time {
		t, _ := time.Parse(dateLayout, ds)
		d := port.DailyPoint{
			Date:        t,
			TempMax:     safeIndex(fc.Daily.Temperature2mMax, i),
			TempMin:     safeIndex(fc.Daily.Temperature2mMin, i),
			WindSpeed:   safeIndex(fc.Daily.WindSpeed10mMax, i),
			WindDir:     safeIndex(fc.Daily.WindDirection10m, i),
			WeatherCode: safeIndexInt(fc.Daily.WeatherCode, i),
		}
		if w, ok := waves[ds]; ok {
			d.WaveHeight = &w
		}
		days = append(days, d)
	}
	return days
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
	defer func() { _ = resp.Body.Close() }()

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

// safeIndexInt returns the int value at index i, or 0 if out of bounds.
func safeIndexInt(s []int, i int) int {
	if i < len(s) {
		return s[i]
	}
	return 0
}

// describeWeatherCode maps a WMO weather code to a short English description.
// The keywords (clear, cloud, rain, ...) double as icon hints on the client.
func describeWeatherCode(code int) string {
	switch code {
	case 0:
		return "Clear sky"
	case 1, 2:
		return "Partly cloudy"
	case 3:
		return "Overcast"
	case 45, 48:
		return "Fog"
	case 51, 53, 55, 56, 57:
		return "Drizzle"
	case 61, 63, 65, 66, 67, 80, 81, 82:
		return "Rain"
	case 71, 73, 75, 77, 85, 86:
		return "Snow"
	case 95, 96, 99:
		return "Thunderstorm"
	default:
		return "Unknown"
	}
}
