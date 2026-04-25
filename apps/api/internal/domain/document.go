package domain

import "time"

// DocumentType represents the type of a document.
type DocumentType string

const (
	DocumentTypeITB              DocumentType = "itb"
	DocumentTypeInsuranceRC      DocumentType = "insurance_rc"
	DocumentTypeInsuranceFull    DocumentType = "insurance_full"
	DocumentTypeLifeRaft         DocumentType = "life_raft"
	DocumentTypeExtinguisher     DocumentType = "extinguisher"
	DocumentTypeFlares           DocumentType = "flares"
	DocumentTypeFirstAid         DocumentType = "first_aid"
	DocumentTypeMedicalCert      DocumentType = "medical_cert"
	DocumentTypeRadioCert        DocumentType = "radio_cert"
	DocumentTypeNavigationLicense DocumentType = "navigation_license"
	DocumentTypeCustom           DocumentType = "custom"
)

// DocumentStatus represents the current validity status of a document.
type DocumentStatus string

const (
	DocumentStatusOK       DocumentStatus = "ok"
	DocumentStatusWarning  DocumentStatus = "warning"
	DocumentStatusCritical DocumentStatus = "critical"
	DocumentStatusExpired  DocumentStatus = "expired"
)

// Document represents a regulatory or safety document associated with a boat.
type Document struct {
	ID                  string
	BoatID              string
	UserID              string
	Type                DocumentType
	CustomName          *string
	ExpiryDate          time.Time
	Status              DocumentStatus
	PhotoURL            *string
	Notes               *string
	LastRenewalDate     *time.Time
	LastRenewalCost     *float64
	LastRenewalProvider *string
	AlertDays           []int
	CreatedAt           time.Time
	UpdatedAt           time.Time
}
