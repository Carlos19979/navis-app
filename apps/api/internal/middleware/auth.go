package middleware

import (
	"context"
	"log/slog"
	"net/http"
	"strings"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

type contextKey string

const userIDKey contextKey = "userID"

// Auth returns a middleware that validates JWT tokens using JWKS (ES256) with
// HS256 fallback. It extracts the "sub" claim and injects the user ID into
// the request context.
func Auth(jwtSecret string, jwksURL string) func(http.Handler) http.Handler {
	var k keyfunc.Keyfunc
	if jwksURL != "" {
		var err error
		k, err = keyfunc.NewDefault([]string{jwksURL})
		if err != nil {
			slog.Warn("failed to initialize JWKS, falling back to HS256 only",
				slog.String("error", err.Error()))
		}
	}

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				writeAuthError(w, "missing authorization header")
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
				writeAuthError(w, "invalid authorization header format")
				return
			}

			tokenString := parts[1]

			keyFunc := func(token *jwt.Token) (any, error) {
				switch token.Method.(type) {
				case *jwt.SigningMethodHMAC:
					return []byte(jwtSecret), nil
				case *jwt.SigningMethodECDSA:
					if k != nil {
						return k.KeyfuncCtx(r.Context())(token)
					}
					return nil, jwt.ErrSignatureInvalid
				default:
					return nil, jwt.ErrSignatureInvalid
				}
			}

			token, err := jwt.Parse(tokenString, keyFunc)
			if err != nil || !token.Valid {
				writeAuthError(w, "invalid or expired token")
				return
			}

			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				writeAuthError(w, "invalid token claims")
				return
			}

			sub, ok := claims["sub"].(string)
			if !ok || sub == "" {
				writeAuthError(w, "missing sub claim in token")
				return
			}

			ctx := context.WithValue(r.Context(), userIDKey, sub)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func writeAuthError(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_, _ = w.Write([]byte(`{"error":{"message":"` + message + `","code":"UNAUTHORIZED"}}`))
}

// UserIDFromContext extracts the user ID from the request context.
func UserIDFromContext(ctx context.Context) (string, bool) {
	userID, ok := ctx.Value(userIDKey).(string)
	return userID, ok
}

// ContextWithUserID returns a context with the given user ID set. Test helper.
func ContextWithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userIDKey, userID)
}
