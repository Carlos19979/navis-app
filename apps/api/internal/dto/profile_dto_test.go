package dto

import (
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

func TestMeResponseFromDomain_TierEntitlements(t *testing.T) {
	t.Parallel()

	freeResp := MeResponseFromDomain(&domain.Profile{Plan: domain.PlanFree}, 1)
	plusResp := MeResponseFromDomain(&domain.Profile{Plan: domain.PlanPlus}, 1)
	proResp := MeResponseFromDomain(&domain.Profile{Plan: domain.PlanPro}, 1)
	free := freeResp.Entitlements
	plus := plusResp.Entitlements
	pro := proResp.Entitlements

	// Plus unlocks the "individual owner" bundle...
	if !plus.AnchorAlarm || !plus.MaintenanceSchedules || !plus.FullReadiness {
		t.Error("Plus should unlock anchor alarm + maintenance + full readiness")
	}
	// ...but not the Pro-only bundle.
	if plus.CostAnalytics || plus.SharedCoordination || plus.ExportPassport {
		t.Error("Plus should NOT unlock cost analytics / shared / passport")
	}
	if plus.MaxBoats != 2 {
		t.Errorf("Plus MaxBoats = %d, want 2", plus.MaxBoats)
	}
	// Free has none of the paid capabilities.
	if free.AnchorAlarm || free.FullReadiness || free.CostAnalytics {
		t.Error("Free should have no paid capabilities")
	}
	// Pro has everything.
	if !pro.CostAnalytics || !pro.SharedCoordination || !pro.AnchorAlarm {
		t.Error("Pro should unlock every capability")
	}
	if !proResp.IsPro || plusResp.IsPro || freeResp.IsPro {
		t.Error("IsPro must be true only for Pro")
	}
}
