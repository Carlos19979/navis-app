package handler

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func serveAuthCallback(t *testing.T, stores StoreLinks, query string) *httptest.ResponseRecorder {
	t.Helper()
	h := NewAuthCallbackHandler(stores)
	rec := httptest.NewRecorder()
	h.Callback(rec, httptest.NewRequest(http.MethodGet, "/auth/callback"+query, nil))
	return rec
}

// The point of the page: forward whatever GoTrue appended to the app, which is
// the only side that can finish the exchange.
func TestAuthCallbackHandler_ForwardsToTheAppScheme(t *testing.T) {
	t.Parallel()

	rec := serveAuthCallback(t, StoreLinks{}, "")

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	body := rec.Body.String()
	if !strings.Contains(body, "navis://login-callback") {
		t.Error("page does not hand the link to the app scheme")
	}
	// Both halves matter: PKCE returns ?code= in the query, the implicit flow
	// and every error return theirs in the fragment.
	for _, want := range []string{"window.location.search", "window.location.hash"} {
		if !strings.Contains(body, want) {
			t.Errorf("page does not forward %s", want)
		}
	}
}

// The URL carries a single-use auth token, so the page must not be cached,
// indexed, or leak the token through a Referer header.
func TestAuthCallbackHandler_ProtectsTheTokenInTheURL(t *testing.T) {
	t.Parallel()

	rec := serveAuthCallback(t, StoreLinks{}, "?code=abc123")

	for header, want := range map[string]string{
		"Cache-Control":   "no-store",
		"Referrer-Policy": "no-referrer",
		"X-Robots-Tag":    "noindex, nofollow",
	} {
		if got := rec.Header().Get(header); got != want {
			t.Errorf("%s = %q, want %q", header, got, want)
		}
	}
}

// The handler never reads the token: forwarding happens in the browser, so
// nothing from the request may end up rendered (or, by extension, logged).
func TestAuthCallbackHandler_DoesNotEchoTheRequest(t *testing.T) {
	t.Parallel()

	body := serveAuthCallback(t, StoreLinks{}, "?code=supersecrettoken").Body.String()

	if strings.Contains(body, "supersecrettoken") {
		t.Error("page echoes the auth token back into the HTML")
	}
}

// An expired or already-used link is the common failure, and it has to say so
// instead of silently trying to open an app with nothing to open.
func TestAuthCallbackHandler_ExplainsAnExpiredLink(t *testing.T) {
	t.Parallel()

	body := serveAuthCallback(t, StoreLinks{}, "").Body.String()

	for _, want := range []string{`id="expired"`, `id="ok"`, `id="plain"`} {
		if !strings.Contains(body, want) {
			t.Errorf("page is missing the %s state", want)
		}
	}
	if !strings.Contains(body, "error_code") && !strings.Contains(body, "'error'") {
		t.Error("page does not look at the GoTrue error parameters")
	}
}

func TestAuthCallbackHandler_StoreLinks(t *testing.T) {
	t.Parallel()

	t.Run("none configured renders no dead buttons", func(t *testing.T) {
		t.Parallel()

		body := serveAuthCallback(t, StoreLinks{}, "").Body.String()

		if strings.Contains(body, `href=""`) {
			t.Error("page renders an empty href")
		}
	})

	t.Run("configured ones are offered", func(t *testing.T) {
		t.Parallel()

		stores := StoreLinks{
			IOS:     "https://apps.apple.com/app/id123456789",
			Android: "https://play.google.com/store/apps/details?id=com.navis.navisMobile",
		}
		body := serveAuthCallback(t, stores, "").Body.String()

		if !strings.Contains(body, stores.IOS) || !strings.Contains(body, stores.Android) {
			t.Error("configured store links are not rendered")
		}
	})
}
