# Roadmap de Implementación — Navis (Actualizado 2026-04-26)

Estado actual: Fases 0-4 y 6-11 implementadas. Este roadmap cubre solo lo que queda.

---

## FASE V: Verificación — Compilación y calidad del código existente
**Objetivo:** Asegurar que todo el código existente compila, pasa linters y no tiene errores antes de construir encima.

**Dependencias:** Ninguna. Es el punto de partida actual.

### Tareas

#### V.1 — Go API: compilación y linting
- Ejecutar `go build ./...` en `apps/api/` — corregir todos los errores de compilación
- Ejecutar `golangci-lint run` — corregir todos los warnings
- Verificar que `go test ./...` corre (aunque no haya tests aún, que no falle por imports rotos)
- Verificar que `go vet ./...` pasa limpio

#### V.2 — Flutter: análisis y compilación
- Ejecutar `flutter pub get` en `apps/mobile/`
- Ejecutar `flutter analyze` — corregir todos los warnings y errores
- Ejecutar `dart format --set-exit-if-changed .` — formatear todo el código
- Verificar que `flutter test` corre sin fallos (aunque no haya tests)
- Verificar que los imports entre features no cruzan boundaries (feature A no importa de feature B)

#### V.3 — Base de datos
- Verificar que las migrations se ejecutan en orden sin errores contra una DB limpia
- Verificar que el seed.sql inserta datos correctamente
- Verificar que las columnas computadas (document status) funcionan
- Verificar que los índices PostGIS se crean correctamente

#### V.4 — Docker
- Verificar que `docker compose up` levanta Postgres + API sin errores
- Verificar que la API se conecta a la DB y responde en GET /health

#### V.5 — Coherencia arquitectónica
- Verificar que los domain entities Go coinciden con el schema SQL (mismos campos, mismos tipos)
- Verificar que los DTOs Go cubren todos los campos necesarios para request/response
- Verificar que los models Flutter coinciden con los DTOs Go (mismos JSON keys)
- Verificar que las interfaces de port tienen todos los métodos que usan los services
- Verificar que el router registra todas las rutas que los handlers implementan

### Criterios de completado Fase V
- [ ] `go build ./...` compila sin errores
- [ ] `golangci-lint run` pasa limpio
- [ ] `flutter analyze` pasa sin warnings
- [ ] `dart format` no reporta cambios
- [ ] Docker compose levanta correctamente
- [ ] No hay imports cruzados entre Flutter features
- [ ] Domain ↔ SQL ↔ DTO ↔ Model están alineados

---

## FASE 5: Go API — Cron de alertas, FCM y device tokens
**Objetivo:** Sistema de notificaciones push completo. El cron revisa caducidades diariamente y envía push via FCM a los dispositivos registrados.

**Dependencias:** Fase V completada.

### Tareas

#### 5.1 — Migration: tabla device_tokens
- Nueva migration `00010_create_device_tokens.sql`:
  ```sql
  CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (token)
  );
  CREATE INDEX idx_device_tokens_user_id ON device_tokens (user_id);
  ```
- RLS: SELECT/INSERT/DELETE donde user_id = auth.uid()

#### 5.2 — Go: domain + port + repo para device tokens
- `internal/domain/device_token.go` — struct DeviceToken, enum Platform
- Añadir a `internal/port/repository.go`:
  ```go
  type DeviceTokenRepository interface {
      Upsert(ctx context.Context, userID, token, platform string) error
      Delete(ctx context.Context, token string) error
      GetByUserID(ctx context.Context, userID string) ([]DeviceToken, error)
  }
  ```
- `internal/adapter/postgres/device_token_repo.go` — implementación SQL

#### 5.3 — Go: handler para device tokens
- `internal/handler/device_handler.go`:
  - `POST /api/v1/devices` — registrar token (upsert)
  - `DELETE /api/v1/devices/{token}` — eliminar token (logout)
- DTO: `CreateDeviceRequest { token, platform }`
- Registrar rutas en router

#### 5.4 — Revisar cliente FCM existente
- Verificar que `internal/adapter/fcm/client.go` implementa correctamente la interfaz `PushNotifier`
- Debe recibir device tokens (no user_id directamente) y enviar via Firebase Admin SDK
- Manejar errores de FCM: token inválido → eliminar de DB, rate limit → reintentar

#### 5.5 — Revisar cron de alertas existente
- Verificar que `internal/cron/expiration_checker.go`:
  - Consulta documents con GetExpiring() del repo
  - Obtiene device_tokens del usuario
  - Verifica en notification_logs que no se haya enviado hoy
  - Envía push a CADA device token del usuario
  - Registra en notification_logs
- Mensaje: "Tu {tipo_documento} del {nombre_barco} caduca en {X} días"
- Log de ejecución: documentos revisados, notificaciones enviadas, errores

#### 5.6 — Wiring en main.go
- Instanciar DeviceTokenRepository
- Conectar al handler y al cron
- Registrar rutas de devices

#### 5.7 — Tests
- Test unitario del cron con mocks
- Test de que no duplica notificaciones (notification_logs)
- Test de que respeta alert_days de cada documento
- Test de upsert/delete de device tokens

### Criterios de completado Fase 5
- [ ] Migration crea tabla device_tokens sin errores
- [ ] POST /api/v1/devices registra token correctamente
- [ ] DELETE /api/v1/devices/{token} elimina token
- [ ] El cron detecta documentos por caducar y envía push a todos los device tokens del usuario
- [ ] No se duplican notificaciones para el mismo documento en el mismo día
- [ ] Tests pasan

---

## FASE 12: Integración, push en Flutter, testing E2E y pulido
**Objetivo:** Todo conectado end-to-end, notificaciones push en dispositivos reales, UI pulida y app lista para beta.

**Dependencias:** Fase 5 completada.

### Tareas

#### 12.1 — Push notifications en Flutter
- Añadir `firebase_messaging` y `firebase_core` a pubspec.yaml
- Configurar Firebase project (iOS + Android)
- `features/notifications/data/notification_repository.dart`:
  - Inicializar FCM, pedir permisos
  - Obtener device token
  - Escuchar token refresh
  - Registrar token en Go API (POST /api/v1/devices)
  - Eliminar token en logout (DELETE /api/v1/devices/{token})
- `features/notifications/presentation/providers/notification_provider.dart`:
  - Provider que inicializa FCM al login
  - Maneja notificaciones en foreground (snackbar con acción)
  - Maneja notificaciones en background (redirige al documento)
- Deep link: al pulsar notificación de caducidad → navegar a document_detail_screen

#### 12.2 — Registro automático de device token
- Al login exitoso → registrar token
- Al logout → eliminar token
- Al recibir token refresh de Firebase → actualizar en API
- Manejar caso de permisos denegados gracefully

#### 12.3 — Testing end-to-end manual
- [ ] Crear cuenta → login → ver pantalla de tabs
- [ ] Registrar un barco con foto → verificar que aparece en dashboard
- [ ] Añadir documentos con distintas fechas de caducidad → verificar semáforo
- [ ] Subir foto de documento → verificar en Supabase Storage
- [ ] Abrir cartas náuticas → verificar tiles OpenSeaMap + posición GPS
- [ ] Consultar meteo del puerto base → verificar datos de viento y oleaje
- [ ] Ver eventos → marcar "Me interesa" → verificar persistencia
- [ ] Iniciar grabación de trip → verificar tracking GPS → detener → completar datos
- [ ] Ver logbook → verificar trip con track sobre mapa
- [ ] Simular documento caducado → verificar push notification llega
- [ ] Pulsar notificación → verificar navegación a documento correcto

#### 12.4 — Pulido UI
- **Transiciones:** Hero animations entre listas y detalle, page transitions suaves
- **Pull-to-refresh** en todas las listas (boats, documents, events, logbook)
- **Skeleton shimmer** loaders en todas las pantallas con carga async
- **Empty states** con NavisEmptyState: ilustración + texto + CTA en cada lista vacía
- **Error states** con NavisErrorWidget: mensaje + botón retry en cada pantalla
- **Snackbars** para confirmación de acciones (creado, actualizado, eliminado)
- **Haptic feedback** en acciones importantes (delete, start/stop recording)
- **Scroll infinito** suave en listas paginadas con loading indicator al final
- **Animaciones micro:** FAB scale on tap, card press effect, progress indicators
- **Status bar** adaptada al tema (iconos claros sobre fondo oscuro)

#### 12.5 — Offline básico
- Detectar estado de conectividad (connectivity_plus)
- Mostrar banner "Sin conexión" cuando offline
- Cachear última respuesta exitosa en memoria para boat dashboard y documents
- Permitir ver datos cacheados sin conexión
- Encolar mutaciones locales y reintentar al reconectar (solo para operaciones críticas: start trip)

#### 12.6 — Accessibility pass
- Verificar semanticLabel en todas las imágenes
- Verificar Tooltip en todos los iconos interactivos
- Verificar touch targets mínimos 48x48 dp
- Verificar contraste WCAG AA en tema oscuro
- Probar con TalkBack (Android) al menos el flujo principal

#### 12.7 — Performance pass
- Verificar `const` constructors en todos los widgets estáticos
- Verificar `ListView.builder` en lugar de `Column(children: list.map(...))`
- Añadir `RepaintBoundary` en el mapa y charts
- Verificar que providers usan `autoDispose` por defecto
- Verificar que las imágenes se comprimen antes de subir
- Profile con Flutter DevTools: no jank en scroll de listas

#### 12.8 — Error reporting
- Integrar Sentry en Flutter (sentry_flutter)
- Integrar Sentry en Go API (sentry-go middleware)
- Configurar DSN via env vars
- Capturar unhandled exceptions en ambos lados
- Filtrar PII de los reports

#### 12.9 — Preparar para beta
- App icon y splash screen con branding Navis
- Configurar Firebase project completo (iOS + Android)
- Configurar signing (iOS certificates, provisioning profiles, Android keystore)
- Build de release: `flutter build apk --release` y `flutter build ipa`
- Subir a TestFlight (iOS) y Google Play Internal Testing (Android)
- Landing page básica (opcional, low priority)

### Criterios de completado Fase 12
- [ ] Push notifications llegan al dispositivo real cuando un documento está por caducar
- [ ] Todos los flujos E2E funcionan sin crasheos
- [ ] UI pulida: transiciones, loaders, empty states, error states, pull-to-refresh
- [ ] Banner offline funciona
- [ ] Accessibility pass completado
- [ ] Performance: sin jank en scroll, DevTools limpio
- [ ] Sentry reporta errores correctamente en ambos lados
- [ ] App subida a TestFlight / Google Play Internal Testing

---

## RESUMEN

| Fase | Nombre | Estado | Estimación |
|------|--------|--------|------------|
| 0 | Scaffolding | ✅ HECHO | — |
| 1 | Base de datos | ✅ HECHO | — |
| 2 | Go API Core | ✅ HECHO | — |
| 3 | Go Repos PostgreSQL | ✅ HECHO | — |
| 4 | Go Services + Handlers | ✅ HECHO | — |
| **V** | **Verificación** | **PENDIENTE** | **1-2 días** |
| **5** | **Cron + FCM + Device Tokens** | **PARCIAL → PENDIENTE** | **1-2 días** |
| 6 | Flutter Core | ✅ HECHO | — |
| 7 | Flutter Mi Barco | ✅ HECHO | — |
| 8 | Flutter Cartas | ✅ HECHO | — |
| 9 | Flutter Meteo | ✅ HECHO | — |
| 10 | Flutter Regatas | ✅ HECHO | — |
| 11 | Flutter Logbook | ✅ HECHO | — |
| **12** | **Integración + Pulido** | **NO EMPEZADO** | **4-6 días** |
| | **TOTAL RESTANTE** | | **~6-10 días** |

---

## NOTAS PARA CLAUDE CODE

- Ejecuta Fase V primero. No construyas encima de código que no compila.
- En Fase V, corrige errores sin cambiar la arquitectura — solo ajustes para que compile y pase linters.
- En Fase 5, reutiliza el código existente del cron y FCM, solo completa lo que falta (device_tokens).
- En Fase 12, testea en dispositivo real (o emulador) cada flujo antes de marcarlo como completado.
- Commits descriptivos: `fix(fase-V): corregir imports rotos en Go API`, `feat(fase-5): añadir tabla device_tokens y endpoints`.
- Todo el código debe pasar `golangci-lint run` (Go) y `flutter analyze` (Flutter) sin errores.
- Sigue las reglas del CLAUDE.md al pie de la letra para cualquier código nuevo.
