package handler

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
)

// WeatherHandler handles HTTP requests for weather data.
type WeatherHandler struct {
	svc *service.WeatherService
}

// NewWeatherHandler creates a new WeatherHandler.
func NewWeatherHandler(svc *service.WeatherService) *WeatherHandler {
	return &WeatherHandler{svc: svc}
}

// GetCurrent handles GET /weather/current?lat=X&lon=Y.
func (h *WeatherHandler) GetCurrent(w http.ResponseWriter, r *http.Request) {
	lat, lon, ok := parseLatLon(w, r)
	if !ok {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	data, err := h.svc.GetCurrent(ctx, lat, lon)
	if err != nil {
		Error(w, http.StatusBadGateway, "failed to fetch weather data", "WEATHER_ERROR")
		return
	}

	JSON(w, http.StatusOK, dto.WeatherFromPort(data))
}

// GetForecast handles GET /weather/forecast?lat=X&lon=Y&days=N.
func (h *WeatherHandler) GetForecast(w http.ResponseWriter, r *http.Request) {
	lat, lon, ok := parseLatLon(w, r)
	if !ok {
		return
	}

	days := 3
	if d := r.URL.Query().Get("days"); d != "" {
		if parsed, err := strconv.Atoi(d); err == nil && parsed > 0 {
			days = parsed
		}
	}

	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	data, err := h.svc.GetForecast(ctx, lat, lon, days)
	if err != nil {
		Error(w, http.StatusBadGateway, "failed to fetch forecast data", "WEATHER_ERROR")
		return
	}

	JSON(w, http.StatusOK, dto.ForecastFromPort(data))
}

// parseLatLon extracts lat and lon query parameters.
// Returns false if parameters are missing or invalid (response already written).
func parseLatLon(w http.ResponseWriter, r *http.Request) (float64, float64, bool) {
	latStr := r.URL.Query().Get("lat")
	lonStr := r.URL.Query().Get("lon")

	if latStr == "" || lonStr == "" {
		Error(w, http.StatusBadRequest, "lat and lon query parameters are required", "BAD_REQUEST")
		return 0, 0, false
	}

	lat, err := strconv.ParseFloat(latStr, 64)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid lat parameter", "BAD_REQUEST")
		return 0, 0, false
	}

	lon, err := strconv.ParseFloat(lonStr, 64)
	if err != nil {
		Error(w, http.StatusBadRequest, "invalid lon parameter", "BAD_REQUEST")
		return 0, 0, false
	}

	return lat, lon, true
}
