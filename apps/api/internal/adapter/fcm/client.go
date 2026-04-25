package fcm

import (
	"context"
	"log/slog"
)

// Client is a placeholder implementation of port.PushNotifier.
// It logs notifications instead of sending them via FCM.
// A real FCM integration will replace this later.
type Client struct {
	logger *slog.Logger
}

// New creates a new FCM placeholder client.
func New(logger *slog.Logger) *Client {
	return &Client{logger: logger}
}

// Send logs the notification details and returns nil.
func (c *Client) Send(ctx context.Context, userID, title, body string) error {
	c.logger.Info("push notification (placeholder)",
		slog.String("user_id", userID),
		slog.String("title", title),
		slog.String("body", body),
	)
	return nil
}
