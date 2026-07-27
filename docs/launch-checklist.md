# Launch Checklist

Estado consolidado de lo que falta para publicar Navis en el App Store.
El detalle paso a paso vive en [deploy.md](deploy.md) y [payments-setup.md](payments-setup.md);
este documento es solo el índice de progreso. Actualizado: 2026-07-15.

## ✅ Hecho

- [x] Código completo: modelo Free/Pro + 6 features Pro, rediseño UI/UX, endurecimiento
      pre-launch en 5 fases, bookings/expense-splits, mantenimiento programado (PRs #4–#26).
- [x] Textos legales con identidad real (Carlos Pérez Martínez, Valencia), email de
      contacto `carloscode23@icloud.com`. Precios (3 tiers): Plus 4,99 €/mes · 39,99 €/año,
      Pro 8,99 €/mes · 69,99 €/año (PR #27 + tiers).
- [x] Build release verificado en iPhone (arranca standalone).
- [x] CI: lint + test Go y Flutter en cada PR; job de deploy preparado (gated `if: false`).

## ⬜ Pendiente — config externa (en orden de dependencia)

### 1. Apple Developer Program ← bloquea 2, 3 y 6
- [x] Alta en developer.apple.com (99 €/año). ✅ 2026-07-24

### 2. App Store Connect
- [x] Paid Applications Agreement: términos aceptados, entidad legal actualizada,
      banca (Revolut ES, EUR) enviada → "En proceso" (validación Apple ~24h),
      formularios fiscales W-8BEN + Certificate of Foreign Status → **Activos**.
      El acuerdo pasa a Activo cuando Apple valide el banco. ✅ 2026-07-24.
- [x] Crear la app con bundle ID **`com.navis.navisMobile`** (el que ya estaba en Xcode) y el
      subscription group `Navis Suscripciones`. ✅ 2026-07-24 (Apple ID `6794321904`).
- [x] Productos (4) creados: `navis_plus_monthly`, `navis_plus_yearly`,
      `navis_pro_monthly`, `navis_pro_yearly` (duraciones 1 mes/1 año). ✅ 2026-07-24.
- [x] Precios base € puestos (base España/EUR + autocálculo): 4,99/39,99/8,99/69,99 €.
      EE. UU. subido a la par (4,99/39,99/8,99/69,99 $). ✅ 2026-07-24.
- [x] Nombre + descripción localizados (ES + EN) en los 4 productos. ✅ 2026-07-24.
- [x] Captura de revisión subida en los 4 productos (paywall a 1170×2532, generado desde
      el golden a DPR 3×). ✅ 2026-07-24. Disponibilidad: todos los países (ok).
      Entitlements `plus` y `pro` se configuran en RevenueCat. **Los productos quedan
      completos**; solo falta enviarlos a revisión con el build (y el Paid Apps Agreement activo).
      ⚠️ Si se añade prueba gratuita de 7 días, hay que divulgarla en Términos §4
      (`apps/api/internal/handler/legal_content.go`).
- [ ] API key de In-App Purchase (para RevenueCat) + al menos un Sandbox tester.
- [ ] Capability In-App Purchase en el target Runner de Xcode.
- [x] URLs configuradas en ASC (dominio Railway `navis-app-production.up.railway.app`):
      Privacy Policy `/legal/privacy` (en Privacidad de la app), Support URL `/support`
      (en la versión 1.0), Terms `/legal/terms` (EULA estándar de Apple + enlace in-app).
      Los 3 endpoints responden 200 en producción. ✅ 2026-07-24.
- [x] Clasificación por edad completada → **13+**. ✅ 2026-07-24.
- [x] Privacidad de la app (nutrition labels) completada. ✅ 2026-07-24.
- [x] Estatus de comerciante (DSA): declarado comerciante + datos de contacto
      (Calle Juan Estellés 24B, Masarojos, Valencia 46112, +34 620377644,
      carloscode23@icloud.com) verificados por email y SMS + justificante de
      dirección subido. Estado en App Store Connect: **En revisión**. ✅ 2026-07-24.
- [x] Documentación de encriptación (export compliance): declarado en
      `ios/Runner/Info.plist` con `ITSAppUsesNonExemptEncryption=false`
      (solo encriptación estándar exenta: HTTPS/TLS). ✅ 2026-07-24.

### 3. Firebase (proyecto `navis-44c8b`, ya existe)
- [ ] Descargar `GoogleService-Info.plist` → `apps/mobile/ios/Runner/`.
- [ ] Generar clave APNs en Apple Developer y subirla a Firebase (sin esto no hay push iOS).
- [ ] Descargar Service Account JSON (para la integración FCM de Novu, paso 7).

### 4. Supabase Cloud
- [ ] Proyecto en **región UE** (la Política de Privacidad §4 lo afirma).
- [ ] `supabase link` + `supabase db push` (00001–00038); verificar bucket `documents`
      privado, RLS de `sent_notifications`, índices de paginación.
- [ ] Auth: confirmaciones de email ON, redirect `navis://login-callback`,
      Sign in with Apple + Google, SMTP de Resend como sender.
  - [x] Redirect `navis://login-callback` — verificado en el dashboard de
        `navis-prod` (2026-07-27): está en Redirect URLs, es la única.
  - [x] Site URL — corregido (2026-07-27). Estaba en `http://localhost:3000`,
        que es el destino de reserva de cualquier redirect NO listado y además
        Supabase lo inyecta en las plantillas de correo como `{{ .SiteURL }}`.
        Ahora apunta a `https://navis-app-production.up.railway.app/support`:
        se eligió `/support` y no la raíz porque la raíz de la API devuelve 404,
        y esta página ya está registrada como Support URL en App Store Connect,
        así que quien caiga ahí encuentra algo útil.

### 5. Railway (Go API)
- [ ] Proyecto en **región UE**, servicio con root dir `apps/api`.
- [ ] Env vars (ver deploy.md §2): `APP_ENV=production`, `DATABASE_URL`, `SUPABASE_*`,
      `REVENUECAT_WEBHOOK_SECRET`, `CORS_ALLOWED_ORIGINS` (+ `NOVU_API_KEY`, `SENTRY_DSN`).
- [ ] Anotar la URL pública (la usan los pasos 2, 6 y los builds móviles).

### 6. RevenueCat
- [ ] Proyecto + app iOS (API key de App Store Connect + bundle ID).
- [ ] Importar los 4 productos; crear **dos** entitlements con identificadores
      **exactamente `plus` y `pro`** (`navis_plus_*` → `plus`, `navis_pro_*` → `pro`);
      offering marcado Current con los 4 packages (Monthly + Annual de cada tier).
      El paywall separa tiers por el identificador del producto (`*_plus_*`/`*_pro_*`).
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
