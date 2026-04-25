.PHONY: help dev api-run api-build api-test api-lint api-dev mobile-run mobile-test mobile-lint mobile-analyze db-reset db-migrate

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# === Development ===

dev: ## Start Supabase + Go API for local development
	docker compose up -d

stop: ## Stop all services
	docker compose down

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

mobile-run: ## Run Flutter app
	cd apps/mobile && flutter run

mobile-test: ## Run Flutter tests
	cd apps/mobile && flutter test

mobile-lint: ## Run Flutter linter
	cd apps/mobile && flutter analyze

mobile-analyze: ## Run Flutter analyze (alias)
	cd apps/mobile && flutter analyze

mobile-build-apk: ## Build Android APK
	cd apps/mobile && flutter build apk --release

mobile-build-ios: ## Build iOS
	cd apps/mobile && flutter build ios --release

# === Database ===

db-reset: ## Reset local Supabase database
	cd packages/supabase && supabase db reset

db-migrate: ## Run pending migrations
	cd packages/supabase && supabase migration up

# === Code generation ===

mobile-codegen: ## Run Flutter build_runner code generation
	cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
