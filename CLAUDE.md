# Navis App

Boat management mobile app for recreational owners. Monorepo: Flutter mobile + Go API + Supabase.

## Monorepo Structure

```
apps/api/          — Go 1.26 API (Chi v5, pgx/v5, Clean Architecture)
apps/mobile/       — Flutter 3.32 / Dart 3.x (Riverpod, GoRouter, Dio)
packages/supabase/ — Migrations, RLS policies, seeds
docs/              — Architecture, API spec, features, plan
```

## Critical Architecture Rules

- **All CRUD goes through the Go API.** Flutter NEVER queries Supabase tables directly.
- **Supabase in Flutter is ONLY for Auth (login/register/session) and Storage (file uploads).**
- **NEVER cross imports between Flutter features** — shared code goes to `shared/`.
- **Domain layer NEVER imports from any other internal package** (Go or Flutter).
- API endpoints follow `/api/v1/<resource>` convention.
- Cursor-based pagination everywhere (never offset-based).
- JSON response envelope: `{ "data": ..., "error": ..., "meta": ... }`.

---

## Go API — Clean Architecture (`apps/api/`)

Dependency flow: `handler → service → port ← adapter`

| Layer | Package | Responsibility |
|-------|---------|---------------|
| Domain | `internal/domain/` | Pure structs, typed string enums, sentinel errors |
| Ports | `internal/port/` | Interfaces only — repository + external service contracts |
| Services | `internal/service/` | Business logic. Transport-agnostic (no HTTP knowledge) |
| Adapters | `internal/adapter/<impl>/` | Implementations: `postgres/` (pgx), `openmeteo/`, `novu/` |
| Handlers | `internal/handler/` | HTTP only: parse request, call service, encode response |
| DTOs | `internal/dto/` | Request/response structs with JSON tags. Separate from domain |
| Middleware | `internal/middleware/` | Auth (JWT), logging, recovery, CORS, request ID, rate limit |
| Router | `internal/router/` | Chi route definitions |
| Config | `internal/config/` | Env-based config via `os.Getenv` with defaults |
| Cron | `internal/cron/` | Scheduled jobs (robfig/cron/v3) |
| Shared | `pkg/` | Cross-cutting: `validator/`, `pagination/` |

### Go — Architecture Rules

- Manual DI in `main.go`. No DI frameworks (wire, fx). Explicit wiring is clearer.
- Each handler receives a service by interface. Each service receives repositories by interface.
- Handlers do ZERO business logic. They decode request → call service → encode response.
- Services contain ALL business logic. They know nothing about HTTP.
- New external integrations get their own adapter package under `internal/adapter/<name>/`.

### Go — HTTP & Routing

- Chi v5 router. Versioned: `/api/v1/boats`, `/api/v1/documents`, etc.
- Use `response.go` helpers: `response.JSON(w, status, data)`, `response.Error(w, status, err)`.
- Status codes: 201 create, 204 delete, 400 validation, 401 auth, 403 forbidden, 404 not found, 409 conflict, 422 unprocessable, 429 rate limit, 500 only for unexpected internal errors.
- Pagination: return `next_cursor` in response. Never use offset.
- Per-handler timeouts with `http.TimeoutHandler` for long operations.
- Health check endpoints: `GET /healthz` (liveness), `GET /readyz` (readiness — checks DB pool).

### Go — Error Handling

- Sentinel errors in `domain/errors.go`: `ErrBoatNotFound`, `ErrUnauthorized`, `ErrValidation`, etc.
- `ValidationError` struct for field-level errors, implements `Unwrap() → ErrValidation`.
- Always wrap with context: `fmt.Errorf("boat_service.GetByID: %w", err)`.
- Use `errors.Is()` and `errors.As()` to compare, never string matching.
- Use `errors.Join()` when aggregating multiple errors (e.g., batch validation).
- Handlers map domain errors to HTTP status codes. Never expose internal errors to client.
- Panic recovery middleware catches panics, logs stack trace, returns 500.

### Go — Database

- `pgx/v5` (pgxpool) directly. NO ORM (no GORM). Full SQL control needed for PostGIS.
- `pgxpool` with MaxConns = 10, MinConns = 2, MaxConnLifetime = 1h, MaxConnIdleTime = 30m.
- All queries take `context.Context` as first parameter.
- Every repo query filters by `user_id` for data isolation.
- Table naming: snake_case plural (`boats`, `documents`, `trip_tracks`).
- **Transactions:** use a `TxManager` or pass `pgx.Tx` via context for multi-table operations. Services start transactions, repos accept the tx. Never start a transaction inside a repo method.
- **Batch operations:** use `pgx.Batch` for bulk inserts/updates (e.g., trip track points) instead of loops.
- Use `pgx.NamedArgs` for readable queries with many parameters.
- Always use `sqlc` or hand-written SQL — never build queries with string concatenation.

### Go — Auth & Security

- Supabase Auth JWT in `Authorization: Bearer <token>` header.
- Middleware validates JWT against Supabase secret, extracts `user_id` from `sub` claim.
- `user_id` injected into context: `context.WithValue(ctx, userIDKey, userID)`.
- Rate limiting middleware per IP and per user (token bucket or sliding window).
- Input sanitization: trim strings, validate max lengths in DTOs before they reach services.
- Never log sensitive data (tokens, passwords, personal data).

### Go — Validation

- `go-playground/validator/v10` for DTO validation in handlers, before calling service.
- Return detailed field-level errors to client with JSON path.
- Custom validators for domain-specific rules (e.g., valid boat type, valid document type).

### Go — Types & Generics

- Domain entities are plain structs — no JSON tags, no DB tags.
- Use `*float64` / `*string` for nullable optional fields, not zero values.
- Typed string enums: `type BoatType string` with const block.
- Repository interfaces are hand-written per entity in `internal/port/` — a generic `Repository[T]` does not fit the per-entity SQL (PostGIS expressions, shared-access scoping, keyset pagination) and is deliberately NOT used.
- Generics ARE used for cross-cutting handler helpers (e.g. `decodeAndValidate[T]`).
- Use `slices` and `maps` stdlib packages instead of manual loops for sorting, filtering, and lookups.
- Use range over integers (`for i := range n`) instead of `for i := 0; i < n; i++`.

### Go — Concurrency & Lifecycle

- **Graceful shutdown:** use `signal.NotifyContext(ctx, syscall.SIGINT, syscall.SIGTERM)` in main. Pass context to HTTP server, cron, and DB pool. `server.Shutdown(ctx)` with timeout.
- Cancel long-running operations via context propagation. Never ignore `ctx.Done()`.
- Use `errgroup.Group` for parallel independent operations within a handler (e.g., fetching boat + documents + weather concurrently).
- Never use `go func()` without error handling and shutdown coordination.

### Go — Observability

- `log/slog` (stdlib) for structured JSON logging.
- **Request ID middleware:** generate UUID per request, propagate via context, include in all log lines.
- Log per request: request_id, user_id, method, path, status, duration, bytes_written.
- Log at appropriate levels: ERROR for 5xx, WARN for 4xx client errors, INFO for successful operations, DEBUG for development detail.
- Structured slog groups: `slog.Group("request", "id", reqID, "method", method)`.
- Consider OpenTelemetry traces for cross-service observability in production.

### Go — Testing

- Unit tests for services with mocked port interfaces.
- Integration tests for repos against real DB (testcontainers or Supabase local).
- Naming: `TestBoatService_Create_Success`, `TestBoatService_Create_DuplicateRegistration`.
- Table-driven tests with `t.Run()` subtests. Always `t.Parallel()` for independent tests.
- Test files next to source (`_test.go`), no separate test folders.
- Use `t.Helper()` in test utility functions for correct line reporting.
- Use `t.Cleanup()` for teardown instead of `defer` in tests.
- Golden files for complex JSON response assertions.
- Benchmark critical paths with `b.Run()` — especially PostGIS queries and batch inserts.

### Go — Linting & Build

- `.golangci.yml` with: errcheck, gosimple, govet, ineffassign, staticcheck, unused, gosec, revive, gocritic, exhaustive (for typed enum switches).
- Code MUST pass `golangci-lint run` without errors.
- Multi-stage Docker: build stage → `gcr.io/distroless/static-debian12` final (~10MB).
- Always check `exhaustive` linter for switch statements on typed enums — ensures all cases handled.

### Adding a New Go Feature

1. Domain entity in `internal/domain/<entity>.go` — pure struct + typed enums
2. Sentinel errors in `internal/domain/errors.go` if needed
3. Repository interface in `internal/port/repository.go` (consider generic base)
4. Service in `internal/service/<entity>_service.go` — all business logic here
5. DTOs in `internal/dto/<entity>_dto.go` — request + response + validation tags
6. Postgres adapter in `internal/adapter/postgres/<entity>_repo.go` — raw SQL with pgx
7. Handler in `internal/handler/<entity>_handler.go` — thin HTTP glue
8. Register routes in `internal/router/router.go`
9. Unit tests for service, integration tests for repo
10. Verify linter passes: `make api-lint`

---

## Flutter — Feature-First Architecture (`apps/mobile/`)

```
lib/
  core/
    config/       — Env vars (Supabase URL, API base URL)
    network/      — ApiClient (Dio with interceptors), SupabaseClient
    theme/        — AppColors (nautical palette), AppTypography
    error/        — Failure sealed class hierarchy
    utils/        — Date utils, distance utils (nautical miles, coordinates)
  features/
    <feature>/
      domain/
        entities/     — Immutable: const constructor, final fields, copyWith, ==, hashCode
        repositories/ — Abstract interface
      data/
        models/       — fromJson / toJson / fromEntity / toEntity
        repositories/ — Implementation using ApiClient
      presentation/
        providers/    — Riverpod AsyncNotifier + providers
        screens/      — Full-page widgets
        widgets/      — Feature-specific widgets
  shared/
    widgets/          — Reusable widgets with Navis prefix (NavisButton, NavisCard, etc.)
    models/           — Cross-feature (PaginatedResponse, etc.)
```

### Flutter — Architecture Rules

- Feature-first with Clean Architecture per feature.
- Entities are pure Dart: `const` constructor, `final` fields, `copyWith()`, `==` override. NO serialization, NO external dependencies.
- Models handle ALL JSON conversion: `fromJson(Map<String, dynamic>)`, `toJson()`, `fromEntity()`, `toEntity()`. JSON keys = `snake_case`, Dart fields = `camelCase`.
- Repository: abstract interface in `domain/repositories/`, implementation in `data/repositories/` using `ApiClient`.

### Flutter — Dart 3.x Modern Features (MANDATORY)

Use these Dart 3.x features everywhere they apply:

- **Sealed classes** for state and error hierarchies:
  ```dart
  sealed class Failure {
    String get message;
  }
  final class ServerFailure extends Failure { ... }
  final class NetworkFailure extends Failure { ... }
  ```
  This enables exhaustive `switch` — the compiler guarantees all cases are handled.

- **Switch expressions** instead of if/else chains or switch statements:
  ```dart
  final icon = switch (status) {
    'ok' => Icons.check_circle,
    'warning' => Icons.warning,
    'critical' => Icons.error,
    'expired' => Icons.cancel,
    _ => Icons.help,
  };
  ```

- **Pattern matching** with destructuring in switch cases and if-case:
  ```dart
  if (state case AsyncData(:final value)) {
    return BoatList(boats: value);
  }
  ```

- **Records** for lightweight multiple returns (avoid creating a class for two values):
  ```dart
  (List<Boat> boats, String? nextCursor) fetchBoats() { ... }
  ```

- **Extension types** for type-safe IDs — prevent mixing user IDs with boat IDs:
  ```dart
  extension type UserId(String value) implements String {}
  extension type BoatId(String value) implements String {}
  ```

- **`final class`** to prevent extension of classes not designed for it:
  ```dart
  final class BoatModel { ... }
  ```

- **Enhanced enums** with fields and methods:
  ```dart
  enum BoatType {
    sailboat('Sailboat', Icons.sailing),
    motorboat('Motorboat', Icons.directions_boat);
    const BoatType(this.label, this.icon);
    final String label;
    final IconData icon;
  }
  ```

- **Collection if/for** in widget trees and data structures. Prefer over ternaries:
  ```dart
  Column(children: [
    BoatHeader(boat: boat),
    if (boat.photoUrl != null) CachedImage(url: boat.photoUrl!),
    for (final doc in documents) DocumentCard(doc: doc),
  ])
  ```

### Flutter — State Management (Riverpod 2)

- `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`.
- Use `@riverpod` annotation with code generation. Run `dart run build_runner watch`.
- **`autoDispose` by default** — all providers auto-dispose when no longer listened. Only add `keepAlive: true` for data that must survive navigation (e.g., user session, boat list cache).
- `AsyncNotifierProvider` + `AsyncNotifier` for async data with mutations.
- `ref.watch()` for reactive dependencies in `build()`, `ref.read()` for one-shot actions in methods.
- Providers do NOT contain business logic. They delegate to repositories.
- **Family providers** for parameterized data (e.g., `boatProvider(boatId)`).
- **Invalidation:** call `ref.invalidateSelf()` after mutations to trigger refetch, or optimistically update state.
- Never store Riverpod providers in variables outside the provider scope.

### Flutter — Optimistic UI & Mutations

- **Optimistic updates** for create/update/delete: update local state immediately, revert on error.
  ```dart
  Future<void> deleteBoat(BoatId id) async {
    final previous = state.valueOrNull ?? [];
    state = AsyncData(previous.where((b) => b.id != id).toList());
    try {
      await repository.deleteBoat(id);
    } catch (e) {
      state = AsyncData(previous); // revert
      rethrow;
    }
  }
  ```
- Show snackbar on error revert so the user knows the action failed.
- For creates, use a temporary ID or loading indicator until server confirms.

### Flutter — Navigation

- `go_router` for declarative routing. All routes in `app/router.dart` with path constants.
- Redirect for auth-protected routes.
- `StatefulShellRoute` for bottom navigation.
- Deep linking support from day one — every screen must be reachable by URL.
- Type-safe route parameters using GoRouter's `$extra` for complex objects, path params for IDs.

### Flutter — Networking & Error Handling

- `Dio` for Go API calls. Interceptors for: auth token injection, error handling, retry, logging.
- JWT from Supabase auto-injected in every Go API request.
- `supabase_flutter` ONLY in `core/network/supabase_client.dart` and auth feature.
- **Retry interceptor:** auto-retry on 5xx and network errors (max 2 retries, exponential backoff).
- **Token refresh interceptor:** catch 401, refresh Supabase session, retry original request.
- Map Dio exceptions to domain `Failure` types at the repository layer. Screens never see `DioException`.

### Flutter — Pagination & Search

- Repositories return `PaginatedResponse<T>` with `items` + `nextCursor`.
- Notifiers track `_nextCursor` and `_hasMore` for infinite scroll.
- **Debounce search** inputs (300ms) before sending API requests. Use a `Timer` or `Debouncer` util.
- Cancel previous search requests when a new one starts (Dio `CancelToken`).

### Flutter — Images & Storage

- **Compress images before upload** — resize to max 1200px width, JPEG quality 85%.
- Use `cached_network_image` for all remote images with placeholder and error widgets.
- Upload to Supabase Storage, store the returned URL in the Go API entity.
- Show upload progress indicator during file uploads.

### Flutter — Performance

- **`const` constructors everywhere possible** — enables widget tree optimizations.
- Use `ListView.builder` / `SliverList` for long lists, never `Column` with `List.map`.
- **`RepaintBoundary`** around expensive widgets (maps, charts, animations).
- Avoid rebuilds: split large widgets into smaller ones, each watching only what it needs.
- Use `select` on Riverpod providers to listen to specific fields instead of entire objects.
- Lazy-load features with deferred imports if app size becomes a concern.

### Flutter — Forms & Validation

- Use `Form` + `TextFormField` with `GlobalKey<FormState>`.
- Validate client-side before API call. Match validation rules with Go API.
- Show inline field errors, not just snackbars.
- Disable submit button while async operation is in progress (prevent double-submit).
- Preserve form state on navigation (use `AutomaticKeepAliveClientMixin` or provider).

### Flutter — Accessibility

- All images have `semanticLabel`.
- All interactive widgets have `Tooltip` or `Semantics` label.
- Minimum touch target: 48x48 dp.
- Text contrast meets WCAG AA (4.5:1 for normal text, 3:1 for large text).
- Test with TalkBack (Android) and VoiceOver (iOS).
- Support dynamic text scaling — never hardcode font sizes without `MediaQuery.textScaleFactor`.

### Flutter — UI/UX

- Dark mode by default (nautical theme).
- Palette: navy (#1B2A4A), cyan (#4DA8DA), green (#2ECC71), amber (#F39C12), red (#E74C3C).
- Shared widgets in `shared/widgets/` with `Navis` prefix.
- All UI strings in `.arb` files for i18n (Spanish + English).
- Imports use package paths: `package:navis_mobile/features/...`.
- Consistent spacing: use theme-defined constants, not magic numbers.
- Loading states: skeleton shimmer for lists, centered spinner for full-page loads.
- Empty states: illustration + helpful message + CTA button.
- Error states: retry button + clear error message. Never show raw exceptions.

### Flutter — Maps

- `flutter_map` with MapLibre renderer. OpenSeaMap tiles as nautical layer.
- GPS tracking with `geolocator`.
- Offline charts: `flutter_map_mbtiles` for local MBTiles/SQLite.

### Flutter — Offline

- SQLite local (drift/sqflite) for boats, documents, trips.
- Sync strategy: save local first, sync to backend when online.
- Show connectivity status banner when offline.
- Queue mutations locally and replay when connection restores.

### Flutter — Testing

- Unit tests for providers and repositories. Widget tests for shared widgets.
- Use `mocktail` for mocks.
- Naming: `boat_provider_test.dart`, `document_card_test.dart`.
- Test all `sealed class` branches with exhaustive switch in test assertions.
- Test error states and loading states, not just happy paths.
- Code MUST pass `flutter analyze` without warnings.

### Adding a New Flutter Feature

1. `features/<name>/domain/entities/<name>.dart` — immutable entity with extension types for IDs
2. `features/<name>/domain/repositories/<name>_repository.dart` — abstract interface
3. `features/<name>/data/models/<name>_model.dart` — JSON model (final class)
4. `features/<name>/data/repositories/<name>_repository.dart` — impl with ApiClient, maps DioException → Failure
5. `features/<name>/presentation/providers/<name>_provider.dart` — AsyncNotifier, autoDispose, optimistic updates
6. Screens and widgets under `presentation/` — const constructors, accessibility labels, loading/error/empty states
7. Add i18n strings to `.arb` files
8. Unit test provider + repo, widget test key screens

---

## Cross-Cutting Concerns

### Error Reporting
- Integrate Sentry (or Crashlytics) in both Go API and Flutter.
- Go: Sentry middleware captures unhandled panics and 5xx errors with request context.
- Flutter: catch unhandled exceptions in `runZonedGuarded`, report with user/device context.
- Tag errors with: user_id, boat_id (if applicable), app version, OS version.
- Filter PII from error reports before sending.

### Security Checklist
- Never log tokens, passwords, or personal data.
- Sanitize all user input: trim whitespace, enforce max lengths.
- Validate content types on file uploads (only images for photos/documents).
- Rate limit auth endpoints more aggressively (10 req/min).
- Use parameterized SQL only — never string concatenation for queries.
- CORS: allow only known origins in production.
- HTTPS only in production. HSTS headers.

### API Versioning
- Current: `v1`. When breaking changes needed, create `v2` handlers alongside `v1`.
- Never remove v1 endpoints without a deprecation period and client migration.

---

## Database (Supabase)

- PostgreSQL with PostGIS enabled.
- Key tables: `profiles` (plan), `boats` (+`share_code`), `boat_members` (shared crew/co-owners), `documents` (computed `status` column), `trips` (+ group/regatta, `share_token`), `trip_tracks` (PostGIS), `trip_participants` (RSVP), `trip_checklist_items`, `maintenance_logs`, `expenses`, `groups`, `group_members`, `events` (+ stream/tracking urls), `event_interests`, `notification_logs`, `sent_notifications`.
- RLS enforces `user_id = auth.uid()` on user tables. Shared boats: members READ a boat + its sub-resources (enforced in the Go service via `boatRepo.HasAccess`, reading as the owner's scope); all WRITES stay owner-only. Events readable by all, writable by admins.
- Plans: `profiles.plan` ∈ `free|pro` gates boat count (1/3), group creation (Pro), and document-expiry reminders (Free=1 doc); enforced in services, returns 402. Paid tier driven by RevenueCat webhook (`POST /api/v1/webhooks/revenuecat`); `PUT /me/plan` is a dev-only switcher (debug builds / non-production). A B2B "fleet" tier is future work.
- Migrations in `packages/supabase/migrations/` numbered `00001_`, `00002_`, etc.
- Document types: itb, insurance_rc, insurance_full, life_raft, extinguisher, flares, first_aid, medical_cert, radio_cert, navigation_license, custom.
- Document status is a computed column: expired / critical (30d) / warning (90d) / ok.

## Cron Job

- `robfig/cron/v3` in Go API, runs daily at 08:00 UTC.
- Checks document expiry against `alert_days` array (default: 30, 7 days).
- Triggers Novu `document-expiry` workflow per user. Novu delivers via FCM (push) and Resend (email).
- Logs to `notification_logs` to avoid duplicates.

## Commands

```bash
# Local development
make dev             # Start Supabase + Go API (full stack)
make stop            # Stop everything

# Supabase (Database + Auth + Storage)
make db-start        # Start Supabase local stack
make db-stop         # Stop Supabase local
make db-migrate      # Apply pending migrations
make db-reset        # Reset and reseed database

# Go API
make api-dev         # Hot reload (air)
make api-build       # go build
make api-test        # go test ./...
make api-lint        # golangci-lint run

# Flutter
make mobile-run      # flutter run (device/emulator)
make mobile-run-emu  # flutter run on Android emulator (10.0.2.2 URLs)
make mobile-test     # flutter test
make mobile-lint     # flutter analyze --fatal-infos
make mobile-format   # dart format --line-length=80
make mobile-codegen  # build_runner code generation
```

## Local Development Setup

Prerequisites: Docker, Supabase CLI, Flutter SDK, Go.

```bash
# 1. Start Supabase (Postgres + Auth + Storage + Dashboard)
make db-start
# Dashboard at http://localhost:54323

# 2. Start Go API (connects to Supabase Postgres on port 54322)
make dev
# API at http://localhost:8080

# 3. Run Flutter app
make mobile-run           # Physical device
make mobile-run-emu       # Android emulator (uses 10.0.2.2)
```

Note: Android emulator uses `10.0.2.2` to reach the host machine's localhost.

## External Services & Infrastructure

| Service | Purpose | Dashboard | Env Var |
|---------|---------|-----------|---------|
| **Supabase** | Auth, Storage, PostgreSQL+PostGIS | supabase.com/dashboard | `SUPABASE_URL`, `SUPABASE_JWT_SECRET`, `SUPABASE_ANON_KEY` |
| **Novu** | Notification orchestration (push, email, in-app) | dashboard.novu.co | `NOVU_API_KEY` |
| **Firebase** | FCM push transport (Android/iOS) | console.firebase.google.com | `google-services.json` (Android), `GoogleService-Info.plist` (iOS) |
| **Resend** | Email delivery (integrated via Novu) | resend.com/emails | Configured in Novu Integrations |
| **Sentry** | Error/crash reporting (Go API + Flutter) | sentry.io | `SENTRY_DSN` (Go), `--dart-define=SENTRY_DSN=...` (Flutter) |

### Novu Setup

- **Workflow:** `document-expiry` — triggered by Go API cron. Steps: Push (FCM) → Email (Resend).
- **Integrations:** FCM (Service Account JSON from Firebase) + Resend (API Key).
- **Environments:** Development and Production — each has its own API Key. Same Firebase Service Account and Resend key in both.
- **Subscribers:** Created automatically when users register device tokens via `POST /api/v1/devices`. Subscriber ID = Supabase `user_id`.
- **Sender:** `Navis <notifications@aerolume.app>`

### Firebase Setup

- **Project:** `navis-44c8b`
- **Android:** `google-services.json` in `apps/mobile/android/app/` (gitignored)
- **iOS:** `GoogleService-Info.plist` in `apps/mobile/ios/Runner/` (pending)
- **Only used for:** FCM push transport. No Firebase Auth, no Firestore, no Analytics.

### How Notifications Flow

```
Go API cron (08:00 UTC)
  → detects expiring document
  → checks notification_logs (dedup)
  → POST Novu /v1/events/trigger (workflow: document-expiry, subscriber: user_id)
    → Novu Push Step → FCM → device notification
    → Novu Email Step → Resend → notifications@aerolume.app → user inbox
Flutter receives push via firebase_messaging → tap → deep link to document
```

## Development Workflow (MANDATORY for every feature/fix)

Follow this procedure for every piece of work, no exceptions:

### 1. Work on a feature branch
```bash
git checkout -b feat/<name>    # or fix/<name>
```

### 2. Before pushing — run all code quality checks locally
```bash
# Go API
cd apps/api && go test -race ./...        # All tests pass
cd apps/api && golangci-lint run           # No lint errors

# Flutter
cd apps/mobile && dart format --output=none --set-exit-if-changed --line-length=80 lib/ test/
cd apps/mobile && flutter analyze --fatal-infos   # Zero issues
cd apps/mobile && flutter test                     # All tests pass
```
**Do NOT push if any of these fail.** Fix the issues first.

### 3. Commit and push
- Commit with a clear message following conventional commits (`feat:`, `fix:`, `refactor:`, etc.)
- Push the feature branch to origin

### 4. Create PR and verify CI passes
- Create a PR targeting `develop` (or `main` for releases)
- Wait for GitHub Actions CI to pass **both** Go API and Flutter Mobile jobs
- If CI fails, fix locally, push again, and re-verify

### 5. Merge only after green CI
- Only merge the PR once all CI checks are green
- Delete the feature branch after merging

### Summary
```
code → local checks → push → PR → CI green → merge → delete branch
```

---

## Deployment

- **MVP:** Supabase Cloud + Railway (Go API, EU region) + App Store / Google Play
- **Scale:** Migrate to K8s on Hetzner + self-hosted Supabase + Cloudflare R2/CDN + self-hosted Novu
- **CI/CD:** GitHub Actions — lint+test on every PR and main push. Deploy to Railway is manual until the Railway project exists (see docs/deploy.md, phase 5 of the launch plan).

## Stack Versions

- Go 1.26, Chi v5, pgx/v5, robfig/cron/v3, go-playground/validator/v10, log/slog
- Flutter 3.32, Dart 3.x, Riverpod 2, GoRouter 14, Dio 5, supabase_flutter 2.5
- flutter_map 7, geolocator 12, drift/sqflite, mocktail, cached_network_image
- Supabase (Auth, Storage, PostGIS, RLS)
- Novu (notification orchestration: push + email + in-app), Resend (email delivery)
- Firebase Messaging (push transport layer in Flutter)
- Sentry for error reporting (Go + Flutter)
