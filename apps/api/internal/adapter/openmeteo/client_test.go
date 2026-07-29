package openmeteo

import (
	"encoding/json"
	"testing"
	"time"
)

// Open-Meteo puts `null` inside a series for steps it has no value for. The
// response structs used to be []float64, so a single null failed the decode of
// the whole payload — the API answered 502 and the weather tab showed an error
// screen with a full, perfectly good forecast on the wire.
const payloadWithNulls = `{
  "current": {
    "time": "2026-07-29T17:45",
    "temperature_2m": 31.0,
    "relative_humidity_2m": 53,
    "weather_code": 0,
    "wind_speed_10m": 6.8,
    "wind_direction_10m": 125
  },
  "hourly": {
    "time": ["2026-07-29T17:00", "2026-07-29T18:00", "2026-07-29T19:00"],
    "temperature_2m": [30.1, null, 28.4],
    "weather_code": [0, null, 2],
    "wind_speed_10m": [7.0, null, 5.5],
    "wind_direction_10m": [120, null, 100],
    "precipitation_probability": [0, null, 10]
  },
  "daily": {
    "time": ["2026-07-29", "2026-07-30", "2026-07-31"],
    "weather_code": [0, 1, null],
    "temperature_2m_max": [31.0, null, 29.5],
    "temperature_2m_min": [22.0, null, 21.0],
    "wind_speed_10m_max": [12.0, 9.0, null],
    "wind_direction_10m_dominant": [130, 140, null]
  }
}`

func decodeOverview(t *testing.T, body string) *overviewResponse {
	t.Helper()
	var fc overviewResponse
	if err := json.Unmarshal([]byte(body), &fc); err != nil {
		t.Fatalf("a payload with nulls must still decode: %v", err)
	}
	return &fc
}

func TestOverviewDecodesSeriesWithNulls(t *testing.T) {
	t.Parallel()

	fc := decodeOverview(t, payloadWithNulls)

	if got := fc.Hourly.Temperature.at(0); got != 30.1 {
		t.Errorf("hourly temp[0] = %v, want 30.1", got)
	}
	if fc.Hourly.Temperature.ptr(1) != nil {
		t.Error("hourly temp[1] is null and must read as missing")
	}
	if got := fc.Hourly.Temperature.at(1); got != 0 {
		t.Errorf("at() on a null must be 0, got %v", got)
	}
	// Out of range is missing too, not a panic — the series can be shorter than
	// `time`, which is what the old direct indexing crashed on.
	if fc.Hourly.Temperature.ptr(99) != nil {
		t.Error("out-of-range must read as missing")
	}
}

func TestBuildHourlySkipsHoursWithoutTemperature(t *testing.T) {
	t.Parallel()

	fc := decodeOverview(t, payloadWithNulls)
	now := time.Date(2026, 7, 29, 17, 0, 0, 0, time.UTC)

	points := buildHourly(fc, map[string]float64{}, now)

	if len(points) != 2 {
		t.Fatalf("expected the 2 hours that have a temperature, got %d", len(points))
	}
	// An hour reading "0°" is worse than an hour that is not listed.
	for _, p := range points {
		if p.Temp == 0 {
			t.Errorf("a listed hour must carry a real temperature, got %+v", p)
		}
	}
	if points[0].Temp != 30.1 || points[1].Temp != 28.4 {
		t.Errorf("wrong hours kept: %v, %v", points[0].Temp, points[1].Temp)
	}
	// The nulls in the other series of a kept hour degrade to zero rather than
	// dropping the hour.
	if points[1].WindSpeed != 5.5 {
		t.Errorf("wind of the last hour = %v, want 5.5", points[1].WindSpeed)
	}
}

func TestBuildDailySkipsDaysWithoutTemperature(t *testing.T) {
	t.Parallel()

	fc := decodeOverview(t, payloadWithNulls)

	days := buildDaily(fc, map[string]float64{})

	if len(days) != 2 {
		t.Fatalf("expected the 2 days that have temperatures, got %d", len(days))
	}
	if days[0].TempMax != 31.0 || days[1].TempMax != 29.5 {
		t.Errorf("wrong days kept: %+v", days)
	}
	// Last day has null wind: zero, but the day still shows.
	if days[1].WindSpeed != 0 {
		t.Errorf("null wind should read 0, got %v", days[1].WindSpeed)
	}
}

func TestCurrentWithNullReadings(t *testing.T) {
	t.Parallel()

	// A "current" block can arrive with nulls too. Better a wrong-looking 0 in
	// one cell than no weather screen at all.
	fc := decodeOverview(t, `{"current":{"time":"2026-07-29T17:45",
	  "temperature_2m":null,"weather_code":null,
	  "wind_speed_10m":null,"wind_direction_10m":null}}`)

	if deref(fc.Current.Temperature) != 0 {
		t.Error("a null temperature must deref to 0, not panic")
	}
	if describeWeatherCode(deref(fc.Current.WeatherCode)) != "Clear sky" {
		t.Error("a null weather code must still describe something")
	}
}

func TestBuildTidesIgnoresGapsAndEmptySeries(t *testing.T) {
	t.Parallel()

	now := time.Date(2026, 7, 29, 0, 0, 0, 0, time.UTC)
	times := []string{
		"2026-07-29T00:00", "2026-07-29T01:00", "2026-07-29T02:00",
		"2026-07-29T03:00", "2026-07-29T04:00",
	}
	v := func(f float64) *float64 { return &f }

	t.Run("a gap does not invent an extreme", func(t *testing.T) {
		t.Parallel()
		// Without skipping nulls this read as a 0 m reading between two 1 m
		// ones: a low tide that does not exist.
		levels := nullableFloats{v(1.0), nil, v(1.05), v(1.6), v(1.0)}

		points, extremes := buildTides(true, times, levels, now)

		if len(points) != 4 {
			t.Fatalf("expected the 4 real readings, got %d", len(points))
		}
		for _, e := range extremes {
			if e.Height == 0 {
				t.Error("a gap became a tide extreme")
			}
		}
	})

	t.Run("every reading missing yields no tides", func(t *testing.T) {
		t.Parallel()
		points, extremes := buildTides(true, times, nullableFloats{nil, nil}, now)

		if points != nil || extremes != nil {
			t.Error("no readings must yield no tides, not a panic")
		}
	})

	t.Run("readings entirely in the past yield no tides", func(t *testing.T) {
		t.Parallel()
		// This used to index series[0] on an empty slice.
		later := now.Add(48 * time.Hour)
		points, extremes := buildTides(true, times, nullableFloats{v(1.0), v(2.0)}, later)

		if points != nil || extremes != nil {
			t.Error("expected no tides for a stale series")
		}
	})
}
