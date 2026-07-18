package dto

import (
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

func TestMeResponseFromDomain_AnchorAlarm(t *testing.T) {
	t.Parallel()

	pro := MeResponseFromDomain(&domain.Profile{Plan: domain.PlanPro}, 1)
	if !pro.Entitlements.AnchorAlarm {
		t.Error("expected Pro to have the anchor-alarm entitlement")
	}

	free := MeResponseFromDomain(&domain.Profile{Plan: domain.PlanFree}, 1)
	if free.Entitlements.AnchorAlarm {
		t.Error("expected Free to lack the anchor-alarm entitlement")
	}
}
