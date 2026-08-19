package domain

import "time"

// Anomaly flags a trip whose fuel efficiency deviates sharply from the boat's
// historical baseline — a possible engine/usage issue worth a look.
type Anomaly struct {
	TripID       string
	Date         time.Time
	Metric       string  // "fuel_per_nm"
	Value        float64 // this trip's ratio
	Baseline     float64 // the boat's historical ratio
	DeviationPct float64 // percent over baseline (e.g. 30 = +30%)
	DistanceNM   float64 // the trip's distance, the ratios' denominator
	// ExcessLiters is the fuel this trip burned beyond the baseline. The client
	// turns it into money with the period's €/L, which this service has no
	// expenses to know.
	ExcessLiters float64
}
