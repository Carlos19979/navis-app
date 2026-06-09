# Navis — Implemented Features (status & continuation notes)

Snapshot of everything built in the "plans + pro features" batch, what is verified,
and what remains (mostly external config). Use this to continue.

## Summary table

| Feature | Backend | Mobile | Verified | Notes / pending |
|---|---|---|---|---|
| **User plans (normal/armador/gestor)** | ✅ | ✅ | E2E + device | Real billing pending (Stripe/RevenueCat). Dev plan switcher in Settings. |
| **Crew editor (chips)** | ✅ (participant names) | ✅ | tests + device | Auto-fills from RSVP "going" on group regattas. |
| **Trip share (public link + web page)** | ✅ | ✅ link | E2E | Image card (F2a) still pending. |
| **Maintenance & expenses** | ✅ | ✅ | E2E + device | Maintenance schedules/reminders cron not built (logs+expenses only). |
| **Tides + navigation window** | ✅ | ✅ | E2E | Open-Meteo `sea_level_height_msl`; hidden when range <0.3m (Mediterranean). |
| ~~Float plan (destination/ETA/shore contact)~~ | **removed** | **removed** | — | Removed 2026-06-09: phone-based auto-alert can't be a reliable rescue net (alerted the owner, not the shore contact; needs SMS/satellite). DB columns (`trips.destination/eta/shore_contact_*`) + dormant Go/Dart fields left in place. Trip *sharing* (F2) stays. |
| **Sign in with Apple/Google** | n/a (provider-agnostic JWT) | ✅ code + URL scheme | build only | **Needs external config**: Supabase providers + Apple/Google credentials + iOS capability. iOS Info.plist URL scheme NOT committed (lives in local ios/ hacks) — re-add `CFBundleURLTypes` scheme `navis` when wiring. |
| **Boat sharing (crew/co-owners)** | ✅ | ✅ | 🔒 security-tested | Roles: `viewer` (read) / `editor` (read + **record trips**). Docs/expenses/boat-edit stay owner-only. |

## Plans / tiers
- Table `profiles(plan)` ∈ `normal|armador|gestor`, default `normal` (auto-created).
- Limits: boats `1 / 2 / 15`; group creation only `armador|gestor`. Map/weather/join-events open to all.
- Enforced in `BoatService.Create` and `GroupService.Create` → HTTP **402** with code `PLAN_LIMIT` / `PLAN_FORBIDDEN`.
- `GET /api/v1/me` → `{plan, max_boats, boat_count, can_create_groups}`.
- `PUT /api/v1/me/plan` → dev switcher (replace with payment webhook in prod).
- Mobile: `accountProvider`; FAB gating in Boats & Groups; plan badge in Profile; **DEV plan switcher** in Settings.

## Boat sharing — security model (important)
- Table `boat_members(boat_id, user_id, role)` with role `viewer|editor` + `boats.share_code`.
- **Reads** (boat, documents, trips+tracks, maintenance, expenses) allowed for **owner OR any member** via `boatRepo.HasAccess` / `GetByIDAccessible`, reading **as the owner's scope**. The boat **logbook** lists *all* members' trips (`tripRepo.ListByBoatAll`).
- **editor role** may additionally **record trips** (`TripService.Create` checks `boatRepo.CanEdit` = owner OR editor). `GET /boats/:id` returns `can_record`.
- **All other writes** (documents, maintenance, expenses, boat edit/delete) stay strict owner-only.
- Verified with two accounts: viewer record-trip 403; owner promotes to editor (204); editor record-trip 201 and it shows in the owner's logbook; editor expense write still 404; non-member 404 everywhere.
- Mobile: "Compartir barco" (owner: code + members list with a **viewer/editor toggle** + remove), "Unirse a un barco" (code), "Compartidos conmigo" section. Shared boat shows documents/logbook/maintenance read-only; the logbook record FAB appears only when `can_record`.

## Cron jobs (in `RegattaNotifier`, all UTC)
- `0 9 * * *` regatta reminders (next 36h) → group members.
- `*/15 * * * *` live-event alert → interested users.
- Dedup via `sent_notifications`. Document-expiry cron unchanged.
- (Removed: overdue float-plan alert — see Float plan row.)

## Migrations added (00018–00024)
`sent_notifications`, `event stream urls`, `profiles`, `trip share_token`,
`maintenance_logs`+`expenses`, `trip float_plan`, `boat_members`+`boats.share_code`.

## Test data (local DB)
- `test@navis.app` / `password123` → plan **gestor** (owner of seeded boats).
- `crew@navis.app` / `password123` → plan **normal**; already a **member of boat "Rayo Veloz"** and the public group "Club Náutico de Prueba".

## Pending / next steps
1. **F1 external config**: Supabase Apple+Google providers, Apple Developer + Google Cloud client IDs, iOS "Sign in with Apple" capability, re-add iOS URL scheme. Native Apple sheet (App Store requirement) instead of web OAuth.
2. **Push delivery**: `NOVU_API_KEY` + Novu workflows (`regatta-reminder`, `regatta-rsvp`, `group-*`, `event-live`, `float-plan-overdue`) + FCM (`GoogleService-Info.plist` iOS). Novu must forward `type`/`id` into FCM data for deep-links.
3. **Payments** for real plan changes (webhook → `profiles.plan`).
4. **F2a** trip image card (capture a stats card → share image).
5. **Maintenance schedules + reminders** (due by engine-hours or date).
6. Optional: editor role for boat co-owners (write access), maintenance polish across more screens.
7. (If float plan is ever revived: notify the **shore contact** via SMS/email — not the owner — with a clear "not a rescue system" disclaimer.)

## Local run reminder
colima + `supabase start -x studio`; native Go API on :8080; iPhone uses the Mac's
`.local` hostname (kept in `env.dart`, NOT committed). API restart: build + run `bin/server`.
