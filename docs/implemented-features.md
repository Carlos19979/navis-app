# Navis — Implemented Features (status & continuation notes)

Snapshot of everything built in the "plans + pro features" batch, what is verified,
and what remains (mostly external config). Use this to continue.

## Summary table

| Feature | Backend | Mobile | Verified | Notes / pending |
|---|---|---|---|---|
| **User plans (Free / Pro)** | ✅ | ✅ code | E2E (API+DB) | RevenueCat IAP + webhook wired; paywall + gating in mobile. Pending: RevenueCat/store product config + mobile device sandbox test. See Plans section. |
| **Crew editor (chips)** | ✅ (participant names) | ✅ | tests + device | Auto-fills from RSVP "going" on group regattas. |
| **Trip share (public link + web page)** | ✅ | ✅ link | E2E | Image card (F2a) still pending. |
| **Maintenance & expenses** | ✅ | ✅ | E2E + device | Maintenance schedules/reminders cron not built (logs+expenses only). |
| **Tides + navigation window** | ✅ | ✅ | E2E | Open-Meteo `sea_level_height_msl`; hidden when range <0.3m (Mediterranean). |
| ~~Float plan (destination/ETA/shore contact)~~ | **removed** | **removed** | — | Removed 2026-06-09: phone-based auto-alert can't be a reliable rescue net (alerted the owner, not the shore contact; needs SMS/satellite). DB columns (`trips.destination/eta/shore_contact_*`) + dormant Go/Dart fields left in place. Trip *sharing* (F2) stays. |
| **Sign in with Apple/Google** | n/a (provider-agnostic JWT) | ✅ code + URL scheme | build only | **Needs external config**: Supabase providers + Apple/Google credentials + iOS capability. iOS Info.plist URL scheme NOT committed (lives in local ios/ hacks) — re-add `CFBundleURLTypes` scheme `navis` when wiring. |
| **Boat sharing (crew/co-owners)** | ✅ | ✅ | 🔒 security-tested | **Granular per-member permissions** (record trips · manage expenses · manage maintenance · view documents · manage documents). Boat edit/delete + member management stay owner-only. |

## Plans / tiers — Free vs Pro (migration 00027)
Collapsed the legacy `normal|armador|gestor` tiers into **Free / Pro** (single paid
tier; a B2B "fleet" tier is future work). Migration `00027_plan_free_pro.sql` remaps
`normal→free`, `armador|gestor→pro`, sets default `free` and `CHECK (free|pro)`.

- Table `profiles(plan)` ∈ `free|pro`, default `free` (auto-created). `Plan` helpers in
  `domain/profile.go`: `IsPro`, `MaxBoats` (1/3), `CanCreateGroups` (Pro), `ReminderDocLimit`
  (Free=1, Pro=unlimited/-1), `CanUseMaintenanceSchedules` (Pro), `AttachmentLimit` (Free=1).
- Enforced in `BoatService.Create`, `GroupService.Create` and the expiration cron →
  HTTP **402** (`PLAN_LIMIT` / `PLAN_FORBIDDEN`). Free reminders are limited to the single
  nearest-expiry document (`cron.allowedDocs`).
- `GET /api/v1/me` → `{plan, is_pro, entitlements{max_boats, boat_count, can_create_groups,
  reminder_doc_limit, maintenance_schedules, attachment_limit}}` (+ legacy top-level mirrors).
- **RevenueCat webhook** `POST /api/v1/webhooks/revenuecat` (secret-authenticated, outside
  JWT) is the source of truth for the paid tier: grant events → `pro`, `EXPIRATION` → `free`
  (`handler/webhook_handler.go`, `planForEvent`). `PUT /api/v1/me/plan` remains a dev switcher,
  only registered when `APP_ENV != production`.
- Mobile: `Account{plan,isPro,entitlements}` from `/me`; `isProProvider` combines server plan
  with the live RC entitlement for instant post-purchase unlock; **RevenueCat** wrapped in
  `features/billing/billing.dart` (only file importing `purchases_flutter`); **paywall sheet**
  (`features/billing/presentation/paywall_sheet.dart`, monthly/annual + Restore) shown when
  gating Boats/Groups FABs; dev plan switcher in Settings gated to `kDebugMode`.
- Verified E2E (local API + DB): free `/me` → 402 on 2nd boat & group; webhook grant → pro
  (max_boats 3, groups, unlimited reminders); pro creates boat+group; webhook expiration → free;
  bad webhook secret → 401.
- **Pending external config (not code):** RevenueCat products (`navis_pro_monthly` 3,99 € /
  `navis_pro_yearly` 29,99 €) + entitlement `pro` + webhook secret + App Store/Play subscriptions;
  Novu `document-expiry` workflow with an **Email (Resend)** step; `--dart-define` RC keys.

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
- Dedup via `sent_notifications`. Document-expiry cron now applies the plan reminder quota (Free=1 nearest doc).
- (Removed: overdue float-plan alert — see Float plan row.)

## Migrations added (00018–00027)
`sent_notifications`, `event stream urls`, `profiles`, `trip share_token`,
`maintenance_logs`+`expenses`, `trip float_plan`, `boat_members`+`boats.share_code`,
`invoice_url`, `boat_member_permissions`, **`00027 plan free/pro`**.

## Test data (local DB)
- `test@navis.app` / `password123` → owner of seeded boats. Plan defaults to **free** after `db reset`; flip via the dev switcher or the RevenueCat webhook.
- `crew@navis.app` / `password123` → **member of boat "Rayo Veloz"** and the public group "Club Náutico de Prueba".

## Pending / next steps
1. **RevenueCat / payments external config** (code done): create products `navis_pro_monthly` (3,99 €) + `navis_pro_yearly` (29,99 €) in App Store Connect / Play Console; RevenueCat entitlement `pro` + webhook (`REVENUECAT_WEBHOOK_SECRET`) → `…/api/v1/webhooks/revenuecat`; `--dart-define REVENUECAT_IOS_KEY/REVENUECAT_ANDROID_KEY`; run `flutter pub get` (adds `purchases_flutter`); device **sandbox** purchase test.
2. **Reminder delivery**: `NOVU_API_KEY` + Novu `document-expiry` workflow with an **Email (Resend)** step (works without FCM). Other workflows (`regatta-*`, `group-*`, `event-live`). FCM push (`GoogleService-Info.plist`) as fast-follow; Novu forwards `type`/`id` for deep-links.
3. **F1 external config**: Supabase Apple+Google providers, Apple Developer + Google Cloud client IDs, iOS "Sign in with Apple" capability, re-add iOS URL scheme. Native Apple sheet (App Store requirement) — **blocking for App Store approval alongside IAP review**.
4. **F2a** trip image card (capture a stats card → share image).
5. **Maintenance schedules + reminders** (due by engine-hours or date) — anchor Pro feature, gated by `maintenance_schedules` entitlement.
6. Optional: maintenance polish across more screens.
7. (If float plan is ever revived: notify the **shore contact** via SMS/email — not the owner — with a clear "not a rescue system" disclaimer.)

## Local run reminder
colima + `supabase start -x studio`; native Go API on :8080; iPhone uses the Mac's
`.local` hostname (kept in `env.dart`, NOT committed). API restart: build + run `bin/server`.
