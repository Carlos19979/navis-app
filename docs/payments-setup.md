# Navis — Guía de configuración de pagos (RevenueCat + App Store + Play)

El **código de pagos ya está implementado**. Esta guía cubre solo la **configuración externa**
(cuentas de developer) que hace falta para que las compras funcionen de verdad. Sigue los
pasos en orden.

> ⚠️ **Nombres exactos.** El código ya espera valores concretos. Si no los respetas, el paywall
> no encontrará productos o el webhook no desbloqueará el plan. Los valores obligatorios están
> marcados con 🔒.

## Valores que el código ya espera (no los cambies)

| Qué | Valor | Dónde está en el código |
|---|---|---|
| 🔒 Entitlements de RevenueCat | **`plus`** y **`pro`** | `apps/mobile/lib/features/billing/billing.dart` (`plusEntitlementId`/`proEntitlementId`) y `apps/api/internal/handler/webhook_handler.go` (`entitlementPlus`/`entitlementPro`) |
| Product IDs Plus (sugeridos) | `navis_plus_monthly` — **4,99 €** · `navis_plus_yearly` — **39,99 €** | offering de RevenueCat (entitlement `plus`) |
| Product IDs Pro (sugeridos) | `navis_pro_monthly` — **8,99 €** · `navis_pro_yearly` — **69,99 €** | offering de RevenueCat (entitlement `pro`) |
| ⚠️ Convención de nombres | el paywall separa tiers por el identificador (`*_plus_*` vs `*_pro_*`) | `paywall_sheet.dart` (`_tierOf`) |
| 🔒 `app_user_id` de RevenueCat | = **Supabase `user_id`** | la app llama `Purchases.logIn(user.id)` |
| 🔒 Ruta del webhook | `POST /api/v1/webhooks/revenuecat` | `apps/api/internal/router/router.go` (fuera del JWT) |
| 🔒 Auth del webhook | valor exacto del header `Authorization` = `REVENUECAT_WEBHOOK_SECRET` | `webhook_handler.go` (`subtle.ConstantTimeCompare`) |

Los product IDs mensual/anual pueden ser los que quieras — la app los lee del offering y los
etiqueta por `packageType` (Mensual/Anual), no por su ID. Pero el **entitlement debe llamarse `pro`**.

---

## Paso 1 — App Store Connect (iOS)

1. **Acuerdos.** En *Business → Agreements, Tax, and Banking*: firma el **Paid Applications
   Agreement** y rellena datos fiscales y bancarios. **Sin esto, los IAP no se activan.**
2. **Grupo de suscripción.** App → *Subscriptions* → crea un grupo (p. ej. `Navis`).
3. **Productos** dentro del grupo (4 productos, 2 tiers):
   - `navis_plus_monthly` — Auto-Renewable, **4,99 €/mes**.
   - `navis_plus_yearly` — Auto-Renewable, **39,99 €/año**.
   - `navis_pro_monthly` — Auto-Renewable, **8,99 €/mes**.
   - `navis_pro_yearly` — Auto-Renewable, **69,99 €/año**.
   - Rellena display name, descripción y screenshot de revisión (Apple lo exige).
4. **App Store Connect API key (In-App Purchase).** *Users and Access → Integrations → In-App
   Purchase* → genera una key y **guárdala** (la subes a RevenueCat en el paso 3). Sirve para que
   RevenueCat reciba las notificaciones de servidor de Apple.
5. **Sandbox testers.** *Users and Access → Sandbox → Testers* → crea al menos un tester
   (un email que NO sea tu Apple ID real).
6. **Capability + IAP en la app.** En Xcode, target Runner → *Signing & Capabilities* → añade
   **In-App Purchase**. (Recuerda: el proyecto iOS vive en los hacks locales de `ios/`, no
   commiteados — ver `implemented-features.md`.)
7. Cuando todo esté, **envía las suscripciones a revisión** junto con el build. La revisión de
   suscripción es una **puerta de aprobación de la App Store**.

## Paso 2 — Google Play Console (Android)

1. Play Console → tu app → *Monetize → Products → Subscriptions*.
2. Crea las suscripciones equivalentes (mismos IDs `navis_pro_monthly` / `navis_pro_yearly`,
   8,99 € / 69,99 € (y los `navis_plus_*` a 4,99 € / 39,99 €)). En Play, un producto de suscripción tiene *base plans* — crea un base plan
   mensual y otro anual (o dos productos, como prefieras; mantén los IDs coherentes con RevenueCat).
3. **Service account para RevenueCat.** Google Cloud → crea una service account con acceso a la
   API de Google Play Developer, descarga el JSON, y en Play Console concédele permisos de
   *View financial data* + *Manage orders*. Ese JSON se sube a RevenueCat.

> Para el MVP puedes lanzar **solo iOS** y dejar Android para después: la app degrada con elegancia
> si no hay clave RevenueCat de esa plataforma (no revienta, solo no muestra productos).

## Paso 3 — RevenueCat (dashboard)

1. Crea un **proyecto** y añade las dos apps (iOS y Android).
   - iOS: pega el **App Store Connect API key** del paso 1.4 + el bundle ID.
   - Android: sube el **JSON de la service account** del paso 2.3 + el package name.
2. **Products.** *Products* → importa/crea los 4 productos (`navis_plus_monthly`,
   `navis_plus_yearly`, `navis_pro_monthly`, `navis_pro_yearly`) en cada tienda.
3. 🔒 **Entitlements.** *Entitlements* → crea **dos**: `plus` (adjunta los dos productos
   `navis_plus_*`) y `pro` (adjunta los dos `navis_pro_*`). Los identificadores **tienen
   que ser `plus` y `pro`**. Una compra de Pro concede el entitlement `pro`; Plus el `plus`.
4. **Offering.** *Offerings* → crea un offering **Current** con los 4 **packages** (los dos
   de Plus y los dos de Pro). La app lee `offerings.current.availablePackages` y separa por
   tier según el identificador del producto (`*_plus_*` / `*_pro_*`).
5. **SDK keys.** *API keys* → copia la **public SDK key de iOS** y la **de Android** (empiezan por
   `appl_...` y `goog_...`). Van al build de Flutter (paso 4).
6. 🔒 **Webhook.** *Integrations → Webhooks* → añade uno:
   - URL: `https://<tu-dominio-de-api>/api/v1/webhooks/revenuecat`
   - Authorization header: **inventa un secreto** (p. ej. una cadena aleatoria larga) y pégalo. Ese
     mismo valor va en `REVENUECAT_WEBHOOK_SECRET` en la API (paso 4).

## Paso 4 — Cableado de secretos

**Backend (Railway u otro).** Añade la env var:

```
REVENUECAT_WEBHOOK_SECRET=<el mismo valor que pusiste en el webhook de RevenueCat>
```

(También `APP_ENV=production` en prod, para que el dev switcher `PUT /me/plan` **no** se registre.)

**Móvil.** Pasa las SDK keys por `--dart-define` al compilar:

```bash
flutter build ios \
  --dart-define=REVENUECAT_IOS_KEY=appl_XXXXXXXX \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_XXXXXXXX \
  --dart-define=API_URL=https://<tu-api> \
  --dart-define=SUPABASE_URL=https://<tu-supabase>
```

(Estas claves son públicas por diseño, pero igualmente van por dart-define, no commiteadas —
igual que el resto de config local. Ver `implemented-features.md`.)

## Paso 5 — Verificación en dispositivo (sandbox)

> El toolchain de Flutter en este Mac está bloqueado por permisos del SDK. Antes: `sudo chown -R
> $(whoami) /opt/homebrew/share/flutter`, luego `flutter pub get` (instala `purchases_flutter`),
> `flutter analyze` y `flutter test`.

1. En el iPhone, *Ajustes → App Store → Sandbox Account* → inicia sesión con el **tester sandbox**
   del paso 1.5.
2. Lanza la app (build del paso 4). Con el usuario de prueba en plan **free**:
   - Pulsa **añadir 2º barco** o **crear grupo** → debe aparecer el **paywall**.
   - Compra el plan mensual → la UI se **desbloquea al instante** (entitlement de RevenueCat).
   - Mata y reabre la app → **Restaurar compras** debe re-desbloquear.
   - Comprueba que el **backend refleja `pro`**: el webhook de RevenueCat escribe `profiles.plan=pro`
     (puedes verificarlo con `GET /api/v1/me`).

## Paso 6 — F1: Sign in with Apple *(no es de pagos, pero bloquea igual)*

Apple exige Sign in with Apple si ofreces login social (Google). Es otra **puerta de aprobación**
de la App Store. Ver el punto F1 en `implemented-features.md` (providers en Supabase, credenciales
Apple/Google, capability iOS, re-añadir el URL scheme `navis` en `Info.plist`).

---

## Cómo probar el webhook sin esperar a una compra real

Con `REVENUECAT_WEBHOOK_SECRET` puesto en la API, puedes simular los eventos con curl (esto es lo
que se usó en la verificación E2E). `SUB` es el `user_id` de Supabase del usuario:

```bash
# Conceder Pro
curl -s -X POST "$API/api/v1/webhooks/revenuecat" \
  -H "Authorization: $REVENUECAT_WEBHOOK_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"INITIAL_PURCHASE\",\"app_user_id\":\"$SUB\",\"entitlement_ids\":[\"pro\"]}}"

# Expirar (vuelve a free)
curl -s -X POST "$API/api/v1/webhooks/revenuecat" \
  -H "Authorization: $REVENUECAT_WEBHOOK_SECRET" \
  -H "Content-Type: application/json" \
  -d "{\"event\":{\"type\":\"EXPIRATION\",\"app_user_id\":\"$SUB\",\"entitlement_ids\":[\"pro\"]}}"
```

Eventos que **conceden** Pro: `INITIAL_PURCHASE`, `RENEWAL`, `PRODUCT_CHANGE`, `UNCANCELLATION`,
`NON_RENEWING_PURCHASE`, `SUBSCRIPTION_EXTENDED`. Evento que **revoca** (→ free): `EXPIRATION`.
`CANCELLATION` NO revoca (el usuario mantiene acceso hasta que expira). Secreto incorrecto → **401**.

## Resumen de qué desbloquea cada tier

| Capacidad | Free | Plus | Pro |
|---|---|---|---|
| Barcos | 1 | 2 | 3 |
| Recordatorios de caducidad de documentos | 1 | ilimitados | ilimitados |
| Mantenimiento programado + cron | ❌ | ✅ | ✅ |
| Readiness completo | solo docs | ✅ | ✅ |
| Alarma de fondeo | ❌ | ✅ | ✅ |
| Fotos por log / galería | 1 / 1 | ∞ / 10 | ∞ / 10 |
| Inteligencia de costes + €/L + anomalías | ❌ | ❌ | ✅ |
| Barco compartido (bookings + splits) | ❌ | ❌ | ✅ |
| Pasaporte PDF | ❌ | ❌ | ✅ |
| Crear grupos/clubes y eventos | ❌ | ❌ | ✅ |
| Compartir barco (ver) + permisos tripulación | ✅ | ✅ | ✅ |

Precios: Plus 4,99 €/mes · 39,99 €/año · Pro 8,99 €/mes · 69,99 €/año.
