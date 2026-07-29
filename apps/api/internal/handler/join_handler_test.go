package handler

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func serveJoin(t *testing.T, stores StoreLinks, query string) *httptest.ResponseRecorder {
	t.Helper()
	h := NewJoinHandler(stores)
	rec := httptest.NewRecorder()
	h.Join(rec, httptest.NewRequest(http.MethodGet, "/join"+query, nil))
	return rec
}

// The whole point of the page: hand the recipient a way into the app.
func TestJoinHandler_OffersTheAppAndTheCode(t *testing.T) {
	t.Parallel()

	rec := serveJoin(t, StoreLinks{}, "?code=EZHT4CNG")

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	body := rec.Body.String()
	for _, want := range []string{"EZHT4CNG", "navis://join?code=EZHT4CNG"} {
		if !strings.Contains(body, want) {
			t.Errorf("page does not contain %q", want)
		}
	}
	if got := rec.Header().Get("Cache-Control"); got != "no-store" {
		t.Errorf("Cache-Control = %q, want no-store", got)
	}
}

// With no store links configured (the app is not published yet) the page must
// not render empty download buttons that go nowhere.
func TestJoinHandler_NoStoreLinksMeansNoDeadButtons(t *testing.T) {
	t.Parallel()

	body := serveJoin(t, StoreLinks{}, "?code=EZHT4CNG").Body.String()

	if strings.Contains(body, `href=""`) {
		t.Error("page renders an empty href")
	}
	if !strings.Contains(body, "App Store") {
		t.Error("page should explain the app is not published yet")
	}
}

func TestJoinHandler_ShowsStoreLinksWhenConfigured(t *testing.T) {
	t.Parallel()

	stores := StoreLinks{
		IOS:     "https://apps.apple.com/app/id123456789",
		Android: "https://play.google.com/store/apps/details?id=com.navis.navisMobile",
	}
	body := serveJoin(t, stores, "?code=EZHT4CNG").Body.String()

	if !strings.Contains(body, stores.IOS) || !strings.Contains(body, stores.Android) {
		t.Error("configured store links must be rendered")
	}
}

// A code is user-supplied input reflected into HTML. Anything that is not a
// share code is dropped rather than echoed.
func TestJoinHandler_RejectsCodesThatAreNotCodes(t *testing.T) {
	t.Parallel()

	for name, query := range map[string]string{
		"missing":    "",
		"empty":      "?code=",
		"too short":  "?code=AB",
		"script tag": "?code=%3Cscript%3Ealert(1)%3C/script%3E",
		"quote out":  `?code=%22%3E%3Cimg+src%3Dx+onerror%3Dalert(1)%3E`,
	} {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			body := serveJoin(t, StoreLinks{}, query).Body.String()
			if strings.Contains(body, "<script>alert") || strings.Contains(body, "onerror=alert") {
				t.Fatal("unescaped user input reached the page")
			}
			if !strings.Contains(body, "no lleva un c") {
				t.Error("expected the invalid-link message")
			}
		})
	}
}

// Lowercase is what a user retyping a code by hand produces.
func TestJoinHandler_NormalisesCase(t *testing.T) {
	t.Parallel()

	body := serveJoin(t, StoreLinks{}, "?code=ezht4cng").Body.String()

	if !strings.Contains(body, "EZHT4CNG") {
		t.Error("expected the code upper-cased")
	}
}
