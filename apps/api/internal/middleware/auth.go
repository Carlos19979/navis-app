package middleware

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

// contextKey is an unexported type for context keys to prevent collisions.
type contextKey string

const userIDKey contextKey = "userID"

// Auth returns a middleware that validates JWT tokens from the Authorization header.
// It extracts the "sub" claim and injects the user ID into the request context.
func Auth(jwtSecret string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				http.Error(w, `{"error":{"message":"missing authorization header","code":"UNAUTHORIZED"}}`, http.StatusUnauthorized)
				return
			}

			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
				http.Error(w, `{"error":{"message":"invalid authorization header format","code":"UNAUTHORIZED"}}`, http.StatusUnauthorized)
				return
			}

			tokenString := parts[1]

			token, err := jwt.Parse(tokenString, func(token *jwt.Token) (any, error) {
				// Ensure the signing method is HMAC.
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, jwt.ErrSignatureInvalid
				}
				return []byte(jwtSecret), nil
			})
			if err != nil || !token.Valid {
				http.Error(w, `{"error":{"message":"invalid or expired token","code":"UNAUTHORIZED"}}`, http.StatusUnauthorized)
				return
			}

			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				http.Error(w, `{"error":{"message":"invalid token claims","code":"UNAUTHORIZED"}}`, http.StatusUnauthorized)
				return
			}

			sub, ok := claims["sub"].(string)
			if !ok || sub == "" {
				http.Error(w, `{"error":{"message":"missing sub claim in token","code":"UNAUTHORIZED"}}`, http.StatusUnauthorized)
				return
			}

			ctx := context.WithValue(r.Context(), userIDKey, sub)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// UserIDFromContext extracts the user ID from the request context.
// Returns the user ID and true if present, or an empty string and false if not.
func UserIDFromContext(ctx context.Context) (string, bool) {
	userID, ok := ctx.Value(userIDKey).(string)
	return userID, ok
}

// ContextWithUserID returns a context with the given user ID set. Test helper.
func ContextWithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userIDKey, userID)
}
