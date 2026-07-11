package config

import (
	"errors"
	"fmt"
	"os"
	"strings"
)

// devDatabaseURL is the local-development default. It must never be used in
// production — Validate rejects it there.
const devDatabaseURL = "postgres://postgres:postgres@localhost:54322/postgres?sslmode=disable"

// Config holds the application configuration loaded from environment variables.
type Config struct {
	Port              string
	AppEnv            string
	DatabaseURL       string
	SupabaseJWTSecret string
	SupabaseURL       string
	// SupabaseServiceRoleKey authorizes privileged admin operations (account
	// deletion: auth.users + Storage). Required in production.
	SupabaseServiceRoleKey string
	LogLevel               string
	CORSAllowedOrigins     []string
	NovuAPIKey             string
	SentryDSN              string
	// RevenueCatWebhookSecret is the exact value RevenueCat is configured to send
	// in the Authorization header of webhook requests. Required in production;
	// requests are rejected with 401 when empty.
	RevenueCatWebhookSecret string
}

// Load reads configuration from environment variables, applying defaults
// suitable for local development where values are not set.
func Load() *Config {
	appEnv := getEnv("APP_ENV", "development")

	defaultLogLevel := "debug"
	if appEnv == "production" {
		defaultLogLevel = "info"
	}

	return &Config{
		Port:                   getEnv("PORT", "8080"),
		AppEnv:                 appEnv,
		DatabaseURL:            getEnv("DATABASE_URL", devDatabaseURL),
		SupabaseJWTSecret:      getEnv("SUPABASE_JWT_SECRET", ""),
		SupabaseURL:            getEnv("SUPABASE_URL", "http://localhost:54321"),
		SupabaseServiceRoleKey: getEnv("SUPABASE_SERVICE_ROLE_KEY", ""),
		LogLevel:               getEnv("LOG_LEVEL", defaultLogLevel),
		CORSAllowedOrigins:     strings.Split(getEnv("CORS_ALLOWED_ORIGINS", "http://localhost:3000"), ","),
		NovuAPIKey:             getEnv("NOVU_API_KEY", ""),
		SentryDSN:              getEnv("SENTRY_DSN", ""),

		RevenueCatWebhookSecret: getEnv("REVENUECAT_WEBHOOK_SECRET", ""),
	}
}

// IsProduction reports whether the app runs with production settings.
func (c *Config) IsProduction() bool {
	return c.AppEnv == "production"
}

// Validate checks that the configuration is safe to boot with. In production it
// fails fast on missing or development-only values so the server never starts
// with auth disabled or an unencrypted database connection.
func (c *Config) Validate() error {
	if !c.IsProduction() {
		return nil
	}

	var errs []error
	if c.SupabaseJWTSecret == "" {
		errs = append(errs, errors.New("SUPABASE_JWT_SECRET must be set in production"))
	}
	if c.RevenueCatWebhookSecret == "" {
		errs = append(errs, errors.New("REVENUECAT_WEBHOOK_SECRET must be set in production"))
	}
	if c.SupabaseServiceRoleKey == "" {
		errs = append(errs, errors.New("SUPABASE_SERVICE_ROLE_KEY must be set in production (account deletion)"))
	}
	if c.DatabaseURL == devDatabaseURL {
		errs = append(errs, errors.New("DATABASE_URL must be set in production (local dev default detected)"))
	} else if strings.Contains(c.DatabaseURL, "sslmode=disable") {
		errs = append(errs, errors.New("DATABASE_URL must require TLS in production (sslmode=disable detected)"))
	}
	if len(errs) > 0 {
		return fmt.Errorf("invalid production config: %w", errors.Join(errs...))
	}
	return nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
