package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// ModerationService implements the user-facing side of App Store guideline 1.2:
// reporting objectionable content and blocking abusive users. Content filtering
// at creation time lives in pkg/moderation and is enforced by the content
// services (groups, regattas).
type ModerationService struct {
	reports port.ReportRepository
	blocks  port.BlockRepository
}

// NewModerationService creates a new ModerationService.
func NewModerationService(reports port.ReportRepository, blocks port.BlockRepository) *ModerationService {
	return &ModerationService{reports: reports, blocks: blocks}
}

// CreateReport validates and stores a user's report of objectionable content.
func (s *ModerationService) CreateReport(ctx context.Context, report *domain.Report) error {
	if !report.ContentType.Valid() {
		return &domain.ValidationError{Field: "content_type", Message: "unsupported content type"}
	}
	if !report.Reason.Valid() {
		return &domain.ValidationError{Field: "reason", Message: "unsupported reason"}
	}
	if err := s.reports.Create(ctx, report); err != nil {
		return fmt.Errorf("moderation_service.CreateReport: %w", err)
	}
	return nil
}

// BlockUser records that blockerID blocks blockedID.
func (s *ModerationService) BlockUser(ctx context.Context, blockerID, blockedID string) error {
	if blockerID == blockedID {
		return domain.ErrSelfBlock
	}
	if err := s.blocks.Block(ctx, blockerID, blockedID); err != nil {
		return fmt.Errorf("moderation_service.BlockUser: %w", err)
	}
	return nil
}

// UnblockUser removes a block.
func (s *ModerationService) UnblockUser(ctx context.Context, blockerID, blockedID string) error {
	if err := s.blocks.Unblock(ctx, blockerID, blockedID); err != nil {
		return fmt.Errorf("moderation_service.UnblockUser: %w", err)
	}
	return nil
}

// ListBlocked returns the user IDs blockerID has blocked.
func (s *ModerationService) ListBlocked(ctx context.Context, blockerID string) ([]string, error) {
	ids, err := s.blocks.ListBlockedIDs(ctx, blockerID)
	if err != nil {
		return nil, fmt.Errorf("moderation_service.ListBlocked: %w", err)
	}
	return ids, nil
}
