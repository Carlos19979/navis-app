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
| **Boat sharing (crew/co-owners)** | ✅ | ✅ | 🔒 security-tested | **Granular per-member permissions** (record trips · manage expenses · manage maintenance · view documents · manage documents). Boat edit/delete + member management stay owner-only. |

## Plans / tiers
- Table `profiles(plan)` ∈ `normal|armador|gestor`, default `normal` (auto-created).
- Limits: boats `1 / 2 / 15`; group creation only `armador|gestor`. Map/weather/join-events open to all.
- Enforced in `BoatService.Create` and `GroupService.Create` → HTTP **402** with code `PLAN_LIMIT` / `PLAN_FORBIDDEN`.
- `GET /api/v1/me` → `{plan, max_boats, boat_count, can_create_groups}`.
- `PUT /api/v1/me/plan` → dev switcher (replace with payment webhook in prod).
- Mobile: `accountProvider`; FAB gating in Boats & Groups; plan badge in Profile; **DEV plan switcher** in Settings.

## Boat sharing — security model (important)
- Table `boat_members(boat_id, user_id, role, can_record_trips, can_manage_expenses, can_manage_maintenance, can_view_documents, can_manage_documents)` + `boats.share_code`. A new member joins **view-only** (only `can_view_documents` true). The `role` column is legacy/unused; enforcement is on the flags.
- **`boatRepo.GetPermissions(userID, boatID)`** resolves the set: owner → all true; member → their flags; non-member → access=false. The owner has every permission implicitly.
- **Base read** (boat info + logbook of all members' trips via `tripRepo.ListByBoatAll`) is allowed for owner or any member (`HasAccess` / `GetByIDAccessible`). Maintenance/expense lists are boat-scoped so every member's entries show.
- **Per-permission enforcement:** record trips → `CanRecordTrips` (`TripService.Create`); expenses create/edit/delete → `CanManageExpenses`; maintenance create/edit/delete → `CanManageMaintenance`; document list/detail → `CanViewDocuments`; document create/edit/delete → `CanManageDocuments`. Document list/update/delete became boat-scoped (top-level `/documents/:id` resolves the boat from the doc).
- **Owner-only always:** boat edit/delete, member management (`PUT /boats/:id/members/:userId/permissions`, remove).
- `GET /boats/:id` returns `permissions{...}`; `GET /boats/:id/members` returns each member's `permissions{...}`.
- Verified with two accounts: viewer record-trip/expense 403; owner grants record-trips+manage-expenses (PUT 204); member then records trips 201, logs expenses 201, but maintenance 403 and document-view 403; base expense *read* still 200; non-member 404.
- Mobile: `Boat.permissions` + `BoatPermissions`; "Compartir barco" members list is a **per-member 5-toggle editor**; the documents tile, logbook record FAB, maintenance/expense FABs+edit, and document FAB are each gated on the matching permission.

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
