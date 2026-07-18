# Navis — Implemented Features (status & continuation notes)

Snapshot of everything built in the "plans + pro features" batch, what is verified,
and what remains (mostly external config). Use this to continue.

## Summary table

| Feature | Backend | Mobile | Verified | Notes / pending |
|---|---|---|---|---|
| **User plans (Free / Pro)** | ✅ | ✅ code | E2E (API+DB) | RevenueCat IAP + webhook wired; paywall + gating in mobile. Pending: RevenueCat/store product config + mobile device sandbox test. See Plans section. |
| **Crew editor (chips)** | ✅ (participant names) | ✅ | tests + device | Auto-fills from RSVP "going" on group regattas. |
| **Trip share (public link + web page)** | ✅ | ✅ link | E2E | Image card (F2a) still pending. |
| **Maintenance & expenses** | ✅ | ✅ | E2E + device | Recurring tasks + **due-reminder cron** (#47) + service-log photos (#50). Expenses screen month/year redesign pending. |
| **Tides + navigation window** | ✅ | ✅ | E2E | Open-Meteo `sea_level_height_msl`; hidden when range <0.3m (Mediterranean). |
| ~~Float plan (destination/ETA/shore contact)~~ | **removed** | **removed** | — | Removed 2026-06-09: phone-based auto-alert can't be a reliable rescue net (alerted the owner, not the shore contact; needs SMS/satellite). DB columns (`trips.destination/eta/shore_contact_*`) + dormant Go/Dart fields left in place. Trip *sharing* (F2) stays. |
| **Sign in with Apple/Google** | n/a (provider-agnostic JWT) | ✅ code + URL scheme | build only | **Needs external config**: Supabase providers + Apple/Google credentials + iOS capability. iOS Info.plist URL scheme NOT committed (lives in local ios/ hacks) — re-add `CFBundleURLTypes` scheme `navis` when wiring. |
| **Boat sharing (crew/co-owners)** | ✅ | ✅ | 🔒 security-tested | **Granular per-member permissions** (record trips · manage expenses · manage maintenance · view documents · manage documents). Boat edit/delete + member management stay owner-only. |

## Three-tier plans — Free / Plus / Pro (2026-07-18)
Split the single paid tier into **Plus** (individual owner) and **Pro** (shared boat /
data). No DB migration — `profiles.plan` gains value `plus` (validated in `Plan.Valid`).
- **Plus** (4,99 €/mes · 39,99 €/año): 2 boats, unlimited reminders, maintenance schedules
  + cron, full readiness, **anchor alarm**, gallery/attachments. **Pro** (8,99 €/mes ·
  69,99 €/año): everything in Plus + cost intelligence/€L/anomalies, shared coordination
  (bookings + splits), passport PDF, clubs, 5 boats.
- Go: `Plan.rank()`/`atLeast()`; each `CanUse*`/limit is per-tier. Webhook maps entitlement
  `plus`/`pro` → plan (`highestTier`). `oneof=free plus pro`.
- Flutter: `PlanTier` enum with capability getters (mirror of `profile.go`) +
  `effectiveTierProvider` (max of server plan and live RC tier) in `billing.dart`; every gate
  reads the specific capability (`.canAnchorAlarm`, `.canCostAnalytics`, …). Paywall rebuilt to
  a **Plus vs Pro comparison** (`showPaywall(requiredTier:)`). Two RC entitlements.
- Grandfathering: existing `pro` users keep Pro (superset); store honours their price.

## Plans / tiers — Free vs Pro (migration 00027) — superseded by the 3-tier split above
Collapsed the legacy `normal|armador|gestor` tiers into **Free / Pro** (later split into
Free / Plus / Pro, see above; a B2B "fleet" tier is future work). Migration `00027_plan_free_pro.sql` remaps
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
- **Pending external config (not code):** RevenueCat 4 products (`navis_plus_monthly` 4,99 € /
  `navis_plus_yearly` 39,99 € / `navis_pro_monthly` 8,99 € / `navis_pro_yearly` 69,99 €) +
  entitlements `plus` and `pro` + webhook secret + App Store/Play subscriptions; Novu `document-expiry` workflow with an **Email (Resend)** step;
  `--dart-define` RC keys.

## Differentiating features batch (2026-07-12)

Six Pro-gated features built on the plan-gating pattern (`domain/profile.go` capability →
`Entitlements` DTO → mobile `Account` → `showPaywall`). Each shipped as its own PR, CI-green.

- **Boat readiness score** (`GET /boats/{id}/readiness`, `features/readiness/`): synthesizes
  document + safety-gear + maintenance status into a 0-100 score and go/no-go signal
  (`ready`/`attention`/`not_ready`) + attention list. **Free = documents-only**; Pro adds gear +
  maintenance (`CanUseFullReadiness`). Glanceable card on the single-boat home + detail screen.
- **Cost intelligence** (`GET /boats/{id}/cost-analytics`, `features/cost/`, Pro
  `CanUseCostAnalytics`): total/category spend, last-12-months, cost/NM, cost/trip, fuel L/NM.
  Entry = insights action in the maintenance app bar (paywall for Free).
- **Boat passport (PDF)** (`features/passport/`, dep `pdf`, Pro `CanExportPassport`): exportable
  dossier (boat, documents+expiry, maintenance history, expenses) shared via `share_plus`.
- **Shared-boat coordination** (migration `00030_shared_boat`, `features/shared/`, Pro
  `CanUseSharedCoordination`): `bookings` (list + **month calendar** #48, API-validated
  overlap #46) + `expense_splits` (splits UI shipped). Access via `can_access_boat` + permissions.
- **Anomaly alerts** (`GET /boats/{id}/anomalies`, `features/anomaly/`, Pro
  `CanUseAnomalyAlerts`): flags completed trips with fuel/NM >30% over the boat's baseline
  (min 3-trip sample). Surfaced on the cost analytics screen.
- **Expiry-threshold single source**: `NavisDateUtils.expiryCriticalDays=30 / expiryWarningDays=90`
  (aligned with the `documents.status` trigger) + `statusFor()`; badge + summary consume it.

**Monetization update:** Pro price set to **€29.99/yr + €3.99/mo, 7-day trial** (RevenueCat
product config pending; webhook already maps `pro`). New entitlements in `/me`:
`full_readiness, cost_analytics, export_passport, shared_coordination, anomaly_alerts`.

**Scrapped (2026-07-12):** float plan (Phase 4) and auto trip detection (Phase 7) were dropped
entirely — float plan's shore-contact alert needs external email/SMS infra (Resend/Novu/Twilio)
that wasn't worth the payoff; auto-detection's background geofencing wasn't a priority.

## Product round vs sector (2026-07-17, PRs #46–#51)

Competitor analysis (TheBoatApp, PlanM8, BoatOn, LookOver, savvy navvy, Navily,
Saillogger) turned into shipped features. All merged, CI-green, verified against
the 9-journey E2E suite on the simulator. Analysis in
`.claude/plans/refactored-bouncing-hamming.md`.

- **Booking overlap validated by the API** (#46): `CreateBooking(force)` — an
  unforced overlapping booking returns **409 `BOOKING_OVERLAP`** (repo
  `HasOverlap`; overlaps stay advisory, `force:true` creates anyway). Closes the
  two-users-book-at-once race the client-only check missed. Mobile maps 409 →
  `BookingOverlapException` → confirm dialog → force retry; list cards show an
  **amber overlap badge** when two active bookings intersect.
- **Maintenance-due reminder cron** (#47): daily 08:15 UTC → new Novu workflow
  **`maintenance-due`** (now **9 workflows**). Pro-gated
  (`CanUseMaintenanceSchedules`, fails closed); Free still sees the due state
  in-app. Deduped per task+status+occurrence via `maintenance_notification_logs`
  (migration `00034`) with a `due_key` that changes after servicing so the next
  season notifies again. `MaintenanceService.DueNotices` reuses `evaluateTask`
  (one definition of "due"). **This is the roadmap's pending anchor Pro
  feature (old item 5) — now done.**
- **Bookings calendar view** (#48): hand-rolled month grid (no new dep) with
  per-day dots (yours/others/amber overlap), month nav, day-tap filter and a
  "book this day" shortcut. Toggle list↔calendar; the FAB flow is unchanged.
- **Document form polish** (#49): `alert_days` now a multi-select chip set
  (30/15/7/1 + custom; the full array is sent, not just the first) — the API
  always supported the array; **custom document type** (`custom` + `custom_name`,
  e.g. fishing permit / MARPOL) now offered and rendered in card/detail/passport;
  **Export my data** button in Settings (GDPR, `GET /user/export` → share sheet);
  **boat photo in the passport PDF** header. API fix: `UpdateDocumentRequest`
  now accepts `custom_name` and validates `type` against the canonical enum.
- **Photos on maintenance logs + boat gallery** (#50): `photo_urls TEXT[]` on
  `maintenance_logs` (migration `00035`) and `boats` (`00036`). Service evidence
  (impeller/anode wear) on service logs, reusing the invoice upload/compression/
  signed-URL machinery; horizontal gallery on boat detail. New shared widgets
  `NavisPhotoStrip` + `NavisPhotoViewer` (fullscreen swipe+zoom). Gating:
  maintenance photos reuse `AttachmentLimit` (Free 1/log, Pro ∞, cap 10); gallery
  uses a new `Plan.GalleryLimit()` (Free 1 = cover only, Pro 10) — server-enforced
  402 + client paywall. New entitlements `attachment_limit`, `gallery_limit`.

**Decided (2026-07-17):** fuel log scrapped (expenses already cover the money and
the per-trip fuel field gives basic L/NM). Instead: **expenses screen redesign**
(month/year period selector + category/date filters instead of one infinite list
with a grand total) — done. **Anchor alarm (B1)** chosen as the next big Pro
feature — done (see below).

## Anchor watch (B1) — Pro (2026-07-18)

Anchor-drift alarm, the sector's classic paid single-function app (Anchor Pro,
AnchorSafe). Reuses ~70% of existing infra; new feature lives in
`features/anchor/`. Plan in `.claude/plans/refactored-bouncing-hamming.md`.

- **Scope v1 — practical parity WITHOUT iOS Critical Alerts.** Matches Anchor
  Pro (background location + `audio` background mode so the alarm sounds while
  locked + local notification) but does **not** pursue Apple's Critical Alerts
  entitlement (would sound through silent/DND but needs Apple approval —
  deferred to a v2). Ships with a best-effort reliability disclaimer, like the
  whole sector ("keep your phone plugged in overnight").
- **Provider** `anchor_watch_provider.dart` (`StateNotifier`, NOT autoDispose):
  drop anchor at the current fix → arm → background-capable `getPositionStream`
  drives a drift check (`DistanceUtils.calculateDistance` × 1852 → metres).
  Anti-false-alarm: ignores fixes with accuracy worse than the radius + requires
  2 consecutive out-of-circle fixes. Default radius 40 m (clamp 15–150).
  Methods: dropAnchor / adjustRadius / recenter / silenceAlarm / disarm /
  recoverWatch / ensureStream.
- **Persistence**: singleton `anchor_watch` row (sqlite v4, `local_database.dart`)
  survives an app kill; the dashboard silently re-arms it on relaunch (mirrors
  the trip-recording recover flow).
- **Alarm** `core/alarm/alarm_service.dart`: looping `assets/sounds/anchor_alarm.wav`
  (audioplayers), sustained vibration, high-importance notification channel
  (`anchor-alarm`, full-screen intent on Android). Initialised in `main.dart`.
- **Gating**: `Plan.CanUseAnchorAlarm()` → `Entitlements.anchor_alarm` →
  `Account.anchorAlarm`; **client-only** (no server endpoint), UI-gated via
  `showPaywall`. Entry from the focus dashboard (blocked while a trip is
  recording — both use the GPS stream).
- **Native**: iOS `Info.plist` adds `audio` to `UIBackgroundModes`; Android adds
  `USE_FULL_SCREEN_INTENT` + `VIBRATE`. New deps: `flutter_local_notifications`,
  `audioplayers`, `vibration`, `wakelock_plus`.
- **Tests**: 9 provider unit tests (arm/drift/silence/recenter/disarm/recover/
  accuracy-filter, fake GPS + mocked alarm), 1 screen widget test (Free paywall
  gate), Go `CanUseAnchorAlarm` + DTO tests, E2E journey **J10** (arm → drift →
  alarm banner → silence → disarm; disarms at the end so the long-lived watch
  doesn't leak into later journeys). EN+ES i18n.

## Boat sharing — security model (important)
- Table `boat_members(boat_id, user_id, role, can_record_trips, can_manage_expenses, can_manage_maintenance, can_view_documents, can_manage_documents)` + `boats.share_code`. A new member joins **view-only** (only `can_view_documents` true). The `role` column is legacy/unused; enforcement is on the flags.
- **`boatRepo.GetPermissions(userID, boatID)`** resolves the set: owner → all true; member → their flags; non-member → access=false. The owner has every permission implicitly.
- **Base read** (boat info + logbook of all members' trips via `tripRepo.ListByBoatAll`) is allowed for owner or any member (`HasAccess` / `GetByIDAccessible`). Maintenance/expense lists are boat-scoped so every member's entries show.
- **Per-permission enforcement:** record trips → `CanRecordTrips` (`TripService.Create`); expenses create/edit/delete → `CanManageExpenses`; maintenance create/edit/delete → `CanManageMaintenance`; document list/detail → `CanViewDocuments`; document create/edit/delete → `CanManageDocuments`. Document list/update/delete became boat-scoped (top-level `/documents/:id` resolves the boat from the doc).
- **Owner-only always:** boat edit/delete, member management (`PUT /boats/:id/members/:userId/permissions`, remove).
- `GET /boats/:id` returns `permissions{...}`; `GET /boats/:id/members` returns each member's `permissions{...}`.
- Verified with two accounts: viewer record-trip/expense 403; owner grants record-trips+manage-expenses (PUT 204); member then records trips 201, logs expenses 201, but maintenance 403 and document-view 403; base expense *read* still 200; non-member 404.
- Mobile: `Boat.permissions` + `BoatPermissions`; "Compartir barco" members list is a **per-member 5-toggle editor**; the documents tile, logbook record FAB, maintenance/expense FABs+edit, and document FAB are each gated on the matching permission.

## Cron jobs (all UTC)
- `0 8 * * *` document-expiry (`ExpirationChecker`) → owners; plan reminder quota (Free=1 nearest doc); dedup `notification_logs`.
- `15 8 * * *` maintenance-due (`MaintenanceChecker`, #47) → Pro owners; dedup `maintenance_notification_logs`.
- `0 9 * * *` regatta reminders (next 36h) → group members (`RegattaNotifier`).
- `*/15 * * * *` live-event alert → interested users. Dedup via `sent_notifications`.
- (Removed: overdue float-plan alert — see Float plan row.)

## Migrations added (00018–00029)
`sent_notifications`, `event stream urls`, `profiles`, `trip share_token`,
`maintenance_logs`+`expenses`, `trip float_plan`, `boat_members`+`boats.share_code`,
`invoice_url`, `boat_member_permissions`, **`00027 plan free/pro`**,
**`00028 security hardening`** (RLS on `sent_notifications`, private `documents`
bucket + signed-URL policy), **`00029 pagination indexes`**,
**`00030 shared_boat`** (`bookings` + `expense_splits` + `can_access_boat` helper).

## Migrations 00031–00036
`00031`/`00032` maintenance tasks (per-boat recurring plan; `00031` added interval
columns to `boats` that `00032` moved to `maintenance_tasks`), `00033` home_port
nullable (optional end to end), **`00034` `maintenance_notification_logs`** (cron
dedup), **`00035` `maintenance_logs.photo_urls`**, **`00036` `boats.photo_urls`**.

## Launch hardening (2026-07-11, plan `docs/launch-hardening-plan.md`)
Five merged phases getting the app from "feature-complete" to launchable:
- **Backend security** — fail-fast config validation, real Sentry capture,
  complete account deletion (Storage + `auth.users` cascade), RLS + private
  documents bucket, rate-limit by real IP, body limits, `/readyz` DB ping,
  device-token IDOR fix.
- **App Store compliance** — in-app account deletion, camera/photo Info.plist
  keys, scoped ATS, privacy/terms served at `/legal/*`, full i18n, email-
  confirmation signup flow.
- **Backend quality** — keyset cursor pagination (one query per page),
  handler/service dedup, consumer-side service interfaces, async notifier,
  plan-gating tests.
- **Mobile quality** — crash-safe trip recording (`TripRecordingNotifier` +
  sqlite per-fix persistence, resume-on-relaunch), signed document URLs,
  shared dialog/FAB widgets, image mem-caching. Deferred: full autoDispose
  sweep, `.select()`, sealed `Failure` adoption (needs on-device verification).
- **Deploy** — `railway.toml`, release-build guards + production config assert,
  runbook `docs/deploy.md`, CI deploy job (gated off until Railway exists).

## Test data (local DB)
- `test@navis.app` / `password123` → owner of seeded boats. Plan defaults to **free** after `db reset`; flip via the dev switcher or the RevenueCat webhook.
- `crew@navis.app` / `password123` → **member of boat "Rayo Veloz"** and the public group "Club Náutico de Prueba".

## Pending / next steps
1. **RevenueCat / payments external config** (code done): create products `navis_pro_monthly` (3,99 €) + `navis_pro_yearly` (29,99 €) in App Store Connect / Play Console; RevenueCat entitlement `pro` + webhook (`REVENUECAT_WEBHOOK_SECRET`) → `…/api/v1/webhooks/revenuecat`; `--dart-define REVENUECAT_IOS_KEY/REVENUECAT_ANDROID_KEY`; run `flutter pub get` (adds `purchases_flutter`); device **sandbox** purchase test.
2. **Reminder delivery**: `NOVU_API_KEY` + Novu `document-expiry` workflow with an **Email (Resend)** step (works without FCM). Other workflows (`regatta-*`, `group-*`, `event-live`). FCM push (`GoogleService-Info.plist`) as fast-follow; Novu forwards `type`/`id` for deep-links.
3. **F1 external config**: Supabase Apple+Google providers, Apple Developer + Google Cloud client IDs, iOS "Sign in with Apple" capability, re-add iOS URL scheme. Native Apple sheet (App Store requirement) — **blocking for App Store approval alongside IAP review**.
4. **F2a** trip image card (capture a stats card → share image).
5. ✅ **Maintenance schedules + reminders** — DONE (#47, cron `maintenance-due`).
   Novu config: add a `maintenance-due` workflow (Push+Email) alongside the rest.
6. **Expenses screen redesign** (month/year + category/date filters) — planned, not built.
7. **Anchor alarm (B1)** — next big Pro feature; planned, not built (needs iOS
   background location + critical-alert design).
8. (If float plan is ever revived: notify the **shore contact** via SMS/email — not the owner — with a clear "not a rescue system" disclaimer.)

## Local run reminder
colima + `supabase start -x studio`; native Go API on :8080; iPhone uses the Mac's
`.local` hostname (kept in `env.dart`, NOT committed). API restart: build + run `bin/server`.
