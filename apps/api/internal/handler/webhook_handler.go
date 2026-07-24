package handler

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
)

// RevenueCat entitlement identifiers that unlock each paid tier. They must match
// the entitlements configured in the RevenueCat dashboard.
const (
	entitlementPlus = "plus"
	entitlementPro  = "pro"
)

// planSetter is the profile service surface the webhook handler consumes.
type planSetter interface {
	SetPlan(ctx context.Context, userID string, plan domain.Plan) (*domain.Profile, error)
}

// WebhookHandler receives provider webhooks (currently RevenueCat) and is the
// source of truth for a user's paid plan. It is mounted OUTSIDE the JWT
// middleware and authenticated by a shared secret in the Authorization header.
type WebhookHandler struct {
	profiles planSetter
	secret   string
	logger   *slog.Logger
}

// NewWebhookHandler creates a new WebhookHandler.
func NewWebhookHandler(profiles planSetter, secret string, logger *slog.Logger) *WebhookHandler {
	return &WebhookHandler{profiles: profiles, secret: secret, logger: logger}
}

// revenueCatWebhook is the subset of the RevenueCat webhook payload we consume.
type revenueCatWebhook struct {
	Event struct {
		Type           string   `json:"type"`
		AppUserID      string   `json:"app_user_id"`
		EntitlementID  string   `json:"entitlement_id"`
		EntitlementIDs []string `json:"entitlement_ids"`
	} `json:"event"`
}

// RevenueCat handles POST /api/v1/webhooks/revenuecat. It maps a subscription
// lifecycle event to the user's plan: grant events set the purchased tier (Plus
// or Pro), expiration resets to Free, and informational events (cancellation,
// billing issues, tests) are acknowledged without changing the plan.
func (h *WebhookHandler) RevenueCat(w http.ResponseWriter, r *http.Request) {
	if !h.authorized(r) {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	var payload revenueCatWebhook
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		Error(w, http.StatusBadRequest, "invalid webhook body", "BAD_REQUEST")
		return
	}

	evt := payload.Event
	if evt.AppUserID == "" {
		Error(w, http.StatusBadRequest, "missing app_user_id", "BAD_REQUEST")
		return
	}

	plan, act := planForEvent(evt.Type, evt.EntitlementID, evt.EntitlementIDs)
	if !act {
		// A subscription event we couldn't map to a tier means the payload
		// carried no entitlement we recognise. We fail closed (plan unchanged)
		// rather than granting a paid tier from an ambiguous payload — but we
		// log loudly, because a RevenueCat payload-shape change would surface
		// here as a stream of these and must not silently drop upgrades.
		if isSubscriptionEvent(evt.Type) {
			h.logger.Warn("revenuecat webhook: subscription event without a recognised entitlement; plan unchanged",
				slog.String("app_user_id", evt.AppUserID),
				slog.String("event_type", evt.Type),
				slog.String("entitlement_id", evt.EntitlementID),
				slog.Any("entitlement_ids", evt.EntitlementIDs))
		}
		// Informational or unrelated-entitlement event: acknowledge, do nothing.
		JSON(w, http.StatusOK, map[string]string{"status": "ignored"})
		return
	}

	if _, err := h.profiles.SetPlan(r.Context(), evt.AppUserID, plan); err != nil {
		// A failed plan write must be retried by RevenueCat → return 5xx.
		h.logger.Error("revenuecat webhook: failed to set plan",
			slog.String("app_user_id", evt.AppUserID),
			slog.String("event_type", evt.Type),
			slog.String("error", err.Error()))
		MapDomainError(w, err)
		return
	}

	h.logger.Info("revenuecat webhook applied",
		slog.String("app_user_id", evt.AppUserID),
		slog.String("event_type", evt.Type),
		slog.String("plan", string(plan)))
	JSON(w, http.StatusOK, map[string]string{"status": "applied", "plan": string(plan)})
}

// authorized compares the request's Authorization header to the configured
// secret in constant time. An empty configured secret rejects every request —
// local dev must set REVENUECAT_WEBHOOK_SECRET in .env to exercise the webhook.
func (h *WebhookHandler) authorized(r *http.Request) bool {
	if h.secret == "" {
		h.logger.Warn("revenuecat webhook: no secret configured; rejecting request")
		return false
	}
	got := r.Header.Get("Authorization")
	return subtle.ConstantTimeCompare([]byte(got), []byte(h.secret)) == 1
}

// isSubscriptionEvent reports whether the event type is one that changes the
// plan when a recognised entitlement is present (a grant or an expiration), as
// opposed to informational events (CANCELLATION, BILLING_ISSUE, TEST, …). The
// handler uses it to decide when an unmapped event deserves a warning.
func isSubscriptionEvent(eventType string) bool {
	switch eventType {
	case "INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION",
		"NON_RENEWING_PURCHASE", "SUBSCRIPTION_EXTENDED", "EXPIRATION":
		return true
	default:
		return false
	}
}

// planForEvent maps a RevenueCat event to a target plan. The bool is false when
// the event should not change the plan.
func planForEvent(eventType, entitlementID string, entitlementIDs []string) (domain.Plan, bool) {
	tier := highestTier(entitlementID, entitlementIDs)
	if tier == "" {
		// No recognised entitlement on the payload → change nothing (fail
		// closed). Applies to grant and expiration events alike.
		return "", false
	}
	switch eventType {
	case "INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION",
		"NON_RENEWING_PURCHASE", "SUBSCRIPTION_EXTENDED":
		return tier, true
	case "EXPIRATION":
		return domain.PlanFree, true
	default:
		// CANCELLATION keeps access until EXPIRATION; BILLING_ISSUE, TRANSFER,
		// SUBSCRIBER_ALIAS, TEST, etc. do not change entitlement.
		return "", false
	}
}

// highestTier returns the top plan whose entitlement appears on the event, or
// "" if none of ours do. An event that carries no recognised entitlement yields
// "" (fail closed): rather than granting a paid tier from an ambiguous payload,
// the plan is left unchanged and the handler logs it, so a RevenueCat payload
// shape change is caught in the logs instead of silently giving away Pro.
func highestTier(entitlementID string, entitlementIDs []string) domain.Plan {
	ids := append([]string{entitlementID}, entitlementIDs...)
	best := domain.Plan("")
	for _, id := range ids {
		switch id {
		case entitlementPro:
			return domain.PlanPro // top tier — cannot be beaten
		case entitlementPlus:
			best = domain.PlanPlus
		}
	}
	return best
}
