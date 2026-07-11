package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const testSecret = "test-secret-key-for-hs256"

func signedToken(t *testing.T, secret string, method jwt.SigningMethod, claims jwt.MapClaims) string {
	t.Helper()
	token := jwt.NewWithClaims(method, claims)
	s, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("signing token: %v", err)
	}
	return s
}

func validClaims() jwt.MapClaims {
	return jwt.MapClaims{
		"sub": "user-123",
		"exp": time.Now().Add(time.Hour).Unix(),
	}
}

// authRequest runs a request with the given Authorization header through the
// Auth middleware and returns the recorder plus the user ID seen downstream.
func authRequest(t *testing.T, jwtSecret, authHeader string) (*httptest.ResponseRecorder, string) {
	t.Helper()
	var gotUserID string
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUserID, _ = UserIDFromContext(r.Context())
		w.WriteHeader(http.StatusOK)
	})

	handler := Auth(jwtSecret, "")(next)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/boats", nil)
	if authHeader != "" {
		req.Header.Set("Authorization", authHeader)
	}
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec, gotUserID
}

func TestAuth_ValidToken_InjectsUserID(t *testing.T) {
	t.Parallel()
	token := signedToken(t, testSecret, jwt.SigningMethodHS256, validClaims())

	rec, userID := authRequest(t, testSecret, "Bearer "+token)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
	if userID != "user-123" {
		t.Fatalf("expected user-123 in context, got %q", userID)
	}
}

func TestAuth_MissingHeader_Returns401(t *testing.T) {
	t.Parallel()
	rec, _ := authRequest(t, testSecret, "")
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", rec.Code)
	}
}

func TestAuth_EmptyConfiguredSecret_RejectsEmptySignedToken(t *testing.T) {
	t.Parallel()
	// A token signed with the empty string must NOT validate when the server
	// secret is also empty — this was the auth-bypass scenario.
	forged := signedToken(t, "", jwt.SigningMethodHS256, validClaims())

	rec, _ := authRequest(t, "", "Bearer "+forged)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for empty-secret token, got %d", rec.Code)
	}
}

func TestAuth_AlgorithmConfusion_NoneRejected(t *testing.T) {
	t.Parallel()
	token := jwt.NewWithClaims(jwt.SigningMethodNone, validClaims())
	s, err := token.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("signing none token: %v", err)
	}

	rec, _ := authRequest(t, testSecret, "Bearer "+s)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for alg=none token, got %d", rec.Code)
	}
}

func TestAuth_WrongSecret_Returns401(t *testing.T) {
	t.Parallel()
	token := signedToken(t, "other-secret", jwt.SigningMethodHS256, validClaims())

	rec, _ := authRequest(t, testSecret, "Bearer "+token)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for wrong-secret token, got %d", rec.Code)
	}
}

func TestAuth_ExpiredToken_Returns401(t *testing.T) {
	t.Parallel()
	claims := jwt.MapClaims{
		"sub": "user-123",
		"exp": time.Now().Add(-time.Hour).Unix(),
	}
	token := signedToken(t, testSecret, jwt.SigningMethodHS256, claims)

	rec, _ := authRequest(t, testSecret, "Bearer "+token)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for expired token, got %d", rec.Code)
	}
}

func TestAuth_TokenWithoutExpiry_Returns401(t *testing.T) {
	t.Parallel()
	token := signedToken(t, testSecret, jwt.SigningMethodHS256, jwt.MapClaims{
		"sub": "user-123",
	})

	rec, _ := authRequest(t, testSecret, "Bearer "+token)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for token without exp claim, got %d", rec.Code)
	}
}

func TestAuth_MissingSubClaim_Returns401(t *testing.T) {
	t.Parallel()
	token := signedToken(t, testSecret, jwt.SigningMethodHS256, jwt.MapClaims{
		"exp": time.Now().Add(time.Hour).Unix(),
	})

	rec, _ := authRequest(t, testSecret, "Bearer "+token)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for token without sub claim, got %d", rec.Code)
	}
}
