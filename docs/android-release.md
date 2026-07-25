# Android / Google Play release runbook

Status: code is Play-ready; the steps below are the manual/config work that
needs the developer's own credentials and the verified Play Console account.
Companion of `docs/launch-checklist.md` (which is iOS-focused).

App identity (permanent):

- `applicationId` / package: **`com.navis.navis_mobile`**
- App label (home screen): **Navis** (`AndroidManifest.xml`)
- Version: driven by `pubspec.yaml` (`1.0.0+1` → versionName `1.0.0`, versionCode `1`)

## What the code already does

- **Release signing** (`android/app/build.gradle.kts`) reads
  `android/key.properties` when present; otherwise it falls back to debug
  signing so `flutter run --release` still works. A Play upload REQUIRES the
  keystore.
- **Google Services plugin** is applied only when `android/app/google-services.json`
  exists — the release build no longer fails when the file is absent. FCM push
  stays inactive until the file is added.
- **AAB build**: `make mobile-build-aab` (mirrors `mobile-build-apk`, same
  dart-defines; Play requires the `.aab`, not an APK).

## 1. Upload keystore (one time)

```bash
keytool -genkey -v -keystore ~/navis-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep the `.jks` and its passwords safe and OUT of git (already gitignored). If
you lose it you can recover via Play App Signing, but avoid the hassle.

Then copy `android/key.properties.example` → `android/key.properties` and fill
in the passwords, alias (`upload`), and the absolute `storeFile` path. This file
is gitignored.

## 2. google-services.json

Firebase console → project **navis-44c8b** → add an Android app with package
`com.navis.navis_mobile` → download `google-services.json` into
`apps/mobile/android/app/`. Gitignored. Without it, push notifications (FCM)
are inactive but the app builds and runs.

## 3. Build the App Bundle

Provide the same release env vars as iOS (see `Makefile` header) plus
`REVENUECAT_ANDROID_KEY` (the `goog_…` SDK key from RevenueCat):

```bash
make mobile-build-aab
# output: apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

## 4. RevenueCat (Android)

- Add an **Android app** to the RevenueCat project (same project as iOS):
  package `com.navis.navis_mobile`, Google Play Billing.
- Create the products matching Play (`navis_plus_monthly/yearly`,
  `navis_pro_monthly/yearly`) and map them to the SAME entitlements `plus` / `pro`.
- Google Play **service account** JSON so RevenueCat can validate purchases
  (Play Console → API access → grant the service account financial/view perms).
- Copy the Android SDK key (`goog_…`) → `REVENUECAT_ANDROID_KEY`.

## 5. Play Console — store listing & declarations

Reuse the iOS assets/text where possible (`docs/app-store-listing.md`,
screenshots): title "Navis", description ES/EN, category, contact.

- **Content rating (IARC)** questionnaire → same answers as ASC (UGC + social =
  yes via the Discover tab) → expect a teen rating.
- **Data safety form** — mirror the App Privacy nutrition labels: collected data
  (name, email, precise location, photos, user content, user/device id,
  purchases, diagnostics), no tracking, encrypted in transit, deletion available.
- **Target audience & content** — 13+.

### Sensitive-permission declarations (highest rejection risk)

The manifest requests these; each needs an in-Console declaration + a
prominent-disclosure/justification, and background location needs a demo video:

- `ACCESS_BACKGROUND_LOCATION` — **highest risk.** Justified by trip recording
  and the anchor-watch drift alarm running while the app is backgrounded. Provide
  the prominent-disclosure flow + a short screen-recording showing the feature.
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_LOCATION` — location foreground
  service for the same tracking/anchor features.
- `USE_FULL_SCREEN_INTENT` — anchor-drift alarm full-screen notification.
- `POST_NOTIFICATIONS`, location (fine/coarse), `WAKE_LOCK`, `VIBRATE` — standard.

## 6. Internal testing

Create an internal testing track, upload the AAB, add tester emails — the
Android analogue of TestFlight internal testing. No review needed for internal
track.

## Open blockers before a Play upload

1. Google Play Developer account verified (identity check, several days).
2. Upload keystore + `key.properties` created (§1).
3. `google-services.json` added (§2) — or accept no push on Android for v1.
4. RevenueCat Android app + `goog_` key + Google service account (§4).
