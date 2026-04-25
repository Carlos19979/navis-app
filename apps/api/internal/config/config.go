package config

import (
	"os"
	"strings"
)

// Config holds the application configuration loaded from environment variables.
type Config struct {
	Port               string
	DatabaseURL        string
	SupabaseJWTSecret  string
	SupabaseURL        string
	LogLevel           string
	CORSAllowedOrigins []string
	FCMCredentialsFile string
}

// Load reads configuration from environment variables, applying defaults
// suitable for local development where values are not set.
func Load() *Config {
	return &Config{
		Port:               getEnv("PORT", "8080"),
		DatabaseURL:        getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/navis?sslmode=disable"),
		SupabaseJWTSecret:  getEnv("SUPABASE_JWT_SECRET", ""),
		SupabaseURL:        getEnv("SUPABASE_URL", "http://localhost:54321"),
		LogLevel:           getEnv("LOG_LEVEL", "debug"),
		CORSAllowedOrigins: strings.Split(getEnv("CORS_ALLOWED_ORIGINS", "http://localhost:3000"), ","),
		FCMCredentialsFile: getEnv("FCM_CREDENTIALS_FILE", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
