package domain

import "testing"

// TestPlan_Tiers pins the Free / Plus / Pro capability matrix so a tier change
// is a deliberate edit, not an accident.
func TestPlan_Tiers(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		got  func(Plan) any
		free any
		plus any
		pro  any
	}{
		{"MaxBoats", func(p Plan) any { return p.MaxBoats() }, 1, 2, 5},
		{"ReminderDocLimit", func(p Plan) any { return p.ReminderDocLimit() }, 1, Unlimited, Unlimited},
		{"AttachmentLimit", func(p Plan) any { return p.AttachmentLimit() }, 1, Unlimited, Unlimited},
		{"GalleryLimit", func(p Plan) any { return p.GalleryLimit() }, 1, 10, 10},
		{"MaintenanceSchedules", func(p Plan) any { return p.CanUseMaintenanceSchedules() }, false, true, true},
		{"FullReadiness", func(p Plan) any { return p.CanUseFullReadiness() }, false, true, true},
		{"AnchorAlarm", func(p Plan) any { return p.CanUseAnchorAlarm() }, false, true, true},
		{"CostAnalytics", func(p Plan) any { return p.CanUseCostAnalytics() }, false, false, true},
		{"AnomalyAlerts", func(p Plan) any { return p.CanUseAnomalyAlerts() }, false, false, true},
		{"SharedCoordination", func(p Plan) any { return p.CanUseSharedCoordination() }, false, false, true},
		{"ExportPassport", func(p Plan) any { return p.CanExportPassport() }, false, false, true},
		{"CreateGroups", func(p Plan) any { return p.CanCreateGroups() }, false, false, true},
		{"IsPro", func(p Plan) any { return p.IsPro() }, false, false, true},
		{"IsPaid", func(p Plan) any { return p.IsPaid() }, false, true, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			if got := tt.got(PlanFree); got != tt.free {
				t.Errorf("%s(free) = %v, want %v", tt.name, got, tt.free)
			}
			if got := tt.got(PlanPlus); got != tt.plus {
				t.Errorf("%s(plus) = %v, want %v", tt.name, got, tt.plus)
			}
			if got := tt.got(PlanPro); got != tt.pro {
				t.Errorf("%s(pro) = %v, want %v", tt.name, got, tt.pro)
			}
		})
	}
}

func TestPlan_Valid(t *testing.T) {
	t.Parallel()
	for _, p := range []Plan{PlanFree, PlanPlus, PlanPro} {
		if !p.Valid() {
			t.Errorf("%q should be valid", p)
		}
	}
	if Plan("enterprise").Valid() {
		t.Error("unknown plan should be invalid")
	}
}
