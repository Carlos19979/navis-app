# Navis — Endurecimiento pre-lanzamiento: seguridad + App Store + deploy + calidad de código

## Context

Cinco auditorías (backend, móvil, infra, calidad-Go, calidad-Flutter) sobre la app completa
concluyen: **de features vamos sobrados para validar, pero hoy no se puede lanzar**. Hay
bypass de auth por defaults vacíos, PII en un bucket público, incumplimientos que garantizan
rechazo de la App Store (sin borrado de cuenta, crash de cámara, sin legal, paywall en
español hardcodeado), un camino de deploy inexistente, y deuda de calidad concentrada
(duplicación masiva de boilerplate, lógica de negocio en widgets, cero tests del gating de
planes). Este plan arregla los ~11 bloqueantes de código + los importantes de primer nivel +
la pasada de duplicidad/buenas-prácticas/optimización en Go y Flutter que pidió el usuario
("si tienes que rehacer cosas o cambiar existentes, hazlo").

**Fuera de alcance** (requiere cuentas del usuario): Apple Developer Program, App Store
Connect, RevenueCat dashboard, Supabase Cloud dashboard (documentado en runbook), Novu
workflows. **Diferido conscientemente**: leader-lock de crons (una sola instancia al
lanzar, documentado), adopción de Riverpod codegen y `Repository[T]` genérico (se actualiza
CLAUDE.md para reflejar la realidad hand-written en su lugar), onboarding completo (solo se
mejora el empty-state con la propuesta de valor).

**Metodología**: cada fase en su propia rama `fix/`- o `refactor/`-, siguiendo el workflow
del repo (local checks → PR → CI verde). Go: `go test -race ./...` + build + vet. Flutter:
`flutter analyze --fatal-infos` + `flutter test` (toolchain ya desbloqueado o lo desbloquea
el usuario con `sudo chown -R $(whoami) /opt/homebrew/share/flutter`).

---

## FASE 1 — Backend: seguridad y fiabilidad (bloqueantes 1,2,4,5,6 + importantes)

### 1.1 Fail-fast de configuración (bloqueantes 1, 2 y silencio de Novu)
- `internal/config/config.go`: añadir `Validate() error` — si `AppEnv == "production"`:
  `SUPABASE_JWT_SECRET`, `REVENUECAT_WEBHOOK_SECRET` y `DATABASE_URL` con ssl obligatorios
  (no vacíos/no defaults); `NOVU_API_KEY` vacío → *warning* ruidoso al log (no aborta:
  email puede llegar después). `LOG_LEVEL` default → `info` si production.
- `cmd/server/main.go`: llamar `cfg.Validate()` y abortar el boot con mensaje claro.
- `internal/middleware/auth.go`: restringir algoritmos aceptados (`jwt.WithValidMethods`
  HS256/ES256 según JWKS) y rechazar secret vacío aunque llegue hasta ahí.
- Quitar del webhook el "secret vacío = permitir" (`webhook_handler.go:90-97`): vacío → 401
  siempre; el modo dev se cubre poniendo el secreto en `.env` local.

### 1.2 Sentry real (bloqueante 6)
- `internal/middleware/recovery.go`: `sentry.CurrentHub().Recover(err)` + flush corto en panics.
- `internal/handler/response.go` (`MapDomainError` rama 500) y errores 5xx del logging
  middleware: `sentry.CaptureException`.
- `main.go:52`: `Environment: cfg.AppEnv` (hoy tagea con el log level — bug).

### 1.3 Borrado de cuenta REAL (bloqueante 5, backend)
- `internal/handler/user_handler.go` → mover lógica a un `UserService` nuevo (regla
  CLAUDE.md: handlers sin lógica). El servicio:
  1. Borra ficheros de Storage (fotos barco + escaneos documentos) vía API admin de
     Supabase Storage (nuevo adapter `internal/adapter/supabase/admin.go`, usa
     `SUPABASE_SERVICE_ROLE_KEY` — nueva env var, incluida en `Validate()`).
  2. Borra filas app en **una transacción** (nuevo `TxManager` en `internal/adapter/postgres`,
     patrón CLAUDE.md: service abre tx, repos aceptan tx) — incluye lo que hoy se omite:
     maintenance, expenses, memberships, interests, participants, checklists, profile,
     sent_notifications, notification_logs; grupos que posee → borrar o transferir (decisión:
     borrar, con aviso previo en la UI móvil).
  3. Borra el usuario de **`auth.users`** vía admin API (GoTrue `DELETE /admin/users/{id}`).
- Export GDPR completo: añadir los tipos omitidos + paginar sin cap silencioso.

### 1.4 RLS y bucket privado (bloqueantes 3 y 4)
- Migración `00028_security_hardening.sql`:
  - `ALTER TABLE sent_notifications ENABLE ROW LEVEL SECURITY;` + policy SELECT propia.
  - `UPDATE storage.buckets SET public=false WHERE id='documents';` (fotos de barco
    pueden quedarse públicas — decisión de producto: no son PII sensible).
- Backend: endpoint o campo que devuelva **signed URLs** para documentos. Aproximación:
  el móvil ya habla con Supabase Storage directamente para subir; para leer, cambiar
  `getPublicUrl` → `createSignedUrl` (TTL 1h) en `core/network/storage_service.dart`.
  (Cambio móvil en Fase 4; la migración va aquí.)

### 1.5 Endurecimiento HTTP (importantes)
- `internal/middleware/ratelimit.go`: clave = IP real (parse `X-Forwarded-For` primer hop
  confiable, strip puerto de `RemoteAddr` como fallback); límite extra estricto en
  `/api/v1/webhooks/*` y rutas de auth-adyacentes.
- `http.MaxBytesReader` (1 MiB default, configurable) como middleware global.
- `/readyz` con ping real a la DB (`pool.Ping(ctx)`).
- CSP: excluir `/public/trips/*` del CSP global `default-src 'none'` y darle un CSP propio
  que permita unpkg + inline (hoy el mapa compartido está **roto** en browsers reales).
  Añadir de paso meta OG/Twitter + `<meta description>` a la página de share (es superficie
  de crecimiento).
- `internal/handler/device_handler.go` Delete: scope por `user_id` (IDOR).
- `internal/adapter/novu/client.go`: `http.Client{Timeout: 10s}`.
- `internal/cron/regatta_notifier.go`: registrar dedup **después** del envío OK (hoy marca
  enviado aunque falle — el expiry cron ya lo hace bien).

### 1.6 Datos (importantes)
- Migración `00029_indexes.sql`: `trips(user_id, created_at DESC, id)`,
  `documents(boat_id, created_at DESC, id)`, `documents(user_id)`,
  `boats(user_id, created_at DESC, id)`.
- `GroupService.Create` en transacción (grupo + owner-member) usando el `TxManager` de 1.3.

**Tests fase 1**: `internal/middleware/auth_test.go` (¡hoy 0 tests en la capa más crítica!):
token válido, firmado con secret vacío→401, alg confusion→401, expirado→401. Tests de
`config.Validate()`. Test del user service de borrado (mocks). Webhook secret vacío→401.

---

## FASE 2 — Backend: calidad (duplicidad, prácticas, optimización)

### 2.1 Dedup mecánico (mayor ratio valor/esfuerzo)
- Enrutar los ~56 bloques userID+401 por el helper **ya existente** `requireUserID`
  (`regatta_handler.go:27`) — moverlo a `handler/helpers.go`; borra ~130 LOC.
- Nuevo `decodeAndValidate[T any](w, r) (T, bool)` en `handler/helpers.go` — colapsa los
  ~23 bloques decode + ~20 validate.
- `metaFromCursor(next string) *Meta` — 9 copias fuera.
- Fusionar `generateInviteCode`/`generateBoatShareCode` → `randomCode(n)` (alfabeto idéntico)
  en un helper compartido de `service`.
- `pagination.ClampLimit(limit)` en `pkg/pagination` y reconciliar el max 50-vs-100
  (decisión: max 50, que es lo que usan los services). 11 call sites.
- `boat_repo.go` y `group_repo.go`: constante `xColumns` como los otros 7 repos (boat repite
  su lista de columnas PostGIS 6×).

### 2.2 Optimización: cursor compuesto (mata 1 query por página en TODOS los listados)
- `pkg/pagination`: cursor = base64 de `created_at|id`; `EncodeCursor`/`DecodeCursor` nuevos
  con compat hacia atrás (cursor legacy → tratar como inválido → primera página, mismo
  comportamiento que hoy con cursor corrupto).
- Reescribir los 8 métodos `List` para usar el cursor compuesto: elimina el
  `SELECT created_at WHERE id=$1` extra, la rama duplicada del SELECT y la recursión de
  cursor inválido en boat/document/event/group/trip repos.

### 2.3 Arquitectura según CLAUDE.md
- **Interfaces de servicio**: definir `type BoatService interface {...}` (etc.) consumidas
  por los handlers — mecánico, por handler; desbloquea tests unitarios de handlers.
- `Notifier.Send` fuera del request path: worker con canal buffered + goroutine supervisada
  (arrancada en main, parada en shutdown) — el POST a Novu deja de bloquear respuestas.
- CLAUDE.md: eliminar la prescripción del genérico `Repository[T]` (0 usos, los repos SQL
  a mano no encajan) y corregir la línea falsa "full deploy on main push".
- Limpiar los 3 C-style loops (`trip_handler.go:301`, `trip_service.go:177`, openmeteo).

### 2.4 Tests de calidad
- `internal/testutil/` compartido: fakes de `NotificationProvider` (hoy duplicado en 2
  paquetes) y `mockProfileRepo`.
- **Cubrir el gating de planes (hoy 0 tests de la feature de pago)**: BoatService.Create
  con límite free/pro (402), GroupService.Create free→PLAN_FORBIDDEN / pro→OK.

---

## FASE 3 — Móvil: cumplimiento App Store (bloqueantes 7-11)

### 3.1 Borrado de cuenta in-app (bloqueante 7; usa 1.3)
- Settings → sección Account: "Eliminar cuenta" con confirmación doble (escribe "ELIMINAR" /
  aviso de que borra barcos, documentos y grupos que posee). Llama `DELETE /api/v1/user`,
  hace signOut y limpia estado local.

### 3.2 Info.plist + ATS (bloqueantes 8 y 11)
- Añadir `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription` (ES/EN vía
  InfoPlist.strings) — commitear al Info.plist del repo.
- Sustituir `NSAllowsArbitraryLoads=true` por excepción scoped al host de dev
  (`NSExceptionDomains` para `.local`) o condicionarlo a builds debug (xcconfig).

### 3.3 Legal (bloqueante 9)
- Redactar **borradores** de Política de Privacidad y Términos (ES/EN) — ⚠️ el usuario debe
  revisarlos antes de publicar (responsabilidad legal, GDPR: Supabase/Railway/RevenueCat/
  Sentry como processors, datos de ubicación).
- Servirlos como HTML desde la API: `GET /legal/privacy` y `/legal/terms` (mismo patrón que
  la página pública de trips) → da la URL que App Store Connect exige.
- Móvil: pantalla `LegalScreen` (webview simple o texto nativo) enlazada desde: los items
  muertos de Profile ("Ayuda y soporte" → mailto/link; "Acerca de" → versión + legal), y
  **el paywall** (links Privacy/Terms + texto de renovación automática obligatorio 3.1.2).

### 3.4 i18n completo (bloqueante 10)
- Mover los ~64 strings hardcodeados a `app_es.arb`/`app_en.arb`. Prioridad: paywall entero,
  diálogos de auth/join, trip_recording, groups/regatta/boat_detail, checklist. Criterio de
  hecho: `grep` de literales con acentos fuera de `l10n/` → 0 en pantallas.

### 3.5 Flujo de registro con verificación de email (importante, user-facing)
- `auth_provider.dart:81`: si `signUp` devuelve user sin sesión → estado nuevo
  `pendingEmailConfirmation` → pantalla "revisa tu correo" con reenviar. Router: no rebotar
  a login en silencio.
- Endurecer notificaciones: envolver `getToken()`/`requestPermission()` en try/catch
  (`notification_service.dart:31`, `login_screen.dart:138`).

---

## FASE 4 — Móvil: robustez GPS + calidad (duplicidad, prácticas, optimización)

### 4.1 Grabación de rutas robusta (el refactor gordo — 3 pájaros de un tiro)
- Extraer TODA la lógica de `trip_recording_screen.dart` (813 líneas: GPS stream, timers,
  stats, buffer de subida) a un **`TripRecordingNotifier`** en
  `features/logbook/presentation/providers/`.
- **Persistencia**: tabla sqlite `track_points` + `recording_session`; cada fix se escribe a
  disco al llegar. `addTrackPoints` y `completeTrip` pasan por la `mutation_queue` existente
  (hoy la esquivan). Al abrir la app con una sesión activa → ofrecer reanudar/cerrar viaje.
  Resultado: matar la app en alta mar ya no pierde la ruta.
- **Rendimiento**: reloj transcurrido en widget propio (deja de reconstruir el mapa entero
  cada segundo); polyline memoizada (solo recalcula al crecer `_trackPoints`).
- Pedir permiso "Always" en iOS cuando el usuario activa grabación (o copy claro de que en
  iOS la grabación en segundo plano necesita ese permiso).
- Test del notifier (la pieza más arriesgada de la app, hoy 0 tests).

### 4.2 Signed URLs para documentos (pareja de 1.4)
- `storage_service.dart`: `getPublicUrl` → `createSignedUrl` para bucket `documents`;
  cachear URL firmada mientras no expire.

### 4.3 Dedup de UI
- `shared/widgets/navis_dialog.dart`: `NavisConfirmDialog.show(...)` (destructive opcional)
  y `NavisInputDialog.show(...)` → sustituir ~15 diálogos copiados.
- `NavisGradientFab` → sustituye el contenedor-FAB byte-idéntico de 5 pantallas.
- `NavisTextField` con la decoración/validators comunes → 36 `InputDecoration` inline.
- `NavisAsyncList<T>` (error/retry + empty + RefreshIndicator + ListView.builder) → 4+
  pantallas de listado; de paso arregla los `ListView(children:)` sobre datos de servidor.
- Formateo de fechas/duraciones: todo por `NavisDateUtils` (añadir `formatHms`); borrar los
  ~8 formateadores inline.

### 4.4 Prácticas + optimización
- **`Failure` mapping real**: los repos mapean `DioException`→`Failure` (hoy la jerarquía
  sealed tiene 0 usos); helper compartido para el patrón offline-fallback + `_canEnqueue`
  (duplicado en 3 repos). Pantallas muestran copy amable, no `error.toString()`
  (`boat_dashboard_screen.dart:144`).
- **`autoDispose`** en todos los providers family/detalle (hoy 0 → retención de sesión
  completa); `keepAlive` solo en `boatsProvider` y sesión.
- `.select()` en los watchers pesados (dashboard, detalles).
- `memCacheWidth` en `CachedNetworkImage` + sustituir los 2 `Image.network` crudos.
- Track JSON parse con `compute()` en `trip_repository.getTrackPoints`.
- `boat_permissions.dart`: sacar `fromJson/toJson` de la entity a un model (única entity
  impura).
- Mejorar empty-state del dashboard con la propuesta de valor (documentos + recordatorios)
  — mini-onboarding barato.
- CLAUDE.md móvil: reflejar la decisión real (providers hand-written, sin codegen).
- Guard de los 2 `debugPrint` sueltos; split de pantallas >700 líneas donde el refactor 4.1/
  4.3 ya obliga a tocarlas (no split gratuito del resto).

### 4.5 Tests móvil
- Backfill mínimo dirigido: `TripRecordingNotifier`, paywall/billing (gating), repos con
  `Failure` mapping, `NavisConfirmDialog`. (Las 7 features con 0 tests: se abre issue, no
  bloquea el lanzamiento.)

---

## FASE 5 — Deploy real (bloqueantes 12-13)

- **Makefile**: `mobile-build-ios`/`-apk` exigen env vars (`API_URL`, `SUPABASE_URL`,
  `SUPABASE_ANON_KEY`, `REVENUECAT_IOS_KEY`, `SENTRY_DSN`) y las inyectan como
  `--dart-define` + `ENVIRONMENT=production`; fallo ruidoso si faltan. Sacar el DSN de
  Sentry hardcodeado del Makefile a env var.
- `env.dart`: en `ENVIRONMENT=production`, assert en arranque de que las URLs no son los
  defaults de dev (cinturón y tirantes).
- **Railway**: `railway.toml` (build Dockerfile, healthcheck `/readyz` — real tras 1.5,
  restart policy). Documentar env vars requeridas.
- **Runbook** `docs/deploy.md`: paso a paso Supabase Cloud (`supabase link` + `db push`,
  SMTP/Resend, redirect URLs, email confirmations ON, service role key), Railway, build
  móvil, y verificación post-deploy (healthz, login, webhook smoke-test de
  `payments-setup.md`).
- CI: job de deploy a Railway en push a main **documentado pero desactivado** hasta que
  exista el proyecto Railway (secret `RAILWAY_TOKEN`); arreglar el claim falso de CLAUDE.md.
- Alinear versiones Go (Dockerfile.dev 1.25 → 1.26; README).

---

## Verificación end-to-end (por fase y global)

- **Go**: `go build ./... && go vet ./... && go test -race ./...` verdes en cada fase.
  E2E local (stack colima+supabase, como el E2E de RevenueCat ya hecho): boot SIN
  `SUPABASE_JWT_SECRET` con `APP_ENV=production` → aborta; token forjado HS256-empty → 401;
  webhook sin secreto → 401; borrado de cuenta → usuario no puede reloguear, storage vacío,
  filas app 0; `/readyz` falla con DB parada; página share renderiza mapa con CSP nuevo.
- **Migraciones**: `supabase db reset` limpio; `SELECT` a `sent_notifications` con anon key
  → denegado; `getPublicUrl` de documents → 400/404, signed URL → 200.
- **Flutter**: `dart format --set-exit-if-changed` + `flutter analyze --fatal-infos` +
  `flutter test` verdes. En dispositivo: flujo cámara en documento (no crash), borrado de
  cuenta end-to-end, paywall en inglés (device en EN) con links legales, grabación de ruta →
  matar app → reabrir → reanudar con puntos intactos.
- **Grep gates**: 0 strings con acentos fuera de l10n; 0 `getPublicUrl` para documents;
  0 `AlertDialog(` fuera de navis_dialog; 0 usos directos de `UserIDFromContext` en handlers
  (salvo helper).
- **Cierre**: actualizar `docs/implemented-features.md` + memoria del proyecto.

## Orden de ejecución y ramas

1. `fix/backend-security` (Fase 1) — la más urgente, independiente.
2. `fix/store-compliance` (Fase 3) — paralelo posible a 2.
3. `refactor/backend-quality` (Fase 2) — tras 1 para no pelear rebases.
4. `refactor/mobile-quality-gps` (Fase 4) — tras 3.
5. `feat/deploy-pipeline` (Fase 5) — al final, cuando 1-4 estén mergeadas.
