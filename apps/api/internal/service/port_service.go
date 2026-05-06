package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
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
	if limit <= 0 || limit > 50 {
		limit = 20
	}
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
