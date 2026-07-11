package handler

import (
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

func TestPlanForEvent(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name       string
		eventType  string
		entID      string
		entIDs     []string
		wantPlan   domain.Plan
		wantAction bool
	}{
		{"initial purchase grants pro", "INITIAL_PURCHASE", "pro", nil, domain.PlanPro, true},
		{"renewal grants pro", "RENEWAL", "", []string{"pro"}, domain.PlanPro, true},
		{"uncancellation grants pro", "UNCANCELLATION", "pro", nil, domain.PlanPro, true},
		{"expiration resets to free", "EXPIRATION", "pro", nil, domain.PlanFree, true},
		{"cancellation keeps access (no-op)", "CANCELLATION", "pro", nil, "", false},
		{"billing issue is a no-op", "BILLING_ISSUE", "pro", nil, "", false},
		{"test event is a no-op", "TEST", "", nil, "", false},
		{"grant for other entitlement ignored", "INITIAL_PURCHASE", "some_other", nil, "", false},
		{"grant with no entitlement fields fails open", "INITIAL_PURCHASE", "", nil, domain.PlanPro, true},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			gotPlan, gotAction := planForEvent(tc.eventType, tc.entID, tc.entIDs)
			if gotAction != tc.wantAction {
				t.Fatalf("action = %v, want %v", gotAction, tc.wantAction)
			}
			if gotAction && gotPlan != tc.wantPlan {
				t.Errorf("plan = %q, want %q", gotPlan, tc.wantPlan)
			}
		})
	}
}
