package dto

import "github.com/Carlos19979/navis-app/apps/api/internal/domain"

// CreateReportRequest is the payload for reporting objectionable content.
type CreateReportRequest struct {
	ContentType string  `json:"content_type" validate:"required,oneof=group event"`
	ContentID   string  `json:"content_id"   validate:"required,uuid"`
	Reason      string  `json:"reason"       validate:"required,oneof=spam offensive harassment other"`
	Note        *string `json:"note"         validate:"omitempty,max=500"`
}

// ToDomain converts the request to a domain Report for the given reporter.
func (r *CreateReportRequest) ToDomain(reporterID string) *domain.Report {
	return &domain.Report{
		ReporterID:  reporterID,
		ContentType: domain.ReportContentType(r.ContentType),
		ContentID:   r.ContentID,
		Reason:      domain.ReportReason(r.Reason),
		Note:        r.Note,
	}
}

// BlockedUsersResponse lists the user IDs the caller has blocked.
type BlockedUsersResponse struct {
	BlockedUserIDs []string `json:"blocked_user_ids"`
}
