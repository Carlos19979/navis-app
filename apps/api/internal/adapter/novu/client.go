package novu

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
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
		http:    &http.Client{},
		logger:  logger,
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
	return c.doRequest(ctx, http.MethodPost, "/v1/events/trigger", body)
}

// EnsureSubscriber creates or updates a subscriber in Novu.
func (c *Client) EnsureSubscriber(ctx context.Context, subscriberID string) error {
	if c.apiKey == "" {
		return nil
	}

	body := map[string]any{
		"subscriberId": subscriberID,
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
