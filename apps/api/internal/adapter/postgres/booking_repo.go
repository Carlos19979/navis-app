package postgres

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// BookingRepo implements port.BookingRepository using PostgreSQL.
type BookingRepo struct {
	pool *pgxpool.Pool
}

// NewBookingRepo creates a new BookingRepo.
func NewBookingRepo(pool *pgxpool.Pool) *BookingRepo {
	return &BookingRepo{pool: pool}
}

const bookingColumns = `id, boat_id, user_id, starts_at, ends_at, purpose, status, created_at, updated_at`

func scanBooking(row interface{ Scan(...any) error }) (*domain.Booking, error) {
	var b domain.Booking
	err := row.Scan(&b.ID, &b.BoatID, &b.UserID, &b.StartsAt, &b.EndsAt,
		&b.Purpose, &b.Status, &b.CreatedAt, &b.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

// Create inserts a booking.
func (r *BookingRepo) Create(ctx context.Context, b *domain.Booking) (*domain.Booking, error) {
	query := `INSERT INTO bookings (boat_id, user_id, starts_at, ends_at, purpose, status)
		VALUES ($1,$2,$3,$4,$5,$6) RETURNING ` + bookingColumns
	out, err := scanBooking(r.pool.QueryRow(ctx, query,
		b.BoatID, b.UserID, b.StartsAt, b.EndsAt, b.Purpose, b.Status))
	if err != nil {
		return nil, fmt.Errorf("creating booking: %w", err)
	}
	return out, nil
}

// ListByBoat returns a boat's bookings, soonest first.
func (r *BookingRepo) ListByBoat(ctx context.Context, boatID string) ([]domain.Booking, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+bookingColumns+` FROM bookings WHERE boat_id = $1 ORDER BY starts_at ASC`,
		boatID)
	if err != nil {
		return nil, fmt.Errorf("listing bookings: %w", err)
	}
	defer rows.Close()

	var out []domain.Booking
	for rows.Next() {
		b, err := scanBooking(rows)
		if err != nil {
			return nil, fmt.Errorf("scanning booking: %w", err)
		}
		out = append(out, *b)
	}
	return out, rows.Err()
}

// Delete removes a booking on a boat.
func (r *BookingRepo) Delete(ctx context.Context, boatID, id string) error {
	ct, err := r.pool.Exec(ctx,
		`DELETE FROM bookings WHERE boat_id = $1 AND id = $2`, boatID, id)
	if err != nil {
		return fmt.Errorf("deleting booking %s: %w", id, err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
