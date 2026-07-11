// Package testutil provides shared hand-written fakes for port interfaces,
// used across service and cron unit tests.
package testutil

import (
	"context"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// TriggeredWorkflow records a single FakeNotificationProvider.TriggerWorkflow call.
type TriggeredWorkflow struct {
	WorkflowID   string
	SubscriberID string
	Payload      map[string]any
}

// FakeNotificationProvider is an in-memory port.NotificationProvider that
// records TriggerWorkflow calls and optionally fails via TriggerFn.
type FakeNotificationProvider struct {
	// TriggerFn, when set, is called after recording and its error returned.
	TriggerFn func(ctx context.Context, workflowID, subscriberID string, payload map[string]any) error
	// Triggered holds every TriggerWorkflow call in order.
	Triggered []TriggeredWorkflow
}

var _ port.NotificationProvider = (*FakeNotificationProvider)(nil)

// TriggerWorkflow records the call and delegates to TriggerFn when set.
func (f *FakeNotificationProvider) TriggerWorkflow(ctx context.Context, workflowID, subscriberID string, payload map[string]any) error {
	f.Triggered = append(f.Triggered, TriggeredWorkflow{workflowID, subscriberID, payload})
	if f.TriggerFn != nil {
		return f.TriggerFn(ctx, workflowID, subscriberID, payload)
	}
	return nil
}

// EnsureSubscriber is a no-op.
func (f *FakeNotificationProvider) EnsureSubscriber(_ context.Context, _ string) error { return nil }

// SetPushToken is a no-op.
func (f *FakeNotificationProvider) SetPushToken(_ context.Context, _, _ string) error { return nil }

// RemovePushToken is a no-op.
func (f *FakeNotificationProvider) RemovePushToken(_ context.Context, _, _ string) error { return nil }

// SetPlanCall records a single FakeProfileRepo.SetPlan call.
type SetPlanCall struct {
	UserID string
	Plan   domain.Plan
}

// FakeProfileRepo is an in-memory port.ProfileRepository returning a fixed
// plan for every user (default: Pro) and recording SetPlan calls.
type FakeProfileRepo struct {
	// Plan is returned by GetOrCreate for every user. Empty means PlanPro.
	Plan domain.Plan
	// GetOrCreateErr, when set, is returned by GetOrCreate.
	GetOrCreateErr error
	// SetPlanCalls holds every SetPlan call in order.
	SetPlanCalls []SetPlanCall
}

var _ port.ProfileRepository = (*FakeProfileRepo)(nil)

// GetOrCreate returns a profile with the configured plan (default Pro).
func (f *FakeProfileRepo) GetOrCreate(_ context.Context, userID string) (*domain.Profile, error) {
	if f.GetOrCreateErr != nil {
		return nil, f.GetOrCreateErr
	}
	plan := f.Plan
	if plan == "" {
		plan = domain.PlanPro
	}
	return &domain.Profile{UserID: userID, Plan: plan}, nil
}

// SetPlan records the call and returns a profile with the new plan.
func (f *FakeProfileRepo) SetPlan(_ context.Context, userID string, plan domain.Plan) (*domain.Profile, error) {
	f.SetPlanCalls = append(f.SetPlanCalls, SetPlanCall{UserID: userID, Plan: plan})
	return &domain.Profile{UserID: userID, Plan: plan}, nil
}
