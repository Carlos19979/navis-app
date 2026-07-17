# Launch Checklist

Estado consolidado de lo que falta para publicar Navis en el App Store.
El detalle paso a paso vive en [deploy.md](deploy.md) y [payments-setup.md](payments-setup.md);
este documento es solo el índice de progreso. Actualizado: 2026-07-15.

## ✅ Hecho

- [x] Código completo: modelo Free/Pro + 6 features Pro, rediseño UI/UX, endurecimiento
      pre-launch en 5 fases, bookings/expense-splits, mantenimiento programado (PRs #4–#26).
- [x] Textos legales con identidad real (Carlos Pérez Martínez, Valencia), email de
      contacto `carloscode23@icloud.com` y precios 3,99 €/mes · 29,99 €/año (PR #27).
- [x] Build release verificado en iPhone (arranca standalone).
- [x] CI: lint + test Go y Flutter en cada PR; job de deploy preparado (gated `if: false`).

## ⬜ Pendiente — config externa (en orden de dependencia)

### 1. Apple Developer Program ← bloquea 2, 3 y 6
- [ ] Alta en developer.apple.com (99 €/año).

### 2. App Store Connect
- [ ] Firmar Paid Applications Agreement + datos fiscales/bancarios.
- [ ] Crear la app (bundle ID) y el subscription group `Navis Pro`.
- [ ] Productos: `navis_pro_monthly` (3,99 €/mes) y `navis_pro_yearly` (29,99 €/año).
      ⚠️ Si se añade prueba gratuita de 7 días, hay que divulgarla en Términos §4
      (`apps/api/internal/handler/legal_content.go`).
- [ ] API key de In-App Purchase (para RevenueCat) + al menos un Sandbox tester.
- [ ] Capability In-App Purchase en el target Runner de Xcode.
- [ ] URLs legales: `https://<api>/legal/privacy` y `/legal/terms`.

### 3. Firebase (proyecto `navis-44c8b`, ya existe)
- [ ] Descargar `GoogleService-Info.plist` → `apps/mobile/ios/Runner/`.
- [ ] Generar clave APNs en Apple Developer y subirla a Firebase (sin esto no hay push iOS).
- [ ] Descargar Service Account JSON (para la integración FCM de Novu, paso 7).

### 4. Supabase Cloud
- [ ] Proyecto en **región UE** (la Política de Privacidad §4 lo afirma).
- [ ] `supabase link` + `supabase db push` (00001–00032); verificar bucket `documents`
      privado, RLS de `sent_notifications`, índices de paginación.
- [ ] Auth: confirmaciones de email ON, redirect `navis://login-callback`,
      Sign in with Apple + Google, SMTP de Resend como sender.

### 5. Railway (Go API)
- [ ] Proyecto en **región UE**, servicio con root dir `apps/api`.
- [ ] Env vars (ver deploy.md §2): `APP_ENV=production`, `DATABASE_URL`, `SUPABASE_*`,
      `REVENUECAT_WEBHOOK_SECRET`, `CORS_ALLOWED_ORIGINS` (+ `NOVU_API_KEY`, `SENTRY_DSN`).
- [ ] Anotar la URL pública (la usan los pasos 2, 6 y los builds móviles).

### 6. RevenueCat
- [ ] Proyecto + app iOS (API key de App Store Connect + bundle ID).
- [ ] Importar productos; entitlement con identificador **exactamente `pro`**;
      offering marcado Current con paquetes Monthly + Annual.
- [ ] Webhook → `https://<railway>/api/v1/webhooks/revenuecat` con el mismo secret
      que `REVENUECAT_WEBHOOK_SECRET`.
- [ ] Copiar SDK key iOS (`appl_…`) para los builds (`REVENUECAT_IOS_KEY`).

### 7. Novu
- [ ] Cuenta + los 9 workflows (7 de `internal/service/notifier.go` + 2 crons): `document-expiry`, `maintenance-due`,
      `regatta-rsvp`, `regatta-scheduled`, `regatta-reminder`, `group-join-request`,
      `group-request-approved`, `event-live`, `expense-split` (Push FCM → Email Resend).
- [ ] Integraciones: FCM (Service Account JSON del paso 3) + Resend (API key).
- [ ] `NOVU_API_KEY` de producción → env de Railway.

### 8. Verificación end-to-end (deploy.md §4)
- [ ] `/readyz` ok · `/api/v1/boats` anónimo → 401 · `/legal/privacy` renderiza ·
      webhook rechaza secret malo.
- [ ] En iPhone: registro → email confirmación → login → barco + documento → travesía →
      compra sandbox (flip a Pro) → Ajustes → Eliminar cuenta.

### 9. Deploy automático (cuando 5 esté estable)
- [ ] Secret `RAILWAY_TOKEN` en GitHub + quitar `if: false` del job `deploy-api` en
      `.github/workflows/ci.yml`.

### 10. Opcional (máquina local)
- [ ] `sudo chown -R personal /opt/homebrew/share/flutter` (arregla el wrapper de Flutter).

## Diferidos de código (no bloquean el lanzamiento)

- Bundle de la fuente Inter (hoy vía google_fonts).
- Dashboard single-boat → overview.
- Remates Fase 4 del rediseño: CTA de ubicación denegada en meteo, jerarquía de botones
  en event detail, charts con GPS denegado.
- Sweep de `autoDispose` + adopción de sealed `Failure` (necesita device para QA).
- Flujos multi-usuario de barco compartido en la suite E2E.
