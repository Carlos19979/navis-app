package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// PortResponse is the API response for a port.
type PortResponse struct {
	ID         string          `json:"id"`
	Name       string          `json:"name"`
	Lat        float64         `json:"lat"`
	Lon        float64         `json:"lon"`
	Country    string          `json:"country"`
	PortType   domain.PortType `json:"port_type"`
	DepthM     *float64        `json:"depth_m,omitempty"`
	Facilities []string        `json:"facilities"`
	VHFChannel *string         `json:"vhf_channel,omitempty"`
	Website    *string         `json:"website,omitempty"`
	CreatedAt  time.Time       `json:"created_at"`
	UpdatedAt  time.Time       `json:"updated_at"`
}

// PortResponseFromDomain builds a PortResponse from a domain Port.
func PortResponseFromDomain(p *domain.Port) *PortResponse {
	facilities := p.Facilities
	if facilities == nil {
		facilities = []string{}
	}
	return &PortResponse{
		ID:         p.ID,
		Name:       p.Name,
		Lat:        p.Lat,
		Lon:        p.Lon,
		Country:    p.Country,
		PortType:   p.PortType,
		DepthM:     p.DepthM,
		Facilities: facilities,
		VHFChannel: p.VHFChannel,
		Website:    p.Website,
		CreatedAt:  p.CreatedAt,
		UpdatedAt:  p.UpdatedAt,
	}
}

// PortListResponseFromDomain converts a slice of domain ports to response DTOs.
func PortListResponseFromDomain(ports []domain.Port) []PortResponse {
	out := make([]PortResponse, len(ports))
	for i := range ports {
		out[i] = *PortResponseFromDomain(&ports[i])
	}
	return out
}
