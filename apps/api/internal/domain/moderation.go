package domain

import "time"

// ReportContentType is the kind of user-generated content being reported.
type ReportContentType string

// ReportContentType values.
const (
	ReportContentGroup ReportContentType = "group"
	ReportContentEvent ReportContentType = "event"
)

// Valid reports whether the content type is one we accept reports for.
func (t ReportContentType) Valid() bool {
	switch t {
	case ReportContentGroup, ReportContentEvent:
		return true
	default:
		return false
	}
}

// ReportReason is why the reporter flagged the content.
type ReportReason string

// ReportReason values.
const (
	ReportReasonSpam       ReportReason = "spam"
	ReportReasonOffensive  ReportReason = "offensive"
	ReportReasonHarassment ReportReason = "harassment"
	ReportReasonOther      ReportReason = "other"
)

// Valid reports whether the reason is one of the accepted values.
func (r ReportReason) Valid() bool {
	switch r {
	case ReportReasonSpam, ReportReasonOffensive, ReportReasonHarassment, ReportReasonOther:
		return true
	default:
		return false
	}
}

// ReportStatus is the operator-review lifecycle of a report.
type ReportStatus string

// ReportStatus values.
const (
	ReportStatusPending   ReportStatus = "pending"
	ReportStatusReviewed  ReportStatus = "reviewed"
	ReportStatusActioned  ReportStatus = "actioned"
	ReportStatusDismissed ReportStatus = "dismissed"
)

// Report is a user's flag on a piece of user-generated content for operator
// review — the "report offensive content" pillar of App Store guideline 1.2.
type Report struct {
	ID          string
	ReporterID  string
	ContentType ReportContentType
	ContentID   string
	Reason      ReportReason
	Note        *string
	Status      ReportStatus
	CreatedAt   time.Time
}

// BlockedUser records that BlockerID has blocked BlockedID. The blocked user's
// public content is hidden from the blocker's discovery feeds.
type BlockedUser struct {
	BlockerID string
	BlockedID string
	CreatedAt time.Time
}
