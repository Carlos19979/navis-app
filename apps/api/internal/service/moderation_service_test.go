package service

import (
	"context"
	"errors"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

type fakeReportRepo struct {
	created *domain.Report
}

func (r *fakeReportRepo) Create(_ context.Context, report *domain.Report) error {
	r.created = report
	return nil
}

type fakeBlockRepo struct {
	blocked   map[string]bool
	unblocked map[string]bool
}

func newFakeBlockRepo() *fakeBlockRepo {
	return &fakeBlockRepo{blocked: map[string]bool{}, unblocked: map[string]bool{}}
}

func (r *fakeBlockRepo) Block(_ context.Context, blocker, blocked string) error {
	r.blocked[blocker+">"+blocked] = true
	return nil
}

func (r *fakeBlockRepo) Unblock(_ context.Context, blocker, blocked string) error {
	r.unblocked[blocker+">"+blocked] = true
	return nil
}

func (r *fakeBlockRepo) ListBlockedIDs(_ context.Context, _ string) ([]string, error) {
	return []string{"u2", "u3"}, nil
}

func TestModerationCreateReport(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		report  *domain.Report
		wantErr error
	}{
		{"valid group report", &domain.Report{ContentType: domain.ReportContentGroup, Reason: domain.ReportReasonSpam}, nil},
		{"invalid content type", &domain.Report{ContentType: "boat", Reason: domain.ReportReasonSpam}, domain.ErrValidation},
		{"invalid reason", &domain.Report{ContentType: domain.ReportContentEvent, Reason: "lol"}, domain.ErrValidation},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			repo := &fakeReportRepo{}
			svc := NewModerationService(repo, newFakeBlockRepo())

			err := svc.CreateReport(context.Background(), tc.report)

			if tc.wantErr == nil {
				if err != nil {
					t.Fatalf("unexpected error: %v", err)
				}
				if repo.created == nil {
					t.Fatal("expected report to be persisted")
				}
				return
			}
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("error = %v, want %v", err, tc.wantErr)
			}
			if repo.created != nil {
				t.Fatal("invalid report should not be persisted")
			}
		})
	}
}

func TestModerationBlockUser(t *testing.T) {
	t.Parallel()

	t.Run("blocks another user", func(t *testing.T) {
		t.Parallel()
		blocks := newFakeBlockRepo()
		svc := NewModerationService(&fakeReportRepo{}, blocks)

		if err := svc.BlockUser(context.Background(), "u1", "u2"); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if !blocks.blocked["u1>u2"] {
			t.Fatal("expected block to be recorded")
		}
	})

	t.Run("cannot block self", func(t *testing.T) {
		t.Parallel()
		blocks := newFakeBlockRepo()
		svc := NewModerationService(&fakeReportRepo{}, blocks)

		err := svc.BlockUser(context.Background(), "u1", "u1")
		if !errors.Is(err, domain.ErrSelfBlock) {
			t.Fatalf("error = %v, want ErrSelfBlock", err)
		}
		if len(blocks.blocked) != 0 {
			t.Fatal("self-block should not be recorded")
		}
	})
}

func TestModerationListBlocked(t *testing.T) {
	t.Parallel()
	svc := NewModerationService(&fakeReportRepo{}, newFakeBlockRepo())

	ids, err := svc.ListBlocked(context.Background(), "u1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(ids) != 2 {
		t.Fatalf("blocked ids = %v, want 2", ids)
	}
}
