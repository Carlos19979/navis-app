package dto

import (
	"time"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// CreateDocumentRequest is the payload for creating a new document.
type CreateDocumentRequest struct {
	BoatID              string              `json:"boat_id"              validate:"required,uuid"`
	Type                domain.DocumentType `json:"type"                 validate:"required,oneof=itb insurance_rc insurance_full life_raft extinguisher flares first_aid medical_cert radio_cert navigation_license custom"`
	CustomName          *string             `json:"custom_name"          validate:"required_if=Type custom,omitempty,min=1,max=100"`
	ExpiryDate          time.Time           `json:"expiry_date"          validate:"required"`
	PhotoURL            *string             `json:"photo_url"            validate:"omitempty,url"`
	Notes               *string             `json:"notes"                validate:"omitempty,max=500"`
	LastRenewalDate     *time.Time          `json:"last_renewal_date"    validate:"omitempty"`
	LastRenewalCost     *float64            `json:"last_renewal_cost"    validate:"omitempty,gte=0"`
	LastRenewalProvider *string             `json:"last_renewal_provider" validate:"omitempty,max=200"`
	AlertDays           []int               `json:"alert_days"           validate:"omitempty,dive,gt=0"`
}

// ToDomain converts the request DTO to a domain Document.
func (r *CreateDocumentRequest) ToDomain(userID string) *domain.Document {
	alertDays := r.AlertDays
	if alertDays == nil {
		alertDays = []int{30, 7}
	}
	return &domain.Document{
		BoatID:              r.BoatID,
		UserID:              userID,
		Type:                r.Type,
		CustomName:          r.CustomName,
		ExpiryDate:          r.ExpiryDate,
		PhotoURL:            r.PhotoURL,
		Notes:               r.Notes,
		LastRenewalDate:     r.LastRenewalDate,
		LastRenewalCost:     r.LastRenewalCost,
		LastRenewalProvider: r.LastRenewalProvider,
		AlertDays:           alertDays,
	}
}

// UpdateDocumentRequest is the payload for updating an existing document.
type UpdateDocumentRequest struct {
	Type                *string    `json:"type"                  validate:"omitempty,oneof=itb insurance_rc insurance_full life_raft extinguisher flares first_aid medical_cert radio_cert navigation_license custom"`
	CustomName          *string    `json:"custom_name"           validate:"omitempty,min=1,max=100"`
	ExpiryDate          *time.Time `json:"expiry_date"           validate:"omitempty"`
	PhotoURL            *string    `json:"photo_url"             validate:"omitempty,url"`
	Notes               *string    `json:"notes"                 validate:"omitempty,max=500"`
	LastRenewalDate     *time.Time `json:"last_renewal_date"     validate:"omitempty"`
	LastRenewalCost     *float64   `json:"last_renewal_cost"     validate:"omitempty,gte=0"`
	LastRenewalProvider *string    `json:"last_renewal_provider" validate:"omitempty,max=200"`
	AlertDays           *[]int     `json:"alert_days"            validate:"omitempty,dive,gt=0"`
}

// ApplyTo merges non-nil fields from the request into the given domain Document.
func (r *UpdateDocumentRequest) ApplyTo(doc *domain.Document) {
	if r.Type != nil {
		doc.Type = domain.DocumentType(*r.Type)
	}
	if r.CustomName != nil {
		doc.CustomName = r.CustomName
	}
	if r.ExpiryDate != nil {
		doc.ExpiryDate = *r.ExpiryDate
	}
	if r.PhotoURL != nil {
		doc.PhotoURL = r.PhotoURL
	}
	if r.Notes != nil {
		doc.Notes = r.Notes
	}
	if r.LastRenewalDate != nil {
		doc.LastRenewalDate = r.LastRenewalDate
	}
	if r.LastRenewalCost != nil {
		doc.LastRenewalCost = r.LastRenewalCost
	}
	if r.LastRenewalProvider != nil {
		doc.LastRenewalProvider = r.LastRenewalProvider
	}
	if r.AlertDays != nil {
		doc.AlertDays = *r.AlertDays
	}
}

// DocumentResponse is the API response for a document.
type DocumentResponse struct {
	ID                  string                `json:"id"`
	BoatID              string                `json:"boat_id"`
	Type                domain.DocumentType   `json:"type"`
	CustomName          *string               `json:"custom_name,omitempty"`
	ExpiryDate          time.Time             `json:"expiry_date"`
	Status              domain.DocumentStatus `json:"status"`
	PhotoURL            *string               `json:"photo_url,omitempty"`
	Notes               *string               `json:"notes,omitempty"`
	LastRenewalDate     *time.Time            `json:"last_renewal_date,omitempty"`
	LastRenewalCost     *float64              `json:"last_renewal_cost,omitempty"`
	LastRenewalProvider *string               `json:"last_renewal_provider,omitempty"`
	AlertDays           []int                 `json:"alert_days"`
	CreatedAt           time.Time             `json:"created_at"`
	UpdatedAt           time.Time             `json:"updated_at"`
}

// DocumentResponseFromDomain builds a DocumentResponse from a domain Document.
func DocumentResponseFromDomain(d *domain.Document) *DocumentResponse {
	return &DocumentResponse{
		ID:                  d.ID,
		BoatID:              d.BoatID,
		Type:                d.Type,
		CustomName:          d.CustomName,
		ExpiryDate:          d.ExpiryDate,
		Status:              d.Status,
		PhotoURL:            d.PhotoURL,
		Notes:               d.Notes,
		LastRenewalDate:     d.LastRenewalDate,
		LastRenewalCost:     d.LastRenewalCost,
		LastRenewalProvider: d.LastRenewalProvider,
		AlertDays:           d.AlertDays,
		CreatedAt:           d.CreatedAt,
		UpdatedAt:           d.UpdatedAt,
	}
}

// DocumentListResponseFromDomain converts a slice of domain documents to response DTOs.
func DocumentListResponseFromDomain(docs []domain.Document) []DocumentResponse {
	out := make([]DocumentResponse, len(docs))
	for i := range docs {
		out[i] = *DocumentResponseFromDomain(&docs[i])
	}
	return out
}
