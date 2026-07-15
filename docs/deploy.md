# Deploy runbook

Step-by-step to take Navis from a green `main` to production: **Supabase Cloud**
(database, auth, storage) → **Railway** (Go API, EU) → **mobile release builds**
→ post-deploy verification.

Everything here is done once by the operator; nothing in this list is automated
yet (the CI deploy job exists but is gated off — see the last section).

> Prerequisites: the Supabase CLI, Railway CLI (`npm i -g @railway/cli`),
> Flutter, an Apple Developer account, and the RevenueCat dashboard from
> `payments-setup.md` already configured.

---

## 1. Supabase Cloud

1. **Create the project** at supabase.com (EU region, e.g. `eu-central-1`).
   Save the project ref, the anon key, the service role key, and the JWT secret
   (Project Settings → API).
2. **Link and push migrations** from `packages/supabase`:
   ```bash
   cd packages/supabase
   supabase link --project-ref <ref>
   supabase db push          # applies all migrations (00001..00032 at the time of writing)
   ```
   Confirm afterwards (SQL editor): `documents` bucket is **private**,
   `sent_notifications` has RLS enabled, and the pagination indexes exist.
3. **Auth**: enable email confirmations (Auth → Providers → Email → "Confirm
   email" ON). Add the app's redirect URLs (Auth → URL Configuration):
   `navis://login-callback`. Enable Sign in with Apple + Google and paste their
   credentials (App Store requires Sign in with Apple if any social login ships).
4. **SMTP**: configure a real sender (Resend) under Auth → SMTP so confirmation
   and reset emails actually send. Sender: `Navis <notifications@aerolume.app>`.
5. **Storage**: the buckets are created by migration `00011`; `00028` makes
   `documents` private. No manual bucket work needed.
6. Note the **pooler** connection string (Project Settings → Database →
   Connection pooling) — it becomes Railway's `DATABASE_URL` (append
   `?sslmode=require`).

## 2. Railway (Go API)

1. New project → Deploy from repo. Set the service **root directory** to
   `apps/api` so `railway.toml` + `Dockerfile` are used.
2. **Environment variables** (Service → Variables) — all secret, all required
   unless noted; `config.Validate()` aborts boot if any is missing or a dev
   default:

   | Var | Value |
   |-----|-------|
   | `APP_ENV` | `production` |
   | `DATABASE_URL` | Supabase pooler URL, `?sslmode=require` |
   | `SUPABASE_URL` | `https://<ref>.supabase.co` |
   | `SUPABASE_JWT_SECRET` | from Supabase API settings |
   | `SUPABASE_SERVICE_ROLE_KEY` | from Supabase API settings (account deletion) |
   | `REVENUECAT_WEBHOOK_SECRET` | the shared secret you set in RevenueCat |
   | `CORS_ALLOWED_ORIGINS` | production origins (comma-separated) |
   | `NOVU_API_KEY` | optional — warns loudly if empty |
   | `SENTRY_DSN` | optional |

3. Deploy. Railway builds the Dockerfile and health-checks `/readyz` (which
   pings the DB) before routing traffic. Note the public URL — it is the
   mobile `API_URL` and the RevenueCat webhook host.
4. **RevenueCat webhook**: in the RevenueCat dashboard set the webhook URL to
   `https://<railway-url>/api/v1/webhooks/revenuecat` with the `Authorization`
   header value = `REVENUECAT_WEBHOOK_SECRET`.

## 3. Mobile release builds

The Makefile targets require every production secret and fail loudly if one is
missing (see `Env.assertProductionConfig`):

```bash
export API_URL=https://<railway-url>
export SUPABASE_URL=https://<ref>.supabase.co
export SUPABASE_ANON_KEY=<anon key>
export SENTRY_DSN=<dsn>
export APP_VERSION=1.0.0
export REVENUECAT_IOS_KEY=appl_xxx        # iOS
export REVENUECAT_ANDROID_KEY=goog_xxx    # Android

make mobile-build-ios     # then Xcode → Archive → App Store Connect
make mobile-build-apk     # or appbundle for Play
```

iOS also needs `GoogleService-Info.plist` in `apps/mobile/ios/Runner/` and the
IAP subscription created in App Store Connect (in "Ready to Submit"), plus the
privacy policy / terms URLs (served at `/legal/privacy` and `/legal/terms`).

## 4. Post-deploy verification

```bash
# API is up and the DB is reachable
curl -fsS https://<railway-url>/readyz            # {"status":"ok"}

# Auth-protected route rejects anonymous
curl -o /dev/null -w '%{http_code}\n' https://<railway-url>/api/v1/boats   # 401

# Legal pages render (App Store Connect URLs)
curl -fsS https://<railway-url>/legal/privacy | head

# Webhook rejects a missing/wrong secret, accepts the real one
curl -o /dev/null -w '%{http_code}\n' -X POST \
  https://<railway-url>/api/v1/webhooks/revenuecat -d '{}'                 # 401
```

Then on a device against the production build: register → receive the
confirmation email → log in; add a boat + document; record a short trip and
confirm the track saves; run the RevenueCat sandbox purchase and confirm the
webhook flips the plan to Pro (the `payments-setup.md` smoke test). Finally,
exercise **Settings → Delete account** and confirm the user can no longer log
in and their storage is gone.

## 5. Enabling automated deploy (later)

CI has a `deploy-api` job (`.github/workflows/ci.yml`) that runs `railway up`
on `main` push. It is gated `if: false`. To enable:

1. Add `RAILWAY_TOKEN` as a repo secret.
2. Change `if: false` to `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`.
