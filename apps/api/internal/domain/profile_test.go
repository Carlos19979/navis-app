package domain

import "testing"

func TestPlan_CanUseAnchorAlarm(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		plan Plan
		want bool
	}{
		{"free cannot", PlanFree, false},
		{"pro can", PlanPro, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			if got := tt.plan.CanUseAnchorAlarm(); got != tt.want {
				t.Errorf("CanUseAnchorAlarm() = %v, want %v", got, tt.want)
			}
		})
	}
}
