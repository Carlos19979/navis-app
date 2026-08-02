package novu

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

// newTestClient points a client at a stub server and captures the request body
// of the single call the test makes.
func newTestClient(t *testing.T, captured *map[string]any) *Client {
	t.Helper()

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw, _ := io.ReadAll(r.Body)
		body := map[string]any{}
		if err := json.Unmarshal(raw, &body); err != nil {
			t.Errorf("request body is not JSON: %v", err)
		}
		*captured = body
		w.WriteHeader(http.StatusCreated)
	}))
	t.Cleanup(srv.Close)

	c := New("test-key", slog.New(slog.NewTextHandler(io.Discard, nil)))
	c.baseURL = srv.URL
	return c
}

// The deep-link target has to travel in the provider overrides: the payload
// alone renders the text, but the app reads the tap target from FCM's data
// block. Without this a push arrives, looks right, and opens nothing.
func TestTriggerWorkflow_SendsDeepLinkAsFCMData(t *testing.T) {
	t.Parallel()

	var got map[string]any
	c := newTestClient(t, &got)

	err := c.TriggerWorkflow(context.Background(), "reminders", "user-1", map[string]any{
		"title": "Documento a punto de caducar",
		"body":  "Tu seguro caduca en 5 dias.",
		"type":  "document",
		"id":    "doc-1",
	})
	if err != nil {
		t.Fatalf("TriggerWorkflow: %v", err)
	}

	overrides, ok := got["overrides"].(map[string]any)
	if !ok {
		t.Fatalf("no overrides in body: %v", got)
	}
	fcm, ok := overrides["fcm"].(map[string]any)
	if !ok {
		t.Fatalf("no fcm overrides: %v", overrides)
	}
	data, ok := fcm["data"].(map[string]any)
	if !ok {
		t.Fatalf("no fcm data: %v", fcm)
	}
	if data["type"] != "document" || data["id"] != "doc-1" {
		t.Errorf("data = %v, want document / doc-1", data)
	}

	// The payload still carries everything, since that is what renders the text.
	payload, ok := got["payload"].(map[string]any)
	if !ok || payload["title"] != "Documento a punto de caducar" {
		t.Errorf("payload lost its content: %v", got["payload"])
	}
}

// A notification with nothing to open must not ship a half-built target.
func TestTriggerWorkflow_OmitsOverridesWithoutADeepLink(t *testing.T) {
	t.Parallel()

	cases := map[string]map[string]any{
		"no target":  {"title": "Hola", "body": "Sin destino"},
		"empty pair": {"title": "Hola", "type": "", "id": ""},
		"type only":  {"title": "Hola", "type": "document"},
		"id only":    {"title": "Hola", "id": "doc-1"},
	}

	for name, payload := range cases {
		t.Run(name, func(t *testing.T) {
			t.Parallel()

			var got map[string]any
			c := newTestClient(t, &got)

			if err := c.TriggerWorkflow(context.Background(), "reminders", "user-1", payload); err != nil {
				t.Fatalf("TriggerWorkflow: %v", err)
			}
			if _, present := got["overrides"]; present {
				t.Errorf("overrides sent for a payload with no deep link: %v", got["overrides"])
			}
		})
	}
}

// Dry-run must stay silent: with no API key there is nothing to call.
func TestTriggerWorkflow_DryRunMakesNoRequest(t *testing.T) {
	t.Parallel()

	var got map[string]any
	c := newTestClient(t, &got)
	c.apiKey = ""

	if err := c.TriggerWorkflow(context.Background(), "reminders", "user-1",
		map[string]any{"title": "Hola", "type": "boat", "id": "b1"}); err != nil {
		t.Fatalf("TriggerWorkflow: %v", err)
	}
	if got != nil {
		t.Errorf("dry-run reached the server: %v", got)
	}
}
