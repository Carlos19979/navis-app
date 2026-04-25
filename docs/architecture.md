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
               | Open-Meteo       |  <-- Weather data (free, no key)
               | Firebase FCM     |  <-- Push notifications
               +------------------+
```

## Component Details

### Flutter App (`apps/mobile/`)

- **Framework**: Flutter 3.22+ with Dart
- **State management**: Riverpod (code generation)
- **Architecture**: Feature-first with clean architecture layers
  - `data/` — Models, repositories (API calls, local cache)
  - `domain/` — Entities, repository interfaces
  - `presentation/` — Screens, widgets, providers
- **Key packages**: go_router, dio, supabase_flutter, flutter_map, geolocator, hive (offline)
- **Localization**: ARB files (Spanish primary, English)

### Go API (`apps/api/`)

- **Framework**: Fiber v2 (Express-like HTTP framework for Go)
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
  - `internal/cron/` — Scheduled jobs (document expiry notifications)
  - `internal/config/` — Environment configuration
  - `internal/router/` — Route registration
- **Auth**: Validates Supabase JWT (RS256) in middleware
- **Cron**: Checks document expiry dates daily, sends FCM push notifications

### Supabase (`packages/supabase/`)

- **Auth**: Email/password, Google, Apple sign-in
- **Storage**: Boat photos, document scans (RLS-protected buckets)
- **Database**: PostgreSQL 15 with PostGIS extension
- **Migrations**: Sequential SQL files, run via `supabase db push`

### PostgreSQL Schema

```
  auth.users
      |
      | 1:N
      v
  +--------+     1:N     +-----------+     1:N     +-------------+
  | boats  | ----------> | documents | <---------- | notification|
  +--------+             +-----------+              |   _logs     |
      |                                             +-------------+
      | 1:N
      v
  +--------+     1:N     +-------------+
  | trips  | ----------> | trip_tracks |
  +--------+             | (GPS points)|
                          +-------------+

  +--------+     N:M     +-----------------+
  | events | <---------> | event_interests |
  +--------+             | (user_id, ...)  |
                          +-----------------+
```

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
2. Points are batched locally (Hive) and sent to the API every 60 seconds
3. Go API inserts batch into `trip_tracks` with PostGIS GEOGRAPHY points
4. On trip completion, the API calculates total `distance_nm` from the track

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
