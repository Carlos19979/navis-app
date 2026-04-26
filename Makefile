.PHONY: help dev stop api-run api-build api-test api-lint api-dev mobile-run mobile-test mobile-lint mobile-analyze mobile-codegen db-start db-stop db-reset db-migrate

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

mobile-run: ## Run Flutter app on connected device
	cd apps/mobile && flutter run

mobile-run-emu: ## Run Flutter app on Android emulator with local backend
	cd apps/mobile && flutter run --dart-define=API_URL=http://10.0.2.2:8080 --dart-define=SUPABASE_URL=http://10.0.2.2:54321

mobile-test: ## Run Flutter tests
	cd apps/mobile && flutter test

mobile-lint: ## Run Flutter analyzer
	cd apps/mobile && flutter analyze --fatal-infos

mobile-format: ## Format Flutter code
	cd apps/mobile && dart format --line-length=80 lib/ test/

mobile-analyze: ## Run Flutter analyze (alias)
	cd apps/mobile && flutter analyze

mobile-build-apk: ## Build Android APK
	cd apps/mobile && flutter build apk --release

mobile-build-ios: ## Build iOS
	cd apps/mobile && flutter build ios --release

mobile-codegen: ## Run Flutter build_runner code generation
	cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
