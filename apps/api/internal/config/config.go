package config

import (
	"os"
	"strings"
)

// Config holds the application configuration loaded from environment variables.
type Config struct {
	Port               string
	AppEnv             string
	DatabaseURL        string
	SupabaseJWTSecret  string
	SupabaseURL        string
	LogLevel           string
	CORSAllowedOrigins []string
	NovuAPIKey         string
	SentryDSN          string
	// RevenueCatWebhookSecret is the exact value RevenueCat is configured to send
	// in the Authorization header of webhook requests. Empty disables auth (local
	// dev only) — never leave empty in production.
	RevenueCatWebhookSecret string
}

// Load reads configuration from environment variables, applying defaults
// suitable for local development where values are not set.
func Load() *Config {
	return &Config{
		Port:               getEnv("PORT", "8080"),
		AppEnv:             getEnv("APP_ENV", "development"),
		DatabaseURL:        getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:54322/postgres?sslmode=disable"),
		SupabaseJWTSecret:  getEnv("SUPABASE_JWT_SECRET", ""),
		SupabaseURL:        getEnv("SUPABASE_URL", "http://localhost:54321"),
		LogLevel:           getEnv("LOG_LEVEL", "debug"),
		CORSAllowedOrigins: strings.Split(getEnv("CORS_ALLOWED_ORIGINS", "http://localhost:3000"), ","),
		NovuAPIKey:         getEnv("NOVU_API_KEY", ""),
		SentryDSN:          getEnv("SENTRY_DSN", ""),

		RevenueCatWebhookSecret: getEnv("REVENUECAT_WEBHOOK_SECRET", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
