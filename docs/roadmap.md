# Roadmap de Implementación — Navis (Actualizado 2026-04-28)

Estado actual: Fases 0-11 implementadas. Fase 12 en progreso. Este roadmap cubre todo lo que queda.

---

## FASE V: Verificación — Compilación y calidad del código existente
**Objetivo:** Asegurar que todo el código existente compila, pasa linters y no tiene errores antes de construir encima.

**Estado: ✅ HECHO** (con correcciones aplicadas 2026-04-27)

### Correcciones aplicadas
- Supabase CLI config.toml: eliminado campo `[project]` obsoleto
- Migration 00003: cambiado `GENERATED STORED` a trigger (CURRENT_DATE no es inmutable)
- seed.sql: corregidos UUIDs inválidos, creado usuario test en auth.users con todos los campos requeridos
- Go API: añadido `.air.toml` para que Air encuentre `cmd/server/main.go`
- Go API: añadido soporte JWKS (ES256) al middleware de auth (Supabase CLI v2.95+ usa ES256)
- Flutter: corregido API response envelope parsing en todos los repositories (`data['items']` → `envelope['data']`)
- Flutter: corregido `boat_model.dart` JSON key (`length_meters` → `length_m`)
- Flutter: corregido error interceptor para manejar respuestas texto plano

---

## FASE 12: Integración y Pulido
**Objetivo:** Conectar todo E2E, pulir UX, preparar para beta.

**Estado: EN PROGRESO**

### 12.1 — Auth flow E2E
- [x] Login con email/password funciona contra Supabase local
- [x] Registro de nuevo usuario (sign-up flow)
- [x] Password reset flow (envío de email + dialog en login)
- [x] Session persistence (auto-refresh JWT via Supabase Flutter)
- [x] Token refresh interceptor en Dio (catch 401, refresh Supabase session, retry request original)
- [x] Retry interceptor: auto-retry en 5xx y errores de red (max 2 retries, exponential backoff)
- [x] Profile screen: mostrar email, nombre, sign-out
- [x] Protección de rutas: GoRouter redirect a login si no hay sesión
- [x] Clear navigation stack on logout (`context.go('/login')`)
- [x] Prevenir loops de re-autenticación (si refresh falla → logout)
- [x] Router reactivo a auth state (refreshListenable)

### 12.2 — Push notifications E2E
- [ ] Verificar que FCM funciona en dispositivo real (no emulador)
- [x] Flutter: solicitar permisos de notificación
- [x] Flutter: registrar device token en API al login
- [x] Flutter: eliminar device token en API al logout
- [ ] Go cron: verificar que detecta documentos por caducar
- [ ] Go cron: verificar que envía notificación via Novu → FCM
- [x] Deep link desde notificación → pantalla del documento (parsear route params de notification data)
- [x] Manejar notificación con app en foreground vs background vs terminated
- [ ] Deduplicación de notificaciones (notification_logs): verificar que no repite envío mismo día

### 12.3 — Boat Management E2E
- [x] Crear barco con todos los campos (nombre, registro, tipo, eslora, puerto base)
- [x] Map picker para seleccionar home port con coordenadas
- [x] Upload foto del barco (Supabase Storage)
- [x] Comprimir imagen antes de subir (max 1200px ancho, JPEG quality 85%)
- [x] Mostrar foto con CachedNetworkImage (placeholder + error widget)
- [x] Editar barco
- [x] Eliminar barco con diálogo de confirmación
- [x] `document_summary` en la lista de barcos (total, expired, critical, warning, ok)
- [x] Boat card muestra estado de documentos con badges de color

### 12.4 — Document Management E2E
- [x] Crear documento con todos los campos
- [x] Tipos de documento ampliados:
  - Registration (Matrícula)
  - Insurance (Seguro RC / Seguro Todo Riesgo)
  - Inspection (ITB)
  - License (PER / PNB / Capitán de Yate)
  - Safety Certificate (Certificado de Navegabilidad)
  - Radio License (Licencia de Estación de Radio)
  - Pollution Certificate (Certificado MARPOL)
  - Medical Certificate (Reconocimiento Médico)
  - Life Raft (Balsa Salvavidas — revisión periódica)
  - Fire Extinguisher (Extintores — revisión periódica)
  - Flares (Bengalas/Pirotecnia — caducidad)
  - First Aid Kit (Botiquín — caducidad medicamentos)
  - Fishing Permit (Permiso de Pesca)
  - Other (Personalizado)
- [x] Upload foto/scan del documento (Supabase Storage, bucket: `documents/{docId}/`)
- [x] Comprimir imagen antes de subir (StorageService._compressImage)
- [x] Computed status badges: OK / Warning / Critical / Expired
- [x] Lista de documentos ordenada por urgencia
- [x] Editar documento
- [x] Renovar documento (fecha renovación, coste, proveedor)
- [x] Eliminar documento con confirmación
- [x] Configurar días de alerta por documento (`alert_days`)

### 12.5 — Logbook E2E
- [x] Crear viaje: seleccionar barco, puerto salida, tripulación
- [x] Añadir campos faltantes a Trip entity/model/DB:
  - `crew` (texto, lista de tripulantes)
  - `engine_hours` (decimal, horas de motor)
  - `fuel_used_liters` (decimal, combustible consumido)
- [x] Migration DB ya existente con columnas en `trips`
- [x] Go domain entity, DTO, handler, repo ya tenían los campos
- [x] Actualizar Flutter Trip entity, model, provider para nuevos campos
- [x] Finalizar viaje: puerto llegada, horas motor, combustible, notas (completion dialog)
- [x] Upload track points al API (POST /trips/{id}/tracks)
- [x] Lista de viajes por barco (fecha, puertos, distancia)
- [x] Vista detalle de viaje con todos los datos (incluir crew, motor, fuel)
- [x] Editar viaje
- [x] Eliminar viaje con confirmación

### 12.6 — Weather E2E
- [x] Pronóstico para cualquier ubicación
- [x] Condiciones actuales: viento, olas, temperatura, visibilidad
- [x] Forecast 3 días con datos náuticos (altura ola, rachas viento)
- [x] Weather widget en home screen para puerto base del barco
- [x] Weather check antes de iniciar un viaje

### 12.7 — Events E2E
- [x] Listar eventos próximos (regatas, exhibiciones, cursos)
- [x] Filtrar por tipo, ubicación, fecha
- [x] Debounce search inputs (300ms) con Timer antes de enviar request
- [ ] CancelToken en Dio para cancelar búsqueda anterior al escribir nueva
- [x] Featured events destacados
- [x] Marcar interés en evento
- [x] Vista detalle con enlace registro

### 12.8 — Charts E2E
- [x] Mapa interactivo con OpenSeaMap tiles
- [x] Mostrar puertos base de todos los barcos (custom markers)
- [x] Ver tracks de viajes sobre el mapa (polyline layer)
- [ ] Información de puertos cercanos (tap handler con popup)
- [ ] PostGIS queries: ST_DWithin para puertos cercanos a ubicación actual

### 12.9 — UI Polish
- [x] RepaintBoundary en todos los FlutterMap widgets
- [x] Skeleton shimmer loaders en todas las pantallas con carga async
- [x] Empty states con ilustración + texto + CTA en cada lista vacía
- [x] Error states con mensaje + botón retry en cada pantalla
- [x] Snackbars para confirmación de acciones (creado, actualizado, eliminado)
- [x] Haptic feedback en acciones importantes (delete, start/stop recording)
- [x] Scroll infinito suave en listas paginadas con loading indicator al final
- [x] Micro-animaciones: FAB scale on tap, card press effect
- [x] Status bar adaptada al tema (iconos claros sobre fondo oscuro)
- [x] i18n completo (faltan strings hardcodeados en varias pantallas)
- [x] Disable submit button mientras async op en progreso (NavisButton.isLoading)
- [x] Preservar form state al navegar (AutomaticKeepAliveClientMixin o provider)

### 12.10 — Offline básico
- [x] Detectar estado de conectividad (connectivity_plus)
- [x] Mostrar banner "Sin conexión" cuando offline
- [x] Cachear última respuesta exitosa en memoria para boats y documents
- [x] Permitir ver datos cacheados sin conexión
- [x] Encolar mutaciones locales y reintentar al reconectar

### 12.11 — Accessibility pass
- [x] semanticLabel en todas las imágenes
- [x] Tooltip en todos los iconos interactivos
- [x] Touch targets mínimos 48x48 dp
- [x] Contraste WCAG AA en tema oscuro
- [ ] Probar con TalkBack (Android) flujo principal
- [x] Soportar text scaling dinámico (no hardcodear font sizes sin MediaQuery)

### 12.12 — Performance pass
- [x] RepaintBoundary en mapas
- [x] `const` constructors en todos los widgets estáticos
- [x] `ListView.builder` en lugar de `Column(children: list.map(...))`
- [x] Providers usan `autoDispose` por defecto
- [x] Imágenes se comprimen antes de subir
- [ ] Profile con Flutter DevTools: no jank en scroll de listas
- [ ] Usar `select` en providers para escuchar campos específicos, no objetos enteros
- [x] Dispose de controllers, subscriptions, listeners en todos los StatefulWidgets

### 12.13 — Error reporting
- [x] Sentry integrado en Flutter (sentry_flutter)
- [x] Sentry integrado en Go API (sentry-go middleware)
- [x] DSN configurado via env vars
- [x] Capturar unhandled exceptions en ambos lados
- [x] Filtrar PII de los reports (no enviar tokens, emails, datos personales)
- [x] Tags en errores: user_id, boat_id, app_version, os_version
- [x] Release version tracking en Sentry

### 12.14 — Go API hardening
- [x] Security headers middleware: HSTS, X-Content-Type-Options, X-Frame-Options
- [x] CORS middleware: whitelist de orígenes permitidos
- [x] Rate limiting middleware: per IP (100 req/min) y per user (1000 req/hour)
- [x] Rate limiting agresivo en auth endpoints (delegado a Supabase Auth)
- [x] Graceful shutdown: signal.NotifyContext + server.Shutdown con timeout
- [x] Request ID middleware: UUID por request, propagar en context, incluir en logs
- [x] Structured logging con slog: request_id, user_id, method, path, status, duration
- [x] Log levels: ERROR para 5xx, WARN para 4xx, INFO para operaciones exitosas
- [x] Input sanitization: trim strings, validar max lengths en DTOs
- [x] Validar content types en uploads (solo imágenes para fotos/documentos)
- [x] Per-handler timeouts con http.TimeoutHandler para operaciones largas
- [x] Verificar que NO se loguean tokens, passwords, ni datos personales

### 12.15 — Supabase Storage setup
- [x] Crear bucket `boats` para fotos de barcos (path: `{userId}/{boatId}/photo.jpg`)
- [x] Crear bucket `documents` para scans (path: `{userId}/{docId}/scan.{ext}`)
- [x] RLS policies en Storage: solo acceso a archivos del propio usuario
- [x] StorageService con compresión de imágenes (max 1200px, JPEG 85%)
- [x] Upload progress indicator durante subida de archivos
- [x] Cache invalidation strategy para imágenes actualizadas

### 12.16 — Preparar para beta
- [ ] App icon y splash screen con branding Navis
- [ ] Configurar Firebase project completo (iOS + Android)
- [ ] Configurar signing (iOS certificates, Android keystore)
- [ ] Build de release: `flutter build apk --release` y `flutter build ipa`
- [ ] Subir a TestFlight (iOS) y Google Play Internal Testing (Android)

### Criterios de completado Fase 12
- [x] Auth flow completo (login, registro, reset, profile, logout)
- [ ] Push notifications llegan al dispositivo real
- [x] Todos los CRUD funcionan E2E sin crasheos
- [x] Fotos de barcos y documentos se suben y muestran
- [x] UI pulida: loaders, empty states, error states, pull-to-refresh
- [x] Banner offline funciona
- [x] Accessibility pass completado
- [ ] Performance: sin jank en scroll
- [x] Sentry reporta errores correctamente
- [x] Go API tiene security headers, rate limiting, graceful shutdown
- [ ] App subida a TestFlight / Google Play Internal Testing

---

## FASE 13: GPS Trip Recording
**Objetivo:** Tracking GPS en vivo durante viajes con grabación en background.

**Dependencias:** Fase 12 completada.

### Tareas

#### 13.1 — Background location service
- [ ] Configurar geolocator para captura en background (battery-optimized)
- [ ] Android: foreground service con notificación persistente ("Navis está grabando tu viaje")
- [ ] iOS: background modes (location, processing) en Info.plist
- [ ] Captura cada 10 segundos: lat, lon, speed, heading
- [ ] Distance filter: solo registrar punto si se movió >10m
- [ ] Manejar permisos de ubicación (foreground + background + always)
- [ ] Manejar app suspend/resume: reanudar tracking al volver

#### 13.2 — Trip recording UI
- [ ] Botón Start/Stop trip en pantalla de barco
- [ ] Pantalla de trip activo: mapa en vivo con track, velocidad, distancia recorrida
- [ ] Auto-calcular distancia desde GPS track
- [ ] Indicador de estado GPS (precisión, última posición)
- [ ] Manejar lifecycle: seguir grabando si app va a background

#### 13.3 — Trip data persistence
- [ ] Batch upload de puntos GPS al API cada 60 segundos (usar pgx.Batch)
- [ ] Almacenar track como PostGIS geometry(linestring, 4326) o array de puntos
- [ ] Buffer local de puntos en caso de pérdida de conexión
- [ ] Al finalizar viaje: calcular distancia total, velocidades, duración en servidor

#### 13.4 — Trip visualization
- [ ] Track del viaje renderizado sobre mapa con polyline
- [ ] Colores de velocidad en el track (lento=azul, rápido=verde)
- [ ] Downsampling de polyline para display (Douglas-Peucker o similar)
- [ ] Estadísticas post-viaje: velocidad max/media, distancia, duración

### Criterios de completado Fase 13
- [ ] Se puede grabar un viaje completo en background sin pérdida de puntos
- [ ] El track se visualiza correctamente en el mapa
- [ ] La distancia calculada por GPS coincide con la real (±10%)
- [ ] La batería no se drena excesivamente (>4h de grabación continua)
- [ ] Batch upload funciona con pgx.Batch (no loops individuales)

---

## FASE 14: Offline Completo
**Objetivo:** La app funciona sin conexión con sincronización automática.

**Dependencias:** Fase 13 completada.

### Tareas

#### 14.1 — Local database
- [ ] Implementar SQLite local con drift para boats, documents, trips
- [ ] Schema local mirrors API schema (mismas tablas, tipos)
- [ ] Sincronizar datos del API a local al iniciar sesión
- [ ] Servir datos desde local cuando offline
- [ ] Detectar cambios remotos y actualizar local (last_modified comparison)

#### 14.2 — Mutation queue
- [ ] Diseñar estructura de cola: tabla `pending_mutations` (entity, operation, payload, created_at)
- [ ] Encolar operaciones CRUD cuando offline
- [ ] Replay mutations al reconectar (orden FIFO estricto)
- [ ] Resolver conflictos: server wins con notificación al usuario ("Tu cambio fue sobrescrito")
- [ ] Retry con exponential backoff si replay falla
- [ ] Mostrar indicador de sync pendiente (badge con count)
- [ ] Manejar app resume: check pending mutations y sincronizar

#### 14.3 — Offline assets
- [ ] Fotos de documentos disponibles offline tras primera visualización (cache en app dir)
- [ ] Cache de tiles de mapa para zona del puerto base
- [ ] Offline nautical charts: descarga regional con flutter_map_mbtiles (MBTiles/SQLite)
- [ ] Gestión de versiones de cartas offline (check for updates)
- [ ] Cache invalidation: limpiar cache de imágenes en app update

### Criterios de completado Fase 14
- [ ] Se puede ver boats, documents y trips sin conexión
- [ ] Se puede crear/editar sin conexión y se sincroniza al reconectar
- [ ] Las fotos se muestran offline tras primera carga
- [ ] Cartas náuticas offline para zona descargada
- [ ] Conflictos se resuelven sin pérdida de datos

---

## FASE 15: Social y Estadísticas
**Objetivo:** Funcionalidades sociales y de gamificación.

**Dependencias:** Fase 14 completada.

### Tareas

#### 15.1 — Trip sharing
- [ ] Generar link público con mapa del viaje
- [ ] Página web pública con el track renderizado
- [ ] Botón compartir en detalle de viaje (WhatsApp, email, etc.)

#### 15.2 — Trip statistics
- [ ] Dashboard: distancia total navegada, horas en el mar, puertos visitados
- [ ] Estadísticas por barco y totales
- [ ] Resumen anual de navegación (year in review)

#### 15.3 — Boat profile
- [ ] Página pública del barco (shareable link)
- [ ] Foto, datos, estadísticas de navegación

### Criterios de completado Fase 15
- [ ] Links de viajes compartidos funcionan y muestran el mapa
- [ ] Dashboard de estadísticas muestra datos reales
- [ ] Resumen anual genera correctamente

---

## FASE 16: Infraestructura y Producción
**Objetivo:** CI/CD, testing, compliance y launch.

**Dependencias:** Puede ejecutarse en paralelo a fases 13-15.

### Tareas

#### 16.1 — Test coverage
- [ ] Go API: unit tests para services con mocked ports (objetivo 80%+)
- [ ] Go API: integration tests para repos contra DB real (testcontainers-go)
- [ ] Go API: table-driven tests con t.Run() y t.Parallel()
- [ ] Go API: golden files para assertions de JSON responses complejos
- [ ] Go API: benchmarks para queries PostGIS y batch inserts (b.Run())
- [ ] Flutter: unit tests para providers y repositories (mocktail)
- [ ] Flutter: widget tests para shared widgets y pantallas clave
- [ ] Flutter: test sealed class branches con exhaustive switch

#### 16.2 — CI/CD pipeline (GitHub Actions)
- [ ] On push to develop: lint + test (Go y Flutter)
- [ ] On push to main: full deploy
- [ ] Build checks: `golangci-lint run`, `flutter analyze`, `flutter test`
- [ ] Docker image build y push al registry
- [ ] Pre-commit hooks: lint + format before commit
- [ ] golangci-lint config: errcheck, gosimple, govet, staticcheck, gosec, revive, gocritic, exhaustive

#### 16.3 — Docker & Deploy
- [ ] Multi-stage Docker: build stage → `gcr.io/distroless/static-debian12` final (~10MB)
- [ ] Supabase Cloud project para staging
- [ ] Go API desplegado en Railway (EU region)
- [ ] Flutter apuntando a staging con `--dart-define=ENVIRONMENT=staging`
- [ ] Environment config: development / staging / production con dart-define flags

#### 16.4 — Analytics
- [ ] Integrar PostHog o Mixpanel en Flutter
- [ ] Eventos clave: signup, login, boat_created, document_created, trip_started, trip_completed
- [ ] Event properties: user_id, boat_id, timestamps
- [ ] Dashboard de retención y uso

#### 16.5 — Legal y compliance
- [ ] Privacy policy (web page)
- [ ] Terms of service (web page)
- [ ] GDPR: endpoint para exportar datos del usuario (JSON)
- [ ] GDPR: endpoint para eliminar cuenta y todos los datos
- [ ] App Store / Google Play metadata y screenshots

#### 16.6 — Database hardening
- [ ] Verificar pgxpool config: MaxConns=10, MinConns=2, MaxConnLifetime=1h, MaxConnIdleTime=30m
- [ ] Verificar que todas las queries usan context.Context como primer param
- [ ] Verificar RLS: todas las tablas con `user_id = auth.uid()` policy
- [ ] Verificar queries parameterizadas (no string concatenation)
- [ ] Migration rollback strategy: down migrations para cada up migration
- [ ] TxManager pattern: services inician transactions, repos aceptan tx

### Criterios de completado Fase 16
- [ ] CI pipeline verde en cada push
- [ ] Test coverage: Go 80%+, Flutter tests para flujos principales
- [ ] Docker image < 15MB
- [ ] Staging environment funcional
- [ ] Analytics captura eventos clave
- [ ] Legal docs publicados
- [ ] GDPR: export y delete funcionan

---

## FASE 17: Premium y Monetización (Futuro)
**Objetivo:** Modelo de suscripción para sostenibilidad.

### Tareas
- [ ] Free tier: 1 barco, document tracking básico
- [ ] Premium tier: barcos ilimitados, analytics avanzados, export logbook PDF, prioridad en notificaciones
- [ ] In-app purchase (App Store + Google Play)
- [ ] Server-side entitlement validation
- [ ] Admin panel web para organizadores de eventos

---

## RESUMEN

| Fase | Nombre | Estado | Estimación |
|------|--------|--------|------------|
| 0 | Scaffolding | ✅ HECHO | — |
| 1 | Base de datos | ✅ HECHO | — |
| 2 | Go API Core | ✅ HECHO | — |
| 3 | Go Repos PostgreSQL | ✅ HECHO | — |
| 4 | Go Services + Handlers | ✅ HECHO | — |
| V | Verificación | ✅ HECHO | — |
| 5 | Cron + Novu + Device Tokens | ✅ HECHO | — |
| 6 | Flutter Core | ✅ HECHO | — |
| 7 | Flutter Mi Barco | ✅ HECHO | — |
| 8 | Flutter Cartas | ✅ HECHO | — |
| 9 | Flutter Meteo | ✅ HECHO | — |
| 10 | Flutter Regatas | ✅ HECHO | — |
| 11 | Flutter Logbook | ✅ HECHO | — |
| **12** | **Integración + Pulido** | **EN PROGRESO** | **8-12 días** |
| **13** | **GPS Trip Recording** | **PENDIENTE** | **3-5 días** |
| **14** | **Offline Completo** | **PENDIENTE** | **5-7 días** |
| **15** | **Social y Estadísticas** | **PENDIENTE** | **3-4 días** |
| **16** | **Infra y Producción** | **PENDIENTE** | **5-7 días** |
| **17** | **Premium (Futuro)** | **FUTURO** | **TBD** |
| | **TOTAL RESTANTE** | | **~24-35 días** |

---

## NOTAS PARA CLAUDE CODE

- Fase 12 es la prioridad actual. Completar todos los E2E antes de pasar a fase 13.
- En Fase 12, testear en emulador cada flujo antes de marcarlo como completado.
- Fase 16 (CI/CD, tests) puede ejecutarse en paralelo a fases 13-15.
- Commits descriptivos: `feat(fase-12): add document photo upload`, `fix(fase-12): correct boat model JSON keys`.
- Todo el código debe pasar `golangci-lint run` (Go) y `flutter analyze` (Flutter) sin errores.
- Sigue las reglas del CLAUDE.md al pie de la letra para cualquier código nuevo.
- Para local dev: `make db-start` → `docker compose up -d` → `make mobile-run-emu`
- SUPABASE_ANON_KEY para local: usar el JWT del `supabase status --output json` (campo ANON_KEY), NO el publishable key.
- Migrations manuales: cuando `supabase db reset` no aplica seeds, usar `docker exec -i supabase_db_supabase psql -U postgres < seed.sql`
