# Navis

Boat management app for recreational owners. Track documents, log trips, check weather, and discover events — all in one place.

## Architecture

- **Mobile** — Flutter (Riverpod, GoRouter, Dio)
- **API** — Go (Chi, pgx, Clean Architecture)
- **BaaS** — Supabase (Auth, Storage, PostGIS, Edge Functions)

## Monorepo structure

```
apps/api/        → Go REST API
apps/mobile/     → Flutter mobile app
packages/supabase/ → Migrations, Edge Functions, seeds
docs/            → Architecture, API spec, features
```

## Quick start

```bash
# 1. Start Supabase + API locally
make dev

# 2. Run Flutter app
make mobile-run
```

## Prerequisites

- Go 1.22+
- Flutter 3.22+
- Docker & Docker Compose
- Supabase CLI

## Development

```bash
make api-dev       # Go API with hot reload
make api-test      # Run Go tests
make api-lint      # Run linter
make mobile-run    # Flutter run
make mobile-test   # Flutter tests
make db-reset      # Reset local database
```

## License

MIT
