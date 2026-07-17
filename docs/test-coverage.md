# Matriz de cobertura de tests — Navis Mobile

Estado de cobertura de la app Flutter tras las oleadas W1–W5 de tests de
widget. Documento vivo: actualízalo al añadir pantallas, tests o al cerrar
gaps.

## Capas de test

| Capa | Ubicación | Ejecución |
|------|-----------|-----------|
| Tests de widget/unit | `apps/mobile/test/` | CI en cada PR (`flutter test --exclude-tags golden`) |
| Golden screenshots | `apps/mobile/test/golden/` | Solo local (`--update-goldens --tags golden`); **excluidos de CI** (píxeles dependen de la máquina) |
| E2E (integration_test) | `apps/mobile/integration_test/` | Manual/simulador iOS contra stack local (`make mobile-e2e`); excluidos del job normal de CI |

## Oleadas

- **W1** (#35): harness de tests — `test/helpers/` (buildRoutedTestApp +
  RouteSpy, runAsyncStateMatrix, planOverrides/expectPaywall, factories,
  FakeGeo, Supabase fake) + boat dashboard y chart spike.
- **W2/W4** (#38): matriz de estados para pantallas CRUD sin cobertura —
  boat form, map picker, logbook, trip detail/edit/stats, maintenance,
  bookings, document list/detail, check-email.
- **W3** (#36): gating Free/Pro y paywall — plan_gating, paywall_sheet,
  is_pro_provider.
- **E2E** (#29, #33, #34): fundación + journeys J01–J08.
- **W5** (esta rama): community, groups, regattas, checklist + extensiones
  de events/profile/settings + esta matriz.

## Auth

| Pantalla × caso | Cubierto por |
|---|---|
| Login: render, validación, submit, error | `test/features/auth/login_screen_test.dart` · E2E J01 |
| Register: render, validación, submit | `test/features/auth/register_screen_test.dart` · E2E J01 |
| CheckEmail: render, reenvío | `test/features/auth/check_email_screen_test.dart` (W2/W4) — inalcanzable en E2E (confirmación de email desactivada en local) |
| Deep-link/callback de sesión | **GAP** (requiere navegador real) |

## Boats

| Pantalla × caso | Cubierto por |
|---|---|
| Dashboard: loading/error/vacío/poblado, límite de barcos Free/Pro | `boat_dashboard_screen_test.dart` (W1) · `plan_gating_test.dart` (W3) · E2E J02 |
| Boat form: validación, crear, editar, puerto base opcional | `boat_form_screen_test.dart` (W2/W4) · E2E J02 |
| Boat detail: secciones, readiness, acciones, borrar | `boat_detail_screen_test.dart` · E2E J02 |
| Map picker: selección, nombre, confirmación | `map_picker_screen_test.dart` (W2/W4) |
| Provider (CRUD optimista) | `boat_provider_test.dart` |
| Subida de foto (Storage real) | **GAP** widget (E2E J02 cubre flujo sin foto) |
| Barco compartido multiusuario (share code, permisos de miembro) | permisos cubiertos en `maintenance_screen_test.dart` y `bookings_screen_test.dart`; el flujo real de 2 usuarios es **GAP** (requiere 2 sesiones) |

## Documents

| Pantalla × caso | Cubierto por |
|---|---|
| Lista: 4 estados, badges de estado | `document_list_screen_test.dart` (W2/W4) · E2E J03 |
| Form: tipos canónicos, validación, guardar | `document_form_screen_test.dart` · E2E J03 |
| Detail: render, borrar | `document_detail_screen_test.dart` (W2/W4) |
| Subida de adjuntos (Storage) | **GAP** (frontera nativa/Storage) |

## Logbook / Trips

| Pantalla × caso | Cubierto por |
|---|---|
| Lista: 4 estados, filtros | `logbook_screen_test.dart` (W2/W4) · E2E J05 |
| Trip detail: mapa, stats, compartir | `trip_detail_screen_test.dart` (W2/W4) — share sheet nativo **GAP** |
| Trip edit: validación, guardar | `trip_edit_screen_test.dart` (W2/W4) |
| Trip stats | `trip_stats_screen_test.dart` (W2/W4) |
| Grabación GPS (provider) | `trip_recording_provider_test.dart` (FakeGeo) |
| Pantalla de grabación en vivo (mapa + GPS real) | E2E J05 (simulador); widget **GAP** parcial |

## Maintenance / Costs

| Pantalla × caso | Cubierto por |
|---|---|
| Maintenance: tabs, 4 estados, tareas, chips sugeridos, sheets, permisos | `maintenance_screen_test.dart` (W2/W4) · E2E J04 |
| Expenses: estados, resumen, badges de split | `maintenance_screen_test.dart` (W2/W4) |
| Split sheet: gating Pro, reparto | `plan_gating_test.dart` (W3) |
| Cost analytics: 4 estados, gating Pro | `cost_analytics_screen_test.dart` · `plan_gating_test.dart` (W3) · golden `cost_golden_test.dart` |
| Settle/liquidar splits multiusuario | **GAP** (flujo de 2 usuarios) |

## Shared (bookings)

| Pantalla × caso | Cubierto por |
|---|---|
| Bookings: 4 estados, nombres de reservante, crear (pickers), solapes, borrar | `bookings_screen_test.dart` (W2/W4) |
| Gating Pro de bookings | `plan_gating_test.dart` (W3) |

## Readiness / Passport / Anomaly

| Pantalla × caso | Cubierto por |
|---|---|
| Readiness: estados, score, bloques Free vs Pro | `readiness_screen_test.dart` · golden `readiness_golden_test.dart` |
| Passport: generación de PDF, gating Pro | `passport_pdf_test.dart` · `plan_gating_test.dart` (W3) — share sheet nativo **GAP** |
| Anomaly alerts UI | cubierto vía dashboard/cost; pantalla dedicada **GAP** menor |

## Weather / Charts

| Pantalla × caso | Cubierto por |
|---|---|
| Weather: estados, overview, day detail | `weather_screen_test.dart` · `day_detail_sheet_test.dart` · E2E J06 |
| Charts: spike del mapa, tiles | `chart_map_spike_test.dart` (W1) · E2E J06 — tiles offline (MBTiles) **GAP** |

## Community (W5)

| Pantalla × caso | Cubierto por |
|---|---|
| 3 tabs render; tab Regattas embebe EventsBody | `community_screen_test.dart` (W5) |
| My groups: loading/error/vacío/poblado | `community_screen_test.dart` (W5) |
| Discover: loading/error/vacío/poblado | `community_screen_test.dart` (W5) |
| FAB + join-by-code solo en tabs de clubes | `community_screen_test.dart` (W5) |
| Crear grupo: Free→paywall / Pro→`/groups/new` (CTA y FAB) | `community_screen_test.dart` (W5, CTA) · `plan_gating_test.dart` (W3, FAB) |
| Discover join: Request→requestJoin+snackbar, error, label Pending | `community_screen_test.dart` (W5) |
| Join by code: diálogo, éxito, código inválido, cancelar | `community_screen_test.dart` (W5) |
| FAB tapado por bottom nav | bug pendiente (ver abajo) |

## Groups (W5)

| Pantalla × caso | Cubierto por |
|---|---|
| Detail: loading/error/poblado; label público/privado + nº miembros | `group_detail_screen_test.dart` (W5) |
| Invite code: solo owner+privado | `group_detail_screen_test.dart` (W5) |
| Requests (solo owner): admitir/rechazar + snackbars | `group_detail_screen_test.dart` (W5) |
| Sección regatas: estados + 4 badges de estado; botón Schedule | `group_detail_screen_test.dart` (W5) |
| Miembros: "You", estrella de owner, expulsar | `group_detail_screen_test.dart` (W5) |
| Acciones: owner Delete (confirm) / member Leave (confirm) / no-miembro nada | `group_detail_screen_test.dart` (W5) |
| Form: nombre requerido, visibilidad, éxito→detalle, fallo→snackbar | `group_form_screen_test.dart` (W5) · E2E J07 |

## Regattas (W5)

| Pantalla × caso | Cubierto por |
|---|---|
| Detail: loading/error/poblado; 4 badges de estado | `regatta_detail_screen_test.dart` (W5) |
| RSVP: pills→setRsvp, error→snackbar; contadores; lista de miembros | `regatta_detail_screen_test.dart` (W5) · E2E J07 |
| Owner planned: CTA checklist→ruta; cancelar regata | `regatta_detail_screen_test.dart` (W5) |
| Owner recording: tarjeta en curso; completed: borrar (confirm) | `regatta_detail_screen_test.dart` (W5) |
| No-owner: sin controles | `regatta_detail_screen_test.dart` (W5) |
| Schedule: picker de barco (vacío→CTA `/boats/new`), puerto gated, validaciones, éxito→pop, fallo | `schedule_regatta_screen_test.dart` (W5) · E2E J07 |
| Start desde evento: grupos propios, CTAs vacíos, validaciones, join→`/regattas/<id>`, cadena de fallback del puerto | `start_event_regatta_screen_test.dart` (W5) |
| Checklist local: 10 ítems, añadir/quitar, Start Trip→record autostart(+port) | `pre_trip_checklist_screen_test.dart` (W5) |
| Checklist regata: estados, toggle+revert optimista, labels por allChecked, completar→record | `pre_trip_checklist_screen_test.dart` (W5) |

## Events

| Pantalla × caso | Cubierto por |
|---|---|
| Lista/calendario: estados, toggle | `events_screen_test.dart` |
| Detail: render, badge, interés, error/retry | `event_detail_screen_test.dart` |
| 'Watch live' con/sin cobertura en vivo | `event_detail_screen_test.dart` (W5) — abrir URL externa (url_launcher) **GAP** nativo |
| 'Join as a group' → start-regatta; solo tipo regatta | `event_detail_screen_test.dart` (W5) |
| Descripción/clases de barco ausentes | `event_detail_screen_test.dart` (W5) |

## Profile / Settings / Billing

| Pantalla × caso | Cubierto por |
|---|---|
| Profile: render, avatar, menú, logout, sin sesión | `profile_screen_test.dart` |
| Badge de plan (Pro/Free/oculto sin cuenta) | `profile_screen_test.dart` (W5) |
| Settings: secciones, dark mode, offline data, logout | `settings_screen_test.dart` |
| Selector de idioma: diálogo 3 opciones, Español persiste | `settings_screen_test.dart` (W5) |
| Toggles de notificaciones persisten en SharedPreferences | `settings_screen_test.dart` (W5) |
| Borrar cuenta: cancelar paso 1 y 2, type-to-confirm, fallo→snackbar | `settings_screen_test.dart` (W5) · E2E J08 (borrado real) |
| Paywall sheet: estados, compra/restore | `paywall_sheet_test.dart` (W3) — compra real (StoreKit/Play) **GAP** nativo |
| Gating por feature (insights, splits, grupos, bookings, passport) | `plan_gating_test.dart` (W3) |

## Gaps restantes (explícitos)

1. **Fronteras nativas** — no testeables en widget tests:
   - Share sheets (pasaporte PDF, compartir trip).
   - Compras reales RevenueCat/StoreKit/Play (solo se testea el flujo hasta
     el SDK con mocks).
   - `url_launcher` (Watch live, mailto de soporte, enlaces legales).
   - Push notifications (FCM) y deep links desde notificación.
2. ~~Flujos multiusuario de barco compartido~~ — **CUBIERTO (G2, #43)**: E2E
   J09 con dos usuarios reales (compartir por código, unirse, vista de
   miembro, split de gasto). Queda sin cubrir: settle desde la sesión del
   segundo usuario y permisos granulares por miembro.
3. **CheckEmailScreen inalcanzable en E2E** — la confirmación de email está
   desactivada en el stack local; cubierta solo por widget test.
4. ~~Golden tests~~ — **AMPLIADO (G4, #44)**: 12 pantallas con baseline
   claro+oscuro (locale es). Siguen excluidos de CI (píxeles dependientes de
   máquina); regenerar con `--update-goldens --tags golden`. `document_list`
   deriva con el día del calendario (fechas relativas) — regenerar al
   refrescar.
5. ~~Offline~~ — **CUBIERTO (G3, #42)**: banner, MutationQueue, enqueue de
   repos y SyncService (27 tests). Hallazgos de diseño documentados en la PR
   (pérdida silenciosa al 5º reintento, sin dedup, gap del primer syncAll,
   `core/network/mutation_queue.dart` es código muerto).
6. **Grabación en vivo (mapa + GPS)** — cubierta en E2E con simulador; sin
   test de widget del render del mapa durante la grabación.

## Bugs de producto encontrados durante el plan de tests

| # | Bug | Estado |
|---|-----|--------|
| 1 | Puerto base obligatorio devolvía 422 al crear barco sin puerto | **ARREGLADO** (#30) |
| 2 | `NotificationService` lanzaba excepción y rompía el arranque/logout | **ARREGLADO** (#30) |
| 3 | Tipos de documento no canónicos → 400 del API | **ARREGLADO** (#31) |
| 4 | Fechas sin zona UTC → 400 del API (RFC3339) | **ARREGLADO** (#32) |
| 5 | Overflow de ~100px con teclado abierto en formularios | **PENDIENTE** (no reproducible aislado: login/register/diálogos son scrollables; cazar con pantalla identificada) |
| 6 | FAB de Community queda bajo el bottom nav (taps caían en Profile) | **ARREGLADO** (#41) |
| 7 | `SplitSheet` crasheaba en `initState` al leer l10n sin contexto | **ARREGLADO** (#36) |
| 8 | Pills de resumen del completion dialog desbordaban con valores largos | **ARREGLADO** (#41) |
| 9 | Cachés de providers user-scoped sobrevivían al cambio de cuenta (la 2ª cuenta veía datos de la 1ª) | **ARREGLADO** (#43) |
