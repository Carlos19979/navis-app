# Navis REST API Specification

**Base URL**: `http://localhost:8080/api/v1`
**Auth**: All endpoints require `Authorization: Bearer <supabase_jwt>` unless noted.

---

## Pagination

All list endpoints use cursor-based pagination:

| Param    | Type   | Default | Description                          |
|----------|--------|---------|--------------------------------------|
| `limit`  | int    | 20      | Items per page (max 100)             |
| `cursor` | string | -       | Opaque cursor from previous response |

Response envelope:

```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6IjEyMyJ9",
    "has_more": true
  }
}
```

---

## Error Responses

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "length_m must be greater than 0",
    "details": [
      { "field": "length_m", "reason": "must be > 0" }
    ]
  }
}
```

| HTTP Code | Code               | Meaning                    |
|-----------|--------------------|----------------------------|
| 400       | VALIDATION_ERROR   | Invalid request body/params|
| 401       | UNAUTHORIZED       | Missing or invalid JWT     |
| 403       | FORBIDDEN          | Resource not owned by user |
| 404       | NOT_FOUND          | Resource does not exist    |
| 409       | CONFLICT           | Duplicate or state conflict|
| 500       | INTERNAL_ERROR     | Server error               |

---

## Boats

### POST /api/v1/boats

Create a new boat.

**Request:**
```json
{
  "name": "Luna Azul",
  "registration": "ES-MAL-3-1234",
  "type": "sailboat",
  "length_m": 12.5,
  "home_port": "Palma de Mallorca",
  "home_port_lat": 39.5696,
  "home_port_lon": 2.6347,
  "photo_url": "https://storage.supabase.co/boats/abc.jpg",
  "photo_urls": ["https://storage.supabase.co/boats/abc-2.jpg"],
  "engine_hours": 342.5
}
```

`home_port` is optional (nullable). `photo_urls` is the gallery beyond the
`photo_url` cover (Pro beyond the cover, `GalleryLimit`); on update, omitting it
keeps the gallery, `[]` clears it.

**Response (201):**
```json
{
  "data": {
    "id": "b0000000-0000-0000-0000-000000000001",
    "user_id": "00000000-0000-0000-0000-000000000001",
    "name": "Luna Azul",
    "registration": "ES-MAL-3-1234",
    "type": "sailboat",
    "length_m": 12.5,
    "home_port": "Palma de Mallorca",
    "home_port_lat": 39.5696,
    "home_port_lon": 2.6347,
    "photo_url": "https://storage.supabase.co/boats/abc.jpg",
    "engine_hours": 342.5,
    "created_at": "2026-04-25T10:00:00Z",
    "updated_at": "2026-04-25T10:00:00Z"
  }
}
```

### GET /api/v1/boats

List the authenticated user's boats.

**Query params:** `limit`, `cursor`

**Response (200):**
```json
{
  "data": [
    {
      "id": "b0000000-0000-0000-0000-000000000001",
      "name": "Luna Azul",
      "registration": "ES-MAL-3-1234",
      "type": "sailboat",
      "length_m": 12.5,
      "home_port": "Palma de Mallorca",
      "home_port_lat": 39.5696,
      "home_port_lon": 2.6347,
      "photo_url": "https://storage.supabase.co/boats/abc.jpg",
      "engine_hours": 342.5,
      "document_summary": {
        "total": 2,
        "expired": 0,
        "critical": 1,
        "warning": 1,
        "ok": 0
      },
      "created_at": "2026-04-25T10:00:00Z",
      "updated_at": "2026-04-25T10:00:00Z"
    }
  ],
  "pagination": {
    "next_cursor": null,
    "has_more": false
  }
}
```

### GET /api/v1/boats/:id

Get a single boat by ID. Returns 403 if not owned by user.

**Response (200):** Same as single boat object above.

### PUT /api/v1/boats/:id

Update a boat. Only provided fields are updated.

**Request:**
```json
{
  "name": "Luna Azul II",
  "engine_hours": 350.0
}
```

**Response (200):** Updated boat object.

### DELETE /api/v1/boats/:id

Delete a boat and all associated documents, trips, and tracks (CASCADE).

**Response (204):** No content.

---

## Documents

### POST /api/v1/boats/:boatId/documents

Create a document for a boat.

**Request:**
```json
{
  "type": "Seguro RC",
  "custom_name": "Poliza Allianz #12345",
  "expiry_date": "2027-01-15",
  "photo_url": "https://storage.supabase.co/documents/xyz.jpg",
  "notes": "Contactar agente: Juan 600-123-456",
  "last_renewal_date": "2026-01-15",
  "last_renewal_cost": 450.00,
  "last_renewal_provider": "Allianz Seguros",
  "alert_days": [30, 7]
}
```

**Response (201):**
```json
{
  "data": {
    "id": "d0000000-0000-0000-0000-000000000001",
    "boat_id": "b0000000-0000-0000-0000-000000000001",
    "type": "Seguro RC",
    "custom_name": "Poliza Allianz #12345",
    "expiry_date": "2027-01-15",
    "status": "ok",
    "photo_url": "https://storage.supabase.co/documents/xyz.jpg",
    "notes": "Contactar agente: Juan 600-123-456",
    "last_renewal_date": "2026-01-15",
    "last_renewal_cost": 450.00,
    "last_renewal_provider": "Allianz Seguros",
    "alert_days": [30, 7],
    "created_at": "2026-04-25T10:00:00Z",
    "updated_at": "2026-04-25T10:00:00Z"
  }
}
```

### GET /api/v1/boats/:boatId/documents

List all documents for a boat.

**Query params:** `limit`, `cursor`, `status` (optional filter: `ok`, `warning`, `critical`, `expired`)

**Response (200):**
```json
{
  "data": [
    {
      "id": "d0000000-0000-0000-0000-000000000001",
      "boat_id": "b0000000-0000-0000-0000-000000000001",
      "type": "Seguro RC",
      "custom_name": "Poliza Allianz #12345",
      "expiry_date": "2027-01-15",
      "status": "ok",
      "days_until_expiry": 265,
      "photo_url": "https://storage.supabase.co/documents/xyz.jpg",
      "notes": "Contactar agente: Juan 600-123-456",
      "last_renewal_date": "2026-01-15",
      "last_renewal_cost": 450.00,
      "last_renewal_provider": "Allianz Seguros",
      "alert_days": [30, 7],
      "created_at": "2026-04-25T10:00:00Z",
      "updated_at": "2026-04-25T10:00:00Z"
    }
  ],
  "pagination": {
    "next_cursor": null,
    "has_more": false
  }
}
```

### GET /api/v1/documents/:id

Get a single document.

**Response (200):** Single document object.

### PUT /api/v1/documents/:id

Update a document.

**Request:**
```json
{
  "expiry_date": "2027-06-15",
  "last_renewal_date": "2026-06-15",
  "last_renewal_cost": 475.00,
  "last_renewal_provider": "Allianz Seguros"
}
```

**Response (200):** Updated document object (with recalculated `status`).

### DELETE /api/v1/documents/:id

Delete a document.

**Response (204):** No content.

---

## Trips (Logbook)

### POST /api/v1/boats/:boatId/trips

Start a new trip. Defaults to `status: "recording"`.

**Request:**
```json
{
  "departure_port": "Palma de Mallorca",
  "departure_time": "2026-04-25T08:30:00Z",
  "crew_members": ["Carlos", "Maria"]
}
```

**Response (201):**
```json
{
  "data": {
    "id": "t0000000-0000-0000-0000-000000000001",
    "boat_id": "b0000000-0000-0000-0000-000000000001",
    "departure_port": "Palma de Mallorca",
    "arrival_port": null,
    "departure_time": "2026-04-25T08:30:00Z",
    "arrival_time": null,
    "distance_nm": null,
    "duration_minutes": null,
    "engine_hours": null,
    "fuel_consumed_l": null,
    "crew_members": ["Carlos", "Maria"],
    "weather_conditions": null,
    "notes": null,
    "photos": null,
    "status": "recording",
    "created_at": "2026-04-25T08:30:00Z",
    "updated_at": "2026-04-25T08:30:00Z"
  }
}
```

### GET /api/v1/boats/:boatId/trips

List trips for a boat, ordered by `departure_time DESC`.

**Query params:** `limit`, `cursor`, `status` (optional: `recording`, `completed`)

**Response (200):**
```json
{
  "data": [
    {
      "id": "t0000000-0000-0000-0000-000000000001",
      "boat_id": "b0000000-0000-0000-0000-000000000001",
      "departure_port": "Palma de Mallorca",
      "arrival_port": "Port de Soller",
      "departure_time": "2026-04-22T08:30:00Z",
      "arrival_time": "2026-04-22T13:00:00Z",
      "distance_nm": 28.5,
      "duration_minutes": 270,
      "status": "completed",
      "track_point_count": 7,
      "created_at": "2026-04-22T08:30:00Z",
      "updated_at": "2026-04-22T13:00:00Z"
    }
  ],
  "pagination": {
    "next_cursor": null,
    "has_more": false
  }
}
```

### GET /api/v1/trips/:id

Get a single trip with full details including track summary.

**Response (200):** Full trip object with additional `track` field:
```json
{
  "data": {
    "id": "t0000000-0000-0000-0000-000000000001",
    "departure_port": "Palma de Mallorca",
    "arrival_port": "Port de Soller",
    "status": "completed",
    "track": {
      "point_count": 7,
      "max_speed_knots": 7.1,
      "avg_speed_knots": 4.97,
      "bounding_box": {
        "min_lat": 39.5696,
        "max_lat": 39.7700,
        "min_lon": 2.4800,
        "max_lon": 2.6347
      }
    },
    "...": "remaining trip fields"
  }
}
```

### PUT /api/v1/trips/:id

Update a trip. Used to complete a recording or edit details.

**Request (complete a trip):**
```json
{
  "arrival_port": "Port de Soller",
  "arrival_time": "2026-04-22T13:00:00Z",
  "engine_hours": 2.1,
  "fuel_consumed_l": null,
  "weather_conditions": {
    "wind_speed_kts": 12,
    "wind_direction": "SW",
    "sea_state": "moderate",
    "visibility": "good"
  },
  "notes": "Great sailing conditions",
  "status": "completed"
}
```

`distance_nm` and `duration_minutes` are auto-calculated from tracks and timestamps when status changes to `completed`.

**Response (200):** Updated trip object.

---

## Trip Tracks

### POST /api/v1/trips/:id/tracks

Batch insert GPS points for a recording trip.

**Request:**
```json
{
  "points": [
    {
      "lat": 39.5696,
      "lon": 2.6347,
      "speed_knots": 0.0,
      "heading": 315.0,
      "recorded_at": "2026-04-25T08:30:00Z"
    },
    {
      "lat": 39.5800,
      "lon": 2.6200,
      "speed_knots": 5.2,
      "heading": 320.0,
      "recorded_at": "2026-04-25T08:30:10Z"
    }
  ]
}
```

**Response (201):**
```json
{
  "data": {
    "inserted": 2,
    "trip_id": "t0000000-0000-0000-0000-000000000001"
  }
}
```

Returns 409 if the trip status is `completed`.

---

## Events

### GET /api/v1/events

List upcoming nautical events. No auth required (public).

**Query params:**
| Param       | Type   | Description                              |
|-------------|--------|------------------------------------------|
| `limit`     | int    | Items per page (default 20, max 100)     |
| `cursor`    | string | Pagination cursor                        |
| `type`      | string | Filter by event_type                     |
| `lat`       | float  | Center latitude for distance filter      |
| `lon`       | float  | Center longitude for distance filter     |
| `radius_km` | float  | Radius in km (requires lat/lon)          |
| `featured`  | bool   | Only featured events                     |

**Response (200):**
```json
{
  "data": [
    {
      "id": "e0000000-0000-0000-0000-000000000001",
      "name": "Copa del Rey Mapfre",
      "organizer": "Real Club Nautico de Palma",
      "organizer_logo_url": null,
      "description": "One of the most important sailing regattas...",
      "event_type": "regatta",
      "location_name": "Palma de Mallorca",
      "lat": 39.5696,
      "lon": 2.6347,
      "start_date": "2026-07-31T09:00:00+02:00",
      "end_date": "2026-08-06T18:00:00+02:00",
      "boat_classes": ["TP52", "ClubSwan 50", "J80", "ORC"],
      "registration_url": "https://copadelrey.com/inscripcion",
      "documents_url": null,
      "is_featured": true,
      "interest_count": 42,
      "user_interested": false,
      "created_at": "2026-04-01T10:00:00Z"
    }
  ],
  "pagination": {
    "next_cursor": "eyJpZCI6ImUwMDAifQ",
    "has_more": true
  }
}
```

### GET /api/v1/events/:id

Get a single event with full details.

**Response (200):** Single event object (same shape as list item).

### POST /api/v1/events/:id/interest

Mark the authenticated user as interested in an event.

**Response (201):**
```json
{
  "data": {
    "event_id": "e0000000-0000-0000-0000-000000000001",
    "interested": true
  }
}
```

Returns 409 if already interested.

### DELETE /api/v1/events/:id/interest

Remove the authenticated user's interest in an event.

**Response (200):**
```json
{
  "data": {
    "event_id": "e0000000-0000-0000-0000-000000000001",
    "interested": false
  }
}
```

---

## Weather

### GET /api/v1/weather

Get marine weather forecast for a location. Proxies Open-Meteo Marine API.

**Query params:**
| Param | Type  | Required | Description       |
|-------|-------|----------|-------------------|
| `lat` | float | yes      | Latitude          |
| `lon` | float | yes      | Longitude         |
| `days`| int   | no       | Forecast days (1-7, default 3) |

**Response (200):**
```json
{
  "data": {
    "location": {
      "lat": 39.5696,
      "lon": 2.6347
    },
    "current": {
      "time": "2026-04-25T12:00:00Z",
      "temperature_c": 22.5,
      "wind_speed_kts": 12.3,
      "wind_direction_deg": 225,
      "wind_gusts_kts": 18.1,
      "wave_height_m": 0.8,
      "wave_period_s": 5.2,
      "wave_direction_deg": 200,
      "visibility_km": 15.0,
      "weather_code": 1
    },
    "hourly": [
      {
        "time": "2026-04-25T13:00:00Z",
        "temperature_c": 23.0,
        "wind_speed_kts": 13.1,
        "wind_direction_deg": 230,
        "wind_gusts_kts": 19.5,
        "wave_height_m": 0.9,
        "wave_period_s": 5.5,
        "wave_direction_deg": 205,
        "weather_code": 2
      }
    ],
    "daily": [
      {
        "date": "2026-04-25",
        "temperature_max_c": 24.0,
        "temperature_min_c": 18.0,
        "wind_speed_max_kts": 18.1,
        "wind_gusts_max_kts": 25.0,
        "wave_height_max_m": 1.2,
        "sunrise": "2026-04-25T05:15:00Z",
        "sunset": "2026-04-25T19:45:00Z",
        "uv_index_max": 7
      }
    ]
  }
}
```

---

## Common Document Types

For reference, typical document `type` values used in Spain:

| Type                          | Description                          |
|-------------------------------|--------------------------------------|
| `Seguro RC`                   | Third-party liability insurance      |
| `ITB`                         | Technical boat inspection            |
| `Licencia de Navegacion`      | Navigation license                   |
| `Certificado de Navegabilidad`| Seaworthiness certificate            |
| `Titulo PER/PNB/CY`          | Skipper license                      |
| `Reconocimiento Medico`       | Medical certificate                  |
| `Permiso de Pesca`            | Fishing permit                       |
| `Radiooperador`               | Radio operator certificate           |

The `type` field is free text; the above are suggestions for the UI.

---

## Account / Plans

### GET /api/v1/me
Returns the current user's plan and derived entitlements.
`{ plan: "free|pro", is_pro, entitlements: { max_boats, boat_count, can_create_groups, reminder_doc_limit, maintenance_schedules, attachment_limit, gallery_limit, full_readiness, cost_analytics, export_passport, shared_coordination, anomaly_alerts } }`
(legacy `max_boats|boat_count|can_create_groups` also mirrored at the top level).

### PUT /api/v1/me/plan
Dev-only switcher, registered only when `APP_ENV != production`. Body `{ "plan": "free|pro" }`.

### POST /api/v1/webhooks/revenuecat
RevenueCat webhook (no JWT; authenticated by the exact `Authorization` header value in
`REVENUECAT_WEBHOOK_SECRET`). Source of truth for the paid tier: grant events
(`INITIAL_PURCHASE`, `RENEWAL`, …) → `pro`; `EXPIRATION` → `free`; informational events
acknowledged as no-ops. `401` on bad secret.

Plan enforcement returns **402** with code `PLAN_LIMIT` (boat quota) or `PLAN_FORBIDDEN`
(e.g. a `free` user creating a group).

## Trip sharing

### PUT /api/v1/trips/:id/share
Make a trip public. Returns `{ token, url }` (idempotent). URL → public web page.

### DELETE /api/v1/trips/:id/share
Revoke the public link.

### GET /public/trips/:token  (no auth)
Public JSON of a shared trip + track.

### GET /public/trips/:token/view  (no auth)
HTML landing page with a Leaflet/OpenSeaMap map of the route (the share/growth page).

## Maintenance & Expenses (per boat)

### GET / POST /api/v1/boats/:id/maintenance · DELETE …/maintenance/:logId
Service logs `{ type, performed_at, engine_hours?, cost?, provider?, notes?, invoice_url?, photo_urls?[] }`. `photo_urls` (≤10, private bucket signed URLs) is Pro beyond the first (`AttachmentLimit`).

### GET / POST / PUT / DELETE /api/v1/boats/:id/maintenance/tasks[/:taskId]
Recurring plan `{ name, interval_months?, interval_hours? }`. Due state is derived server-side and drives the `maintenance-due` reminder cron (Pro).

### GET / POST /api/v1/boats/:id/expenses · DELETE …/expenses/:expenseId
Expenses `{ category, amount, incurred_on, notes? }`.

### Bookings & expense splits (shared boat, Pro)
`GET/POST/DELETE /api/v1/boats/:id/bookings` — POST `{ starts_at, ends_at, purpose?, force? }`; an unforced overlap returns **409** `BOOKING_OVERLAP` (send `force:true` to create anyway). Expense splits under `/api/v1/expenses/:expenseId/splits` (+ `/settle`) and `/api/v1/boats/:id/expense-splits-summary`.

### GET /api/v1/user/export  (GDPR)
Full JSON export of the user's data (surfaced in Settings → Export my data).

### GET /api/v1/boats/:id/expenses/summary
`{ totals: {category: amount}, total }`.

## Boat sharing (crew / co-owners)

### PUT /api/v1/boats/:id/share-code
Owner: get/create the boat's invite code → `{ code }`.

### POST /api/v1/boats/join
Body `{ code }` → join a boat as a read-only `viewer` member.

### GET /api/v1/boats/shared
Boats shared with the current user.

### GET /api/v1/boats/:id/members · DELETE …/members/:userId
Owner: list / revoke shared members.

### PUT /api/v1/boats/:id/members/:userId/permissions
Owner: set a member's granular permissions. Body (all booleans):
`{ "can_record_trips", "can_manage_expenses", "can_manage_maintenance", "can_view_documents", "can_manage_documents" }`.

### POST /api/v1/boats/:id/leave
Member: leave a shared boat.

**Access model:** base read (boat info + logbook of all members' trips) is allowed for the
owner or any member. Everything else is governed by **per-member permissions** (resolved via
`boatRepo.GetPermissions`; the owner has all): record trips, manage expenses, manage
maintenance, view documents, manage documents. Boat edit/delete and member management stay
owner-only. `GET /api/v1/boats/:id` returns `is_owner` and a `permissions{...}` object;
`GET /api/v1/boats/:id/members` returns each member's `permissions{...}`.

## Weather (extended)

### GET /api/v1/weather/overview?lat&lon
Adds `tides` (hourly sea level) and `tide_extremes` (`{time, height, kind: high|low}`),
omitted where the tidal range is negligible (<0.3 m).
