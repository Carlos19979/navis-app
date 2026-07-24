package handler

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestLegalPagesRender guards the standalone legal pages App Store Connect links
// to. Beyond a 200 + valid HTML shell, it asserts the elements Apple's review
// requires on a subscription app's legal pages: a real contact, the exact
// subscription prices, and account-deletion instructions.
func TestLegalPagesRender(t *testing.T) {
	t.Parallel()
	h := NewLegalHandler()

	tests := []struct {
		name     string
		serve    func(http.ResponseWriter, *http.Request)
		mustHave []string
	}{
		{
			name:  "privacy",
			serve: h.Privacy,
			mustHave: []string{
				"<!DOCTYPE html>",
				"carloscode23@icloud.com", // real contact
				"Carlos Pérez Martínez",   // real controller identity
				"elimina",                 // account deletion (ES)
				"delete your account",     // account deletion (EN)
			},
		},
		{
			name:  "terms",
			serve: h.Terms,
			mustHave: []string{
				"<!DOCTYPE html>",
				"carloscode23@icloud.com",
				// Exact subscription prices Apple reviewers cross-check.
				"4,99", "39,99", "8,99", "69,99",
				"€4.99", "€39.99", "€8.99", "€69.99",
				"cancel", // subscription cancellation terms
			},
		},
		{
			// Apple's Support URL must be a working page with a real contact and
			// help content — not a bare mailto.
			name:  "support",
			serve: h.Support,
			mustHave: []string{
				"<!DOCTYPE html>",
				"carloscode23@icloud.com", // contact
				"cancel",                  // how to cancel a subscription (EN)
				"Delete account",          // account deletion path (EN)
				`href="/legal/privacy"`,   // links to the legal pages
				"Frequently asked questions",
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			rec := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodGet, "/legal/"+tc.name, nil)

			tc.serve(rec, req)

			if rec.Code != http.StatusOK {
				t.Fatalf("status = %d, want 200", rec.Code)
			}
			if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "text/html") {
				t.Errorf("content-type = %q, want text/html", ct)
			}
			body := rec.Body.String()
			for _, want := range tc.mustHave {
				if !strings.Contains(body, want) {
					t.Errorf("page is missing required content %q", want)
				}
			}
		})
	}
}
