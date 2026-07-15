.PHONY: help dev stop api-run api-build api-test api-lint api-dev mobile-run mobile-run-emu mobile-test mobile-lint mobile-analyze mobile-format mobile-build-apk mobile-build-ios mobile-codegen db-start db-stop db-reset db-migrate install-hooks lint

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# === Local Development ===

dev: db-start ## Start Supabase + Go API for local development
	docker compose up -d

stop: ## Stop all services
	docker compose down
	cd packages/supabase && supabase stop

# === Supabase (Database + Auth + Storage) ===

db-start: ## Start Supabase local (Postgres, Auth, Storage, Dashboard)
	cd packages/supabase && supabase start

db-stop: ## Stop Supabase local
	cd packages/supabase && supabase stop

db-reset: ## Reset local Supabase database and reseed
	cd packages/supabase && supabase db reset

db-migrate: ## Apply pending migrations
	cd packages/supabase && supabase migration up

# === Go API ===

api-run: ## Run Go API server
	cd apps/api && go run cmd/server/main.go

api-build: ## Build Go API binary
	cd apps/api && go build -o bin/server cmd/server/main.go

api-test: ## Run Go tests
	cd apps/api && go test ./...

api-lint: ## Run Go linter
	cd apps/api && golangci-lint run

api-dev: ## Run Go API with hot reload (air)
	cd apps/api && air

# === Flutter ===

# SENTRY_DSN is read from the environment (set it in your shell or .env).
# It is optional for dev — leave unset to run without Sentry.
mobile-run: ## Run Flutter app on connected device
	cd apps/mobile && flutter run --dart-define=SENTRY_DSN=$(SENTRY_DSN)

mobile-run-emu: ## Run Flutter app on Android emulator with local backend
	cd apps/mobile && flutter run --dart-define=API_URL=http://10.0.2.2:8080 --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SENTRY_DSN=$(SENTRY_DSN)

mobile-test: ## Run Flutter tests
	cd apps/mobile && flutter test

mobile-lint: ## Run Flutter analyzer
	cd apps/mobile && flutter analyze --fatal-infos

mobile-format: ## Format Flutter code
	cd apps/mobile && dart format --line-length=80 lib/ test/

mobile-analyze: ## Run Flutter analyze (alias)
	cd apps/mobile && flutter analyze

# Release builds require every production secret. `make` errors out naming
# the first missing one instead of shipping a build wired to dev defaults.
# Provide them via env/CI secrets:
#   API_URL SUPABASE_URL SUPABASE_ANON_KEY SENTRY_DSN APP_VERSION
#   REVENUECAT_IOS_KEY (iOS) / REVENUECAT_ANDROID_KEY (Android)
define require
$(if $($(1)),,$(error $(1) is required for a release build — set it in the environment))
endef

RELEASE_COMMON = \
	--dart-define=ENVIRONMENT=production \
	--dart-define=API_URL=$(API_URL) \
	--dart-define=SUPABASE_URL=$(SUPABASE_URL) \
	--dart-define=SUPABASE_ANON_KEY=$(SUPABASE_ANON_KEY) \
	--dart-define=SENTRY_DSN=$(SENTRY_DSN) \
	--dart-define=APP_VERSION=$(APP_VERSION)

mobile-build-apk: ## Build a production Android APK (requires release env vars)
	$(call require,API_URL)
	$(call require,SUPABASE_URL)
	$(call require,SUPABASE_ANON_KEY)
	$(call require,SENTRY_DSN)
	$(call require,APP_VERSION)
	$(call require,REVENUECAT_ANDROID_KEY)
	cd apps/mobile && flutter build apk --release $(RELEASE_COMMON) \
		--dart-define=REVENUECAT_ANDROID_KEY=$(REVENUECAT_ANDROID_KEY)

mobile-build-ios: ## Build a production iOS release (requires release env vars)
	$(call require,API_URL)
	$(call require,SUPABASE_URL)
	$(call require,SUPABASE_ANON_KEY)
	$(call require,SENTRY_DSN)
	$(call require,APP_VERSION)
	$(call require,REVENUECAT_IOS_KEY)
	cd apps/mobile && flutter build ios --release $(RELEASE_COMMON) \
		--dart-define=REVENUECAT_IOS_KEY=$(REVENUECAT_IOS_KEY)

mobile-codegen: ## Run Flutter build_runner code generation
	cd apps/mobile && dart run build_runner build --delete-conflicting-outputs

mobile-e2e-smoke: ## E2E smoke on iOS simulator (needs 'make dev' stack up)
	TARGET=smoke_test.dart ./scripts/e2e.sh

mobile-e2e: ## Full E2E journey sweep on iOS simulator (needs 'make dev' stack up)
	TARGET=suite_test.dart ./scripts/e2e.sh

lint: ## Run all linters (Go + Flutter)
	cd apps/api && golangci-lint run --timeout=5m
	cd apps/mobile && flutter analyze --fatal-infos
	cd apps/mobile && dart format --output=none --set-exit-if-changed --line-length=80 lib/

install-hooks: ## Install git pre-commit hooks
	@echo '#!/bin/sh' > .git/hooks/pre-commit
	@echo 'echo "Running linters..."' >> .git/hooks/pre-commit
	@echo 'cd apps/api && golangci-lint run --timeout=5m || exit 1' >> .git/hooks/pre-commit
	@echo 'cd ../../apps/mobile && flutter analyze --fatal-infos || exit 1' >> .git/hooks/pre-commit
	@echo 'cd ../../apps/mobile && dart format --output=none --set-exit-if-changed --line-length=80 lib/ || exit 1' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed."
