package service

import (
	"context"
	"io"
	"log/slog"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// captureProvider records TriggerWorkflow calls so tests can assert which
// workflow fired for which subscriber.
type captureProvider struct {
	triggers []capturedTrigger
}

type capturedTrigger struct {
	workflow   string
	subscriber string
}

func (c *captureProvider) TriggerWorkflow(_ context.Context, workflowID, subscriberID string, _ map[string]any) error {
	c.triggers = append(c.triggers, capturedTrigger{workflowID, subscriberID})
	return nil
}
func (c *captureProvider) EnsureSubscriber(context.Context, string) error        { return nil }
func (c *captureProvider) SetPushToken(context.Context, string, string) error    { return nil }
func (c *captureProvider) RemovePushToken(context.Context, string, string) error { return nil }

// testNotifier builds a synchronous Notifier (no Start) over a capture provider.
func testNotifier(p *captureProvider) *Notifier {
	return NewNotifier(p, nil, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

func TestNotifier_SendMany_ExcludesActorAndEmpty(t *testing.T) {
	t.Parallel()
	cap := &captureProvider{}
	n := testNotifier(cap)

	n.SendMany(context.Background(),
		[]string{"a", "", "b", "actor"}, "actor",
		WorkflowBookingCreated, "t", "b", "boat", "boat-1")

	if len(cap.triggers) != 2 {
		t.Fatalf("expected 2 triggers (a, b), got %d: %+v", len(cap.triggers), cap.triggers)
	}
	got := map[string]bool{}
	for _, tr := range cap.triggers {
		if tr.workflow != WorkflowBookingCreated {
			t.Errorf("workflow = %q, want %q", tr.workflow, WorkflowBookingCreated)
		}
		got[tr.subscriber] = true
	}
	if !got["a"] || !got["b"] {
		t.Errorf("expected recipients a and b, got %v", got)
	}
	if got["actor"] || got[""] {
		t.Errorf("actor/empty should be skipped, got %v", got)
	}
}

func TestBoatService_JoinByCode_NotifiesOwner(t *testing.T) {
	t.Parallel()
	cap := &captureProvider{}
	repo := &mockBoatRepo{
		shareCodeFn: func(_ context.Context, _ string) (string, string, error) {
			return "boat-1", "owner-1", nil
		},
		getAccessibleFn: func(_ context.Context, _, _ string) (*domain.Boat, error) {
			return &domain.Boat{ID: "boat-1"}, nil
		},
	}
	svc := NewBoatService(repo, nil, testNotifier(cap))

	if _, err := svc.JoinByCode(context.Background(), "user-2", "SHARE"); err != nil {
		t.Fatalf("JoinByCode: %v", err)
	}
	if len(cap.triggers) != 1 {
		t.Fatalf("expected 1 trigger, got %d: %+v", len(cap.triggers), cap.triggers)
	}
	if cap.triggers[0].workflow != WorkflowBoatMemberJoined {
		t.Errorf("workflow = %q, want %q", cap.triggers[0].workflow, WorkflowBoatMemberJoined)
	}
	if cap.triggers[0].subscriber != "owner-1" {
		t.Errorf("subscriber = %q, want owner-1", cap.triggers[0].subscriber)
	}
}

func TestBoatService_JoinByCode_OwnerJoiningOwnBoatDoesNotNotify(t *testing.T) {
	t.Parallel()
	cap := &captureProvider{}
	repo := &mockBoatRepo{
		shareCodeFn: func(_ context.Context, _ string) (string, string, error) {
			return "boat-1", "owner-1", nil
		},
		getByIDFn: func(_ context.Context, _, _ string) (*domain.Boat, error) {
			return &domain.Boat{ID: "boat-1"}, nil
		},
	}
	svc := NewBoatService(repo, nil, testNotifier(cap))

	// The owner opening their own share code is a no-op join → no notification.
	if _, err := svc.JoinByCode(context.Background(), "owner-1", "SHARE"); err != nil {
		t.Fatalf("JoinByCode: %v", err)
	}
	if len(cap.triggers) != 0 {
		t.Fatalf("expected no triggers, got %+v", cap.triggers)
	}
}
