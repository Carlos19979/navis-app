package service

import (
	"context"
	"fmt"
	"strings"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
)

// PortService implements business logic for port operations.
// Ports are read-only for regular users; they are managed externally.
type PortService struct {
	portRepo port.NauticalPortRepository
}

// NewPortService creates a new PortService.
func NewPortService(portRepo port.NauticalPortRepository) *PortService {
	return &PortService{portRepo: portRepo}
}

// GetByID retrieves a single port.
func (s *PortService) GetByID(ctx context.Context, id string) (*domain.Port, error) {
	p, err := s.portRepo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("getting port %s: %w", id, err)
	}
	return p, nil
}

// NearLocation returns ports within a given radius of coordinates.
func (s *PortService) NearLocation(ctx context.Context, lat, lon, radiusKM float64, cursor string, limit int) ([]domain.Port, string, error) {
	limit = pagination.ClampLimit(limit)
	if radiusKM <= 0 {
		radiusKM = 50
	}
	if radiusKM > 200 {
		radiusKM = 200
	}

	ports, nextCursor, err := s.portRepo.NearLocation(ctx, lat, lon, radiusKM, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing ports near %.4f,%.4f: %w", lat, lon, err)
	}
	return ports, nextCursor, nil
}

// maxBBoxSpanDeg caps how wide a single bbox query may be. A whole-globe
// request still only returns one clamped page, but rejecting absurd spans
// keeps the public endpoint from being used to scan the entire table with a
// single unbounded envelope.
const maxBBoxSpanDeg = 90.0

// WithinBBox returns ports inside the geographic bounding box
// [minLon, minLat, maxLon, maxLat], keyset-paginated by (name, id). It clamps
// the page size and validates the box before hitting the repository.
//
// The page ceiling is [pagination.MaxViewportLimit], not the API-wide default:
// a map viewport has to arrive in a single request (see that constant).
func (s *PortService) WithinBBox(ctx context.Context, minLon, minLat, maxLon, maxLat float64, cursor string, limit int) ([]domain.Port, string, error) {
	limit = pagination.ClampLimitTo(limit, pagination.MaxViewportLimit)

	if err := validateBBox(minLon, minLat, maxLon, maxLat); err != nil {
		return nil, "", err
	}

	ports, nextCursor, err := s.portRepo.WithinBBox(ctx, minLon, minLat, maxLon, maxLat, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("listing ports within bbox [%.4f,%.4f,%.4f,%.4f]: %w", minLon, minLat, maxLon, maxLat, err)
	}
	return ports, nextCursor, nil
}

// minSearchQueryLen guards against overly broad `%%` scans of the table.
const minSearchQueryLen = 2

// Search returns ports whose name matches query. When nearLat/nearLon are
// provided results are ordered by distance to that point. It clamps the page
// size and validates the inputs before hitting the repository.
func (s *PortService) Search(ctx context.Context, query string, nearLat, nearLon *float64, cursor string, limit int) ([]domain.Port, string, error) {
	limit = pagination.ClampLimit(limit)

	query = strings.TrimSpace(query)
	if len(query) < minSearchQueryLen {
		return nil, "", &domain.ValidationError{
			Field:   "q",
			Message: "search query must be at least 2 characters",
		}
	}

	// near is all-or-nothing, and each component must be in WGS84 range.
	if (nearLat == nil) != (nearLon == nil) {
		return nil, "", &domain.ValidationError{
			Field:   "near",
			Message: "near requires both latitude and longitude",
		}
	}
	if nearLat != nil && nearLon != nil {
		if *nearLat < -90 || *nearLat > 90 || *nearLon < -180 || *nearLon > 180 {
			return nil, "", &domain.ValidationError{
				Field:   "near",
				Message: "near is out of range",
			}
		}
	}

	ports, nextCursor, err := s.portRepo.Search(ctx, query, nearLat, nearLon, cursor, limit)
	if err != nil {
		return nil, "", fmt.Errorf("searching ports for %q: %w", query, err)
	}
	return ports, nextCursor, nil
}

// validateBBox enforces WGS84 ranges, ordering (min < max) and a sane maximum
// span. It returns a domain.ValidationError (mapped to 422) on failure.
func validateBBox(minLon, minLat, maxLon, maxLat float64) error {
	switch {
	case minLon < -180 || minLon > 180 || maxLon < -180 || maxLon > 180:
		return &domain.ValidationError{Field: "bbox", Message: "longitude must be within [-180, 180]"}
	case minLat < -90 || minLat > 90 || maxLat < -90 || maxLat > 90:
		return &domain.ValidationError{Field: "bbox", Message: "latitude must be within [-90, 90]"}
	case minLon >= maxLon:
		return &domain.ValidationError{Field: "bbox", Message: "minLon must be less than maxLon"}
	case minLat >= maxLat:
		return &domain.ValidationError{Field: "bbox", Message: "minLat must be less than maxLat"}
	case maxLon-minLon > maxBBoxSpanDeg || maxLat-minLat > maxBBoxSpanDeg:
		return &domain.ValidationError{Field: "bbox", Message: "bbox span is too large"}
	default:
		return nil
	}
}
