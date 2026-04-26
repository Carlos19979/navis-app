package fcm

import (
	"context"
	"log/slog"
)

// Client is a placeholder implementation of port.PushNotifier.
// It logs notifications instead of sending them via FCM.
// Replace with a real FCM integration when Firebase credentials are available.
type Client struct {
	logger *slog.Logger
}

// New creates a new FCM placeholder client.
func New(logger *slog.Logger) *Client {
	return &Client{logger: logger}
}

// Send logs the notification details and returns nil.
func (c *Client) Send(ctx context.Context, deviceToken, title, body string) error {
	c.logger.Info("push notification (placeholder)",
		slog.String("device_token", deviceToken),
		slog.String("title", title),
		slog.String("body", body),
	)
	return nil
}
