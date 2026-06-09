# Navis Architecture

## System Overview

```
+--------------------------------------------------+
|                  FLUTTER APP                      |
|            (apps/mobile — Dart/Riverpod)          |
|                                                   |
|  +------------+  +----------+  +---------------+  |
|  |  Auth UI   |  | Boat/Doc |  | Logbook/Maps  |  |
|  |  Screens   |  |  Screens |  |   Screens     |  |
|  +-----+------+  +----+-----+  +-------+-------+  |
|        |              |                |           |
|  +-----+--------------+----------------+--------+  |
|  |           Core / Shared Layer                 |  |
|  |  (HTTP client, offline cache, theme, i18n)    |  |
|  +-----+------------------+----------+----------+  |
+--------|------------------|----------|------------+
         |                  |          |
    Auth | Storage    REST API    Realtime
         |                  |          |
+--------v--+        +-----v----------v-----------+
|            |        |                            |
|  SUPABASE  |        |         GO API             |
|   AUTH     |        |   (apps/api — Fiber/pgx)   |
|            |        |                            |
|  - Email   |        |  +---------+  +--------+   |
|  - Google  |        |  |Handlers |  | Cron   |   |
|  - Apple   |        |  |  REST   |  | Jobs   |   |
|            |        |  +----+----+  +---+----+   |
|  SUPABASE  |        |       |           |        |
|  STORAGE   |        |  +----v-----------v----+   |
|            |        |  |    Service Layer     |   |
|  - Photos  |        |  +----+----------------+   |
|  - Docs    |        |       |                    |
+--------+---+        +-------|--------------------+
         |                    |
         |              +-----v-----+
         |              |           |
         +------------->| POSTGRES  |
                        | + PostGIS |
                        |           |
                        +-----------+

               +------------------+
               |   EXTERNAL APIs  |
               +------------------+
               | Open-Meteo       |  <-- Weather + marine/tides (free, no key)
               | Novu             |  <-- Notification orchestration
               | Firebase FCM     |  <-- Push transport
               | Resend           |  <-- Email (via Novu)
               | Sentry           |  <-- Error reporting (Go + Flutter)
               +------------------+
```

## Component Details

### Flutter App (`apps/mobile/`)

- **Framework**: Flutter 3.32 with Dart 3.x
- **State management**: Riverpod (hand-written providers — no codegen)
- **Architecture**: Feature-first with clean architecture layers
  - `data/` — Models, repositories (API calls, local cache)
  - `domain/` — Entities, repository interfaces
  - `presentation/` — Screens, widgets, providers
- **Key packages**: go_router, dio, supabase_flutter, flutter_map, geolocator, drift/sqflite (offline), share_plus, url_launcher
- **Localization**: ARB files (Spanish primary, English)

### Go API (`apps/api/`)

- **Framework**: Chi v5 (lightweight HTTP router for Go)
- **Database**: pgx v5 (native PostgreSQL driver, no ORM)
- **Architecture**: Hexagonal (ports & adapters)
  - `cmd/server/` — Entry point, server bootstrap
  - `internal/handler/` — HTTP handlers (request/response)
  - `internal/service/` — Business logic
  - `internal/port/` — Interfaces (repository contracts)
  - `internal/adapter/` — Implementations (postgres, fcm, openmeteo)
  - `internal/domain/` — Domain entities
  - `internal/dto/` — Data transfer objects
  - `internal/middleware/` — Auth verification, logging, CORS
  - `internal/cron/` — Scheduled jobs (document expiry; regatta reminders;
    live-event alerts)
  - `internal/config/` — Environment configuration
  - `internal/router/` — Route registration
- **Auth**: Validates Supabase JWT in middleware (provider-agnostic — email,
  Apple, Google all produce a valid Supabase JWT)
- **Cron** (robfig/cron, UTC): daily document-expiry check; daily regatta
  reminders; every 15m live-event alerts. Dedup via `notification_logs` /
  `sent_notifications`. Push delivered via Novu → FCM.

### Supabase (`packages/supabase/`)

- **Auth**: Email/password, Google, Apple sign-in
- **Storage**: Boat photos, document scans (RLS-protected buckets)
- **Database**: PostgreSQL 15 with PostGIS extension
- **Migrations**: Sequential SQL files, run via `supabase db push`

### PostgreSQL Schema

```
  auth.users ---1:1--- profiles (plan: normal|armador|gestor)
      |
      | 1:N (owner)        N:M shared crew/co-owners (read-only)
      v                     ^
  +--------+ <--- boat_members (boat_id, user_id, role) ; boats.share_code
  | boats  |
  +--------+--1:N--> documents (status, renewal)
      |    \--1:N--> maintenance_logs / expenses
      | 1:N
      v
  +--------+--1:N--> trip_tracks (GPS, PostGIS)
  | trips  |--1:N--> trip_participants (RSVP) / trip_checklist_items
  +--------+  (regatta: group_id/kind/scheduled_at ; public share: share_token)

  groups --1:N--> group_members (pending|active)     (clubs/crews, invite code)
  events --N:M--> event_interests   (events carry stream_url / tracking_url)
  notification_logs / sent_notifications             (push dedup)
```

Key tables: `profiles`, `boats` (+`share_code`), `boat_members`, `documents`,
`trips` (+regatta/float-plan/share fields), `trip_tracks`, `trip_participants`,
`trip_checklist_items`, `maintenance_logs`, `expenses`, `groups`, `group_members`,
`events`, `event_interests`, `notification_logs`, `sent_notifications`.

## Data Flow

### Authentication
1. User signs in via Supabase Auth (Flutter SDK)
2. Supabase returns a JWT access token
3. Flutter stores the JWT and sends it as `Authorization: Bearer <token>` to the Go API
4. Go middleware validates the JWT signature using Supabase's JWKS
5. Extracted `user_id` is injected into the request context

### Document Expiry Notifications
1. Go cron job runs daily at 08:00 UTC
2. Queries documents where `expiry_date - CURRENT_DATE` matches any value in `alert_days`
3. Cross-references `notification_logs` to avoid duplicate sends
4. Sends push notification via Firebase FCM
5. Records the notification in `notification_logs`

### GPS Trip Recording
1. Flutter uses `geolocator` to capture position every 10 seconds
2. Points are batched locally (drift/sqflite) and sent to the API every 60 seconds
3. Go API inserts batch into `trip_tracks` with PostGIS GEOGRAPHY points
4. On trip completion, the API calculates total `distance_nm` from the track

### Plans / entitlements
1. `profiles.plan` (normal/armador/gestor) is read by `BoatService.Create` and
   `GroupService.Create` to enforce boat-count and group-creation limits
2. Over-limit actions return HTTP 402 (`PLAN_LIMIT` / `PLAN_FORBIDDEN`)
3. Flutter reads `GET /me` to gate the create FABs; a dev switcher writes
   `PUT /me/plan` (replaced by a payment webhook in production)

### Boat sharing (crew / co-owners)
1. Owner generates `boats.share_code`; an invitee `POST /boats/join` is added to
   `boat_members` as a read-only `viewer`
2. Reads of a boat and its documents/trips/maintenance/expenses check
   `boatRepo.HasAccess(userID, boatID)` and resolve to the **owner's** scope
3. All writes remain strictly owner-scoped (members get 404), so sharing can
   never escalate to write access

## Deployment

| Component | Environment | Host |
|-----------|------------|------|
| Flutter App | Production | App Store / Google Play |
| Go API | Production | Railway / Fly.io (Docker) |
| PostgreSQL | Production | Supabase (managed) |
| Supabase | Production | supabase.com (hosted) |

## Local Development

```bash
# Start all services
make dev

# Runs:
# - Supabase local (supabase start)
# - Go API with hot reload (air)
# - Flutter app (flutter run)
```
