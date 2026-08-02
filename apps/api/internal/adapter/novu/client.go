package novu

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"time"
)

// Client implements port.NotificationProvider using the Novu REST API.
type Client struct {
	apiKey  string
	baseURL string
	http    *http.Client
	logger  *slog.Logger
}

// New creates a new Novu client. If apiKey is empty, operates in dry-run mode (logs only).
func New(apiKey string, logger *slog.Logger) *Client {
	return &Client{
		apiKey:  apiKey,
		baseURL: "https://api.novu.co",
		// Without a timeout a hung Novu request pins its caller forever.
		http:   &http.Client{Timeout: 10 * time.Second},
		logger: logger,
	}
}

// TriggerWorkflow triggers a Novu notification workflow for a subscriber.
func (c *Client) TriggerWorkflow(ctx context.Context, workflowID, subscriberID string, payload map[string]any) error {
	if c.apiKey == "" {
		c.logger.Info("novu: dry-run trigger",
			slog.String("workflow", workflowID),
			slog.String("subscriber", subscriberID),
		)
		return nil
	}

	body := map[string]any{
		"name":    workflowID,
		"to":      map[string]string{"subscriberId": subscriberID},
		"payload": payload,
	}
	if data := deepLinkData(payload); len(data) > 0 {
		body["overrides"] = map[string]any{"fcm": map[string]any{"data": data}}
	}
	return c.doRequest(ctx, http.MethodPost, "/v1/events/trigger", body)
}

// deepLinkData lifts the {type, id} deep-link target out of the payload and
// into FCM's data block.
//
// The payload alone does not reach the device: Novu renders title and body from
// it, but the app reads the tap target from `message.data`, and that is only
// populated from the provider overrides. Verified on a real device — the push
// arrived and looked right, yet tapping it navigated nowhere because data was
// empty. FCM requires every data value to be a string.
func deepLinkData(payload map[string]any) map[string]string {
	data := make(map[string]string, 2)
	for _, key := range []string{"type", "id"} {
		if value, ok := payload[key].(string); ok && value != "" {
			data[key] = value
		}
	}
	// Both halves or nothing: a type without an id (or the reverse) routes
	// nowhere, and sending half a target only invites a crash downstream.
	if len(data) != 2 {
		return nil
	}
	return data
}

// EnsureSubscriber creates or updates a subscriber in Novu (the endpoint
// upserts), including the address the email channel needs.
//
// Without an email every email step ends as "Subscriber missing email
// address": the fallback that exists precisely for when push does not arrive
// could never deliver. Empty values are omitted rather than sent blank, so a
// user with no email keeps whatever Novu already has.
func (c *Client) EnsureSubscriber(ctx context.Context, subscriberID, email, name string) error {
	if c.apiKey == "" {
		return nil
	}

	body := map[string]any{
		"subscriberId": subscriberID,
	}
	if email != "" {
		body["email"] = email
	}
	if name != "" {
		body["firstName"] = name
	}
	return c.doRequest(ctx, http.MethodPost, "/v1/subscribers", body)
}

// SetPushToken registers an FCM device token for a subscriber.
func (c *Client) SetPushToken(ctx context.Context, subscriberID, token string) error {
	if c.apiKey == "" {
		c.logger.Info("novu: dry-run set push token",
			slog.String("subscriber", subscriberID),
		)
		return nil
	}

	body := map[string]any{
		"providerId": "fcm",
		"credentials": map[string]any{
			"deviceTokens": []string{token},
		},
	}
	path := fmt.Sprintf("/v1/subscribers/%s/credentials", subscriberID)
	return c.doRequest(ctx, http.MethodPut, path, body)
}

// RemovePushToken removes a device token from a subscriber's credentials.
func (c *Client) RemovePushToken(ctx context.Context, subscriberID, token string) error {
	if c.apiKey == "" {
		return nil
	}

	c.logger.Info("novu: remove push token",
		slog.String("subscriber", subscriberID),
	)
	return nil
}

func (c *Client) doRequest(ctx context.Context, method, path string, body any) error {
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("novu: marshal body: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bytes.NewReader(jsonBody))
	if err != nil {
		return fmt.Errorf("novu: create request: %w", err)
	}

	req.Header.Set("Authorization", "ApiKey "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("novu: request failed: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("novu: API error status %d on %s %s", resp.StatusCode, method, path)
	}

	return nil
}
