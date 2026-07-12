package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// AnomalyResponse mirrors a domain.Anomaly.
type AnomalyResponse struct {
	TripID       string  `json:"trip_id"`
	Date         string  `json:"date"`
	Metric       string  `json:"metric"`
	Value        float64 `json:"value"`
	Baseline     float64 `json:"baseline"`
	DeviationPct float64 `json:"deviation_pct"`
}

// AnomalyListFromDomain converts a slice of anomalies.
func AnomalyListFromDomain(as []domain.Anomaly) []AnomalyResponse {
	out := make([]AnomalyResponse, len(as))
	for i, a := range as {
		out[i] = AnomalyResponse{
			TripID:       a.TripID,
			Date:         a.Date.Format(time.RFC3339),
			Metric:       a.Metric,
			Value:        a.Value,
			Baseline:     a.Baseline,
			DeviationPct: a.DeviationPct,
		}
	}
	return out
}
