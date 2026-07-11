package handler

import (
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

func TestWebhookAuthorization(t *testing.T) {
	t.Parallel()
	logger := slog.New(slog.DiscardHandler)
	body := `{"event":{"type":"TEST","app_user_id":"u1"}}`

	tests := []struct {
		name       string
		secret     string
		authHeader string
		wantStatus int
	}{
		{"empty configured secret always rejects", "", "", http.StatusUnauthorized},
		{"empty secret rejects even matching empty header", "", "anything", http.StatusUnauthorized},
		{"wrong secret rejects", "expected", "wrong", http.StatusUnauthorized},
		{"missing header rejects", "expected", "", http.StatusUnauthorized},
		{"matching secret accepts", "expected", "expected", http.StatusOK},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			h := NewWebhookHandler(nil, tc.secret, logger)
			req := httptest.NewRequest(http.MethodPost, "/api/v1/webhooks/revenuecat",
				strings.NewReader(body))
			if tc.authHeader != "" {
				req.Header.Set("Authorization", tc.authHeader)
			}
			rec := httptest.NewRecorder()

			h.RevenueCat(rec, req)

			if rec.Code != tc.wantStatus {
				t.Fatalf("status = %d, want %d (body: %s)", rec.Code, tc.wantStatus, rec.Body.String())
			}
		})
	}
}

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
