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
  "engine_hours": 342.5
}
```

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
Returns the current user's plan and derived limits.
`{ plan, max_boats, boat_count, can_create_groups }`

### PUT /api/v1/me/plan
Dev/testing only (replace with a payment webhook). Body `{ "plan": "normal|armador|gestor" }`.

Plan enforcement returns **402** with code `PLAN_LIMIT` (boat quota) or `PLAN_FORBIDDEN`
(e.g. a `normal` user creating a group).

## Trip sharing & float plan

### PUT /api/v1/trips/:id/share
Make a trip public. Returns `{ token, url }` (idempotent). URL → public web page.

### DELETE /api/v1/trips/:id/share
Revoke the public link.

### GET /public/trips/:token  (no auth)
Public JSON of a shared trip + track.

### GET /public/trips/:token/view  (no auth)
HTML landing page with a Leaflet/OpenSeaMap map of the route (the share/growth page).

### PUT /api/v1/trips/:id/float-plan
Body `{ destination, eta, shore_contact_name, shore_contact_phone }` (all optional).
An overdue cron alerts the owner if a recording trip passes its ETA + 30m.

## Maintenance & Expenses (per boat)

### GET / POST /api/v1/boats/:id/maintenance · DELETE …/maintenance/:logId
Service logs `{ type, performed_at, engine_hours?, cost?, provider?, notes? }`.

### GET / POST /api/v1/boats/:id/expenses · DELETE …/expenses/:expenseId
Expenses `{ category, amount, incurred_on, notes? }`.

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

### POST /api/v1/boats/:id/leave
Member: leave a shared boat.

**Access model:** boat + its documents/trips/maintenance/expenses are **readable** by the
owner or any member; **all writes are owner-only**. `GET /api/v1/boats/:id` includes `is_owner`.

## Weather (extended)

### GET /api/v1/weather/overview?lat&lon
Adds `tides` (hourly sea level) and `tide_extremes` (`{time, height, kind: high|low}`),
omitted where the tidal range is negligible (<0.3 m).
