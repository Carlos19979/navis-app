package config

import (
	"strings"
	"testing"
)

func productionConfig() *Config {
	return &Config{
		AppEnv:                  "production",
		DatabaseURL:             "postgres://app:secret@db.example.com:5432/navis?sslmode=require",
		SupabaseJWTSecret:       "a-real-secret",
		RevenueCatWebhookSecret: "a-webhook-secret",
	}
}

func TestValidate_Development_AllowsEmptySecrets(t *testing.T) {
	t.Parallel()
	cfg := &Config{AppEnv: "development", DatabaseURL: devDatabaseURL}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("development config should validate, got: %v", err)
	}
}

func TestValidate_Production_Valid(t *testing.T) {
	t.Parallel()
	if err := productionConfig().Validate(); err != nil {
		t.Fatalf("valid production config should validate, got: %v", err)
	}
}

func TestValidate_Production_Failures(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name    string
		mutate  func(*Config)
		wantMsg string
	}{
		{
			name:    "empty JWT secret",
			mutate:  func(c *Config) { c.SupabaseJWTSecret = "" },
			wantMsg: "SUPABASE_JWT_SECRET",
		},
		{
			name:    "empty webhook secret",
			mutate:  func(c *Config) { c.RevenueCatWebhookSecret = "" },
			wantMsg: "REVENUECAT_WEBHOOK_SECRET",
		},
		{
			name:    "dev default database URL",
			mutate:  func(c *Config) { c.DatabaseURL = devDatabaseURL },
			wantMsg: "DATABASE_URL",
		},
		{
			name: "sslmode disabled",
			mutate: func(c *Config) {
				c.DatabaseURL = "postgres://app:secret@db.example.com:5432/navis?sslmode=disable"
			},
			wantMsg: "TLS",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			cfg := productionConfig()
			tt.mutate(cfg)
			err := cfg.Validate()
			if err == nil {
				t.Fatal("expected validation error, got nil")
			}
			if !strings.Contains(err.Error(), tt.wantMsg) {
				t.Fatalf("error %q does not mention %q", err, tt.wantMsg)
			}
		})
	}
}

func TestValidate_Production_AggregatesAllErrors(t *testing.T) {
	t.Parallel()
	cfg := &Config{AppEnv: "production", DatabaseURL: devDatabaseURL}
	err := cfg.Validate()
	if err == nil {
		t.Fatal("expected validation error, got nil")
	}
	for _, want := range []string{"SUPABASE_JWT_SECRET", "REVENUECAT_WEBHOOK_SECRET", "DATABASE_URL"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("aggregated error missing %q: %v", want, err)
		}
	}
}
