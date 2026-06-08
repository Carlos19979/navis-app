package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// TripParticipantRepo implements port.TripParticipantRepository using PostgreSQL.
type TripParticipantRepo struct {
	pool *pgxpool.Pool
}

// NewTripParticipantRepo creates a new TripParticipantRepo.
func NewTripParticipantRepo(pool *pgxpool.Pool) *TripParticipantRepo {
	return &TripParticipantRepo{pool: pool}
}

// SetRSVP upserts a participant's attendance answer for a trip.
func (r *TripParticipantRepo) SetRSVP(ctx context.Context, tripID, userID string, rsvp domain.RSVP) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO trip_participants (trip_id, user_id, rsvp)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (trip_id, user_id)
		 DO UPDATE SET rsvp = EXCLUDED.rsvp, responded_at = now()`,
		tripID, userID, rsvp)
	if err != nil {
		return fmt.Errorf("setting RSVP for trip %s: %w", tripID, err)
	}
	return nil
}

// Remove deletes a participant's RSVP from a trip.
func (r *TripParticipantRepo) Remove(ctx context.Context, tripID, userID string) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM trip_participants WHERE trip_id = $1 AND user_id = $2`,
		tripID, userID)
	if err != nil {
		return fmt.Errorf("removing RSVP for trip %s: %w", tripID, err)
	}
	return nil
}

// ListByTrip returns all RSVPs for a trip, oldest answer first.
func (r *TripParticipantRepo) ListByTrip(ctx context.Context, tripID string) ([]domain.TripParticipant, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT tp.trip_id, tp.user_id, tp.rsvp, tp.responded_at, `+memberNameExpr+`
		 FROM trip_participants tp
		 LEFT JOIN auth.users u ON u.id = tp.user_id
		 WHERE tp.trip_id = $1
		 ORDER BY tp.responded_at ASC`,
		tripID)
	if err != nil {
		return nil, fmt.Errorf("listing participants for trip %s: %w", tripID, err)
	}
	defer rows.Close()

	participants := make([]domain.TripParticipant, 0)
	for rows.Next() {
		var p domain.TripParticipant
		if err := rows.Scan(&p.TripID, &p.UserID, &p.RSVP, &p.RespondedAt, &p.Name); err != nil {
			return nil, fmt.Errorf("scanning participant for trip %s: %w", tripID, err)
		}
		participants = append(participants, p)
	}
	return participants, rows.Err()
}
