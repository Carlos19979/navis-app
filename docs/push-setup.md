# Navis — Guía de configuración de push (APNs + Firebase + Novu)

El **código de push ya está implementado**: la app registra el token FCM contra
`POST /api/v1/devices`, el handler crea el subscriber en Novu y le cuelga el token,
y el `Notifier` dispara las 5 workflows con `{title, body, type, id}` en el payload.
Esta guía cubre lo que falta, que es casi todo **configuración externa** (Apple,
Firebase, Novu, Railway) más **dos ficheros de credenciales que no van al repo**.

> ⚠️ **Sin estos pasos el push no falla: desaparece en silencio.** Sin
> `GoogleService-Info.plist` / `google-services.json`, `Firebase.initializeApp()`
> degrada con try/catch y `getToken()` devuelve `null`. Sin la key APNs en
> Firebase, Novu acepta el trigger con 201 y el device nunca recibe nada.

## Qué ya está en el repo (no hay que tocarlo)

| Qué | Dónde |
|---|---|
| Capacidad Push de iOS (`aps-environment`) | `apps/mobile/ios/Runner/Runner.entitlements`, cableado con `CODE_SIGN_ENTITLEMENTS` en Debug/Release/Profile |
| Bundle del plist de Firebase (iOS) | fase `Bundle Firebase Config` del target Runner: copia `ios/Runner/GoogleService-Info.plist` al `.app` **si existe**; si no, avisa y sigue |
| Plugin Google Services (Android) | `android/app/build.gradle.kts` lo aplica solo `if (file("google-services.json").exists())`; declarado en `android/settings.gradle.kts` (4.4.4) |
| Permiso `POST_NOTIFICATIONS` (Android 13+) | `android/app/src/main/AndroidManifest.xml` |
| `remote-notification` en `UIBackgroundModes` | `ios/Runner/Info.plist` |
| Registro de token + subscriber en Novu | `apps/api/internal/handler/device_handler.go` (`EnsureSubscriber` + `SetPushToken`, `providerId: "fcm"`) |
| Deep link al tocar la notificación | `notification_provider.dart` → `_handlePayload({type, id})` |

## Valores exactos que el código ya espera (no los cambies)

| Qué | Valor | Dónde está en el código |
|---|---|---|
| 🔒 Bundle ID iOS | **`com.navis.navisMobile`** | `PRODUCT_BUNDLE_IDENTIFIER` en `ios/Runner.xcodeproj/project.pbxproj` |
| 🔒 Package name Android | **`com.navis.navis_mobile`** | `applicationId`/`namespace` en `android/app/build.gradle.kts` |
| Apple Team ID | **`8TF3JSZXAP`** | `DEVELOPMENT_TEAM` en el pbxproj |
| 🔒 Proyecto Firebase | **`navis-44c8b`** | — (lo consume el plist / json) |
| 🔒 Ruta del plist iOS | `apps/mobile/ios/Runner/GoogleService-Info.plist` | fase `Bundle Firebase Config` |
| 🔒 Ruta del json Android | `apps/mobile/android/app/google-services.json` | `if (file(...).exists())` en `app/build.gradle.kts` |
| 🔒 Provider de push en Novu | **`fcm`** | `novu.Client.SetPushToken` |
| 🔒 Subscriber ID en Novu | = **Supabase `user_id`** | `device_handler.go` (`userID`) |
| 🔒 IDs de las 5 workflows | `reminders`, `regatta-updates`, `group-updates`, `boat-activity`, `event-live` | bloque `const` en `apps/api/internal/service/notifier.go` |
| 🔒 Campos del payload | `title`, `body`, `type`, `id` | `Notifier.TrySend` |
| 🔒 Valores de `type` que rutan | `document`, `regatta`, `group`, `event`, `trip`, `boat` | `_handlePayload` en `notification_provider.dart` |

Los dos ficheros de credenciales (`GoogleService-Info.plist`, `google-services.json`)
están en `.gitignore` **a propósito** y no deben commitearse nunca.

---

## Paso 1 — Apple Developer (APNs)

Todo en [developer.apple.com](https://developer.apple.com/account) con la cuenta del
team `8TF3JSZXAP`.

1. **Activa la capacidad Push en el App ID.** *Certificates, Identifiers & Profiles →
   Identifiers →* App ID **`com.navis.navisMobile`** → marca **Push Notifications** →
   *Save*. Sin esto, la firma automática de Xcode falla en cuanto lea el
   `Runner.entitlements` que ya está en el repo (`Provisioning profile doesn't include
   the aps-environment entitlement`).
2. **Regenera el provisioning profile.** Si usas *Automatically manage signing* (es el
   caso: `CODE_SIGN_STYLE` no está forzado a Manual), basta abrir
   `apps/mobile/ios/Runner.xcworkspace` en Xcode una vez y dejar que refresque el
   perfil. Si los perfiles son manuales, regenéralos a mano y vuelve a descargarlos.
3. **Crea la key APNs `.p8`.** *Keys → +* → nombre `Navis APNs` → marca **Apple Push
   Notifications service (APNs)** → *Continue → Register → Download*.
   - Apunta el **Key ID** (10 caracteres) que aparece en la ficha.
   - Apunta el **Team ID**: `8TF3JSZXAP`.
   - ⚠️ El `.p8` **se descarga una sola vez**. Guárdalo en un gestor de secretos, no
     en el repo (`*.p8` cae bajo el `*.key`/`*.pem` del `.gitignore`, pero no lo pongas
     ahí de todos modos).

Una key APNs sirve para development y production a la vez: no hace falta certificado
por entorno.

## Paso 2 — Firebase (proyecto `navis-44c8b`)

En [console.firebase.google.com](https://console.firebase.google.com) → proyecto
**`navis-44c8b`**. Firebase se usa **solo como transporte FCM**: no actives Auth,
Firestore ni Analytics.

1. **Registra la app iOS.** *Project settings → General → Your apps → Add app → iOS*:
   - Bundle ID: **`com.navis.navisMobile`** (exacto, respeta la mayúscula de `navisMobile`).
   - Apodo: `Navis iOS`. App Store ID: se puede dejar vacío.
   - Descarga **`GoogleService-Info.plist`** y colócalo en
     **`apps/mobile/ios/Runner/GoogleService-Info.plist`**.
   - **No hay que arrastrarlo a Xcode.** La fase de build `Bundle Firebase Config` lo
     mete en el `.app` sola. Si lo añades como recurso del proyecto, rompes el build
     de todo el mundo que no tenga el fichero.
2. **Sube la key APNs.** *Project settings → Cloud Messaging → Apple app configuration
   → APNs Authentication Key → Upload*:
   - Fichero: el `.p8` del paso 1.
   - **Key ID**: el del paso 1.
   - **Team ID**: `8TF3JSZXAP`.
   - Sin esta subida FCM no puede hablar con APNs y **todo push a iOS se pierde sin
     error visible**.
3. **Registra la app Android.** *Add app → Android*:
   - Package name: **`com.navis.navis_mobile`**.
   - SHA-1: **no hace falta** para FCM (solo lo piden Auth/Dynamic Links).
   - Descarga **`google-services.json`** y colócalo en
     **`apps/mobile/android/app/google-services.json`**. El plugin se aplica solo en
     cuanto el fichero existe.
4. **Genera el service-account JSON para Novu.** *Project settings → Service accounts →
   Generate new private key* → descarga el JSON. Es la credencial que Novu usa para
   llamar a la API HTTP v1 de FCM. Guárdala fuera del repo
   (`firebase-service-account.json` ya está en `.gitignore`).

## Paso 3 — Novu (integración FCM + workflows)

En [dashboard.novu.co](https://dashboard.novu.co). Hazlo **en los dos entornos**
(Development y Production): cada uno tiene su propia API key y sus propias workflows.

1. **Integración FCM.** *Integrations → Add a provider → Firebase Cloud Messaging*:
   - Pega el contenido del **service-account JSON** del paso 2.4.
   - Deja el `providerId` en **`fcm`** (es el que envía `novu.Client.SetPushToken`).
   - Marca la integración como **Active** y como primaria del canal Push.
2. **Integración Resend** (email, ya documentada en `CLAUDE.md`): API key de Resend,
   remitente `Navis <notifications@aerolume.app>`.
3. **Las 5 workflows.** Crea/activa una por dominio, con el **identifier exacto**:
   `reminders`, `regatta-updates`, `group-updates`, `boat-activity`, `event-live`.
   Si el identifier no coincide, Novu responde 201 y descarta el trigger.
   Pasos de cada workflow: **Push (FCM) → Email (Resend)**.
4. **Configura el paso Push de cada workflow así** (idéntico en las cinco: la entrega
   es genérica, cada trigger trae su propio texto y su propio deep link):

   | Campo del paso Push | Valor |
   |---|---|
   | Title / Subject | `{{payload.title}}` |
   | Content / Body | `{{payload.body}}` |
   | **Data / Custom data → `type`** | `{{payload.type}}` |
   | **Data / Custom data → `id`** | `{{payload.id}}` |

   ⚠️ **`type` e `id` tienen que ir como *data fields*, no en el cuerpo del mensaje.**
   Llegan a Flutter en `RemoteMessage.data` y son lo único que `_handlePayload` usa
   para navegar (`/documents/<id>`, `/regattas/<id>`, `/groups/<id>`, `/events/<id>`,
   `/trips/<id>`, `/boats/<id>`). Si faltan, la notificación se ve pero al tocarla no
   pasa nada.
5. **Activa (publica) las 5 workflows.** Una workflow en borrador no dispara.

## Paso 4 — Railway (API de producción)

1. Copia la **API key del entorno Production** de Novu (*Settings → API keys*).
2. En el proyecto de Railway → servicio de la API → *Variables* → define
   **`NOVU_API_KEY`** con ese valor y redeploy.
   - Con `NOVU_API_KEY` vacío el cliente Novu entra en **dry-run**: loguea el trigger
     y devuelve `nil`. Es decir, la API arranca igual, el feed de la campanita se
     rellena, y **no sale ni un push**. Es el fallo más fácil de no notar.
3. No hay ninguna otra variable de push: el resto (APNs, FCM) vive en los dashboards.

---

## Verificación

### 1. El build lleva la configuración (iOS)

```bash
cd apps/mobile
flutter build ios --debug --no-codesign
# En el log NO debe aparecer:
#   warning: ios/Runner/GoogleService-Info.plist is missing - FCM push stays inactive
/usr/libexec/PlistBuddy -c 'Print :aps-environment' ios/Runner/Runner.entitlements
# → development
```

Y con la app compilada, comprueba que el plist viaja dentro del bundle:

```bash
find build/ios -name 'GoogleService-Info.plist' -path '*Runner.app*'
```

### 2. El device obtiene token y lo registra

Corre la app en un **dispositivo físico** (el simulador de iOS no da tokens APNs
reales), inicia sesión y mira los logs:

```bash
flutter run --debug   # o make mobile-run
```

- Debe aparecer el diálogo de permiso de notificaciones.
- **NO** debe aparecer `notifications: Firebase unavailable: [core/no-app]`. Si
  aparece, falta el plist / el json.
- La app debe hacer `POST /api/v1/devices` con `{token, platform}` y recibir **201**.
  En los logs de la API (Railway o local) verás la petición; en Novu, *Subscribers →*
  el subscriber con tu `user_id` debe tener el **token FCM** en sus credenciales.

En Android, si el token no llega, revisa además que el permiso `POST_NOTIFICATIONS`
esté concedido (Android 13+ lo pide en runtime).

### 3. Un trigger de prueba llega al device

Opción A — desde Novu (la más rápida, no toca producción de datos):
*Workflows → `reminders` → Test workflow*, con el subscriber = tu `user_id` de
Supabase y este payload:

```json
{
  "title": "Prueba de push",
  "body": "Si ves esto, APNs/FCM y Novu estan bien",
  "type": "boat",
  "id": "<un-uuid-de-barco-tuyo>"
}
```

Debe ocurrir todo esto:
1. La notificación aparece en el device (con la app en background).
2. Al tocarla, la app abre `/boats/<id>` — eso prueba que `type` e `id` viajan como
   data fields.
3. En *Activity Feed* de Novu el paso Push sale **Sent**, no *Failed*.

Opción B — end to end por la API: crea un documento con caducidad dentro de los
`alert_days` y espera el cron (08:00 UTC), o dispara cualquier acción que notifique
(por ejemplo un split de gasto en un barco compartido, workflow `boat-activity`).

### Errores típicos y qué significan

| Síntoma | Causa |
|---|---|
| `getToken()` devuelve `null` en iOS, sin error | falta `aps-environment` (ya resuelto en el repo) **o** la capacidad Push no está activada en el App ID → no hay token APNs |
| Xcode: `Provisioning profile doesn't include the aps-environment entitlement` | paso 1.1/1.2: activa Push en el App ID y refresca el perfil |
| `[core/no-app]` en los logs | falta `GoogleService-Info.plist` / `google-services.json` |
| Novu marca el push **Sent** pero el device no recibe nada | falta la key APNs en Firebase → Cloud Messaging (paso 2.2) |
| Novu marca el paso Push **Failed: no push credentials** | el subscriber no tiene token: la app no llegó a hacer `POST /devices` |
| La API loguea `novu: dry-run trigger` | `NOVU_API_KEY` sin definir (paso 4) |
| Llega la notificación pero al tocarla no navega | el paso Push no reenvía `type`/`id` como data fields (paso 3.4) |
| Nada llega y Novu no registra actividad | el identifier de la workflow no coincide, o está en borrador |

---

## Pendientes conocidos (no bloquean el push)

- **`aps-environment` en release.** El fichero dice `development` a propósito: la
  firma automática de Xcode lo reescribe a `production` al exportar un archive de
  App Store/TestFlight. Si algún día se pasa a firma **manual**, hay que crear un
  segundo entitlements con `production` y apuntar ahí `CODE_SIGN_ENTITLEMENTS` en la
  configuración Release.
- **`_handleNotificationTap` en `main.dart`** solo mira `document_id`, que el backend
  ya no manda (manda `{type, id}`). Es inofensivo — el deep link real lo resuelve
  `notification_provider.dart`, que sí lee `{type, id}` y también cubre el arranque
  en frío — pero conviene limpiarlo para no dejar dos rutas de deep link.
- **iOS Critical Alerts** (para la alarma de fondeo) siguen fuera: requieren un
  entitlement aparte aprobado por Apple.
