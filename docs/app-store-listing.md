# App Store — ficha de Navis (borrador para pegar)

> Copy listo para App Store Connect, en las dos localizaciones que la app soporta:
> **Español (es-ES)** como principal y **English (en-US)**. Basado en el
> posicionamiento de `marketing-plan.md` (vender el dolor, no la gestión) y el
> inventario real de features (`monetization-plan.md` §apéndice).
>
> ⚠️ Los límites de caracteres de Apple están anotados en cada campo. Los conté a
> ojo; App Store Connect los valida al pegar — recorta si te avisa.
> 🔗 Donde pone `<api>` va el dominio público de la API (Railway) cuando exista.

---

## Datos generales (comunes a los dos idiomas)

| Campo | Valor propuesto | Nota |
|---|---|---|
| Bundle ID 🔒 | `com.navis.navisMobile` | El que ya estaba en el proyecto Xcode/registrado. **App creada** (2026-07-24), Apple ID `6794321904`. |
| Nombre en la tienda | `Navis - Gestión náutica` | "Navis" a secas estaba cogido; bajo el icono sigue siendo "Navis". |
| Categoría principal | **Navigation** | Máxima intención náutica en ASO. Alternativa: Lifestyle. |
| Categoría secundaria | **Lifestyle** | |
| Clasificación por edad | **4+** | Sin contenido sensible. |
| Precio de la app | **Gratis** (con compras dentro) | El modelo es freemium Free/Plus/Pro. |
| Privacy Policy URL 🔒 | `https://<api>/legal/privacy` | Ya renderiza (verificado en tests). |
| Support URL 🔒 | `https://<api>/support` | ✅ Página propia (contacto + FAQs), verificada en tests. |
| Marketing URL | *(opcional)* | |
| Copyright | `2026 Carlos Pérez Martínez` | |

---

## Compras dentro de la app (In-App Purchases) — textos de revisión

Apple pide nombre visible + descripción por producto. Deben coincidir con los IDs que
el código espera (`navis_plus_*` / `navis_pro_*`).

| Product ID | Display Name (ES) | Descripción de revisión (ES) |
|---|---|---|
| `navis_plus_monthly` | Navis Plus (mensual) | Recordatorios ilimitados, mantenimiento programado, alarma de fondeo y galeria de fotos del barco. |
| `navis_plus_yearly` | Navis Plus (anual) | Plan Plus con facturación anual (2 meses gratis). |
| `navis_pro_monthly` | Navis Pro (mensual) | Todo lo de Plus + coste por milla, reservas compartidas, pasaporte PDF y clubes. |
| `navis_pro_yearly` | Navis Pro (anual) | Plan Pro con facturación anual (2 meses gratis). |

---

# 🇪🇸 Español (es-ES) — localización principal

### Nombre (≤30 car.)
```
Navis: tu barco bajo control
```

### Subtítulo (≤30 car.)
```
Docs, mantenimiento y gastos
```

### Texto promocional (≤170 car., editable sin revisión)
```
Nunca más una multa por un documento caducado ni una avería por un mantenimiento olvidado. Navis te avisa a tiempo y lleva tu barco al día.
```

### Palabras clave (≤100 car., separadas por comas SIN espacios)
```
barco,nautica,mantenimiento,bitacora,documentos,seguro,ITB,gastos,tripulacion,vela,motor,regata
```

### Descripción (≤4000 car.)
```
Tu barco genera papeleo, mantenimiento y gastos. Navis lo pone todo bajo control desde el móvil, para que navegues tranquilo.

NUNCA MÁS UNA MULTA POR UN DOCUMENTO CADUCADO
Guarda el seguro, la ITB, la titulación, las bengalas y todo lo que caduca. Navis calcula el estado de cada documento y te avisa antes de que expire.

NUNCA MÁS UNA AVERÍA POR UN MANTENIMIENTO OLVIDADO
Programa las tareas por meses o por horas de motor. Navis te recuerda el cambio de aceite, el ánodo o la revisión antes de que sea un problema, y guardas cada intervención con fotos.

SABE LO QUE TE CUESTA DE VERDAD
Registra gastos, combustible y consumo en €/litro. Descubre cuánto te cuesta cada milla y detecta gastos fuera de lo normal.

DIVIDE LOS GASTOS DEL FINDE (GRATIS)
¿Barco compartido o tripulación? Reparte los gastos y liquida cuentas sin hojas de cálculo. Sin coste.

TU BITÁCORA, CON GPS
Graba tus travesías con GPS, revisa la ruta en el mapa, tu velocidad y la distancia, y comparte la salida con quien quieras.

TODO LO DEMÁS
· Puerto, meteorología marina y estado de "listo para zarpar" de un vistazo
· Clubs, grupos y regatas con inscripciones
· Alarma de fondeo (garreo) para dormir tranquilo
· Tu año navegado en un pasaporte PDF

PLANES
Navis es gratis para empezar: documentos, tu barco y el registro de viajes no cuestan nada. Navis gestiona un barco por cuenta en todos los planes.
· Plus (4,99 €/mes · 39,99 €/año): recordatorios ilimitados, mantenimiento programado, alarma de fondeo y galería de fotos.
· Pro (8,99 €/mes · 69,99 €/año): coste por milla, reservas compartidas, pasaporte PDF y clubes.

Las suscripciones se renuevan automáticamente salvo que las canceles al menos 24 h antes del fin del período, desde los ajustes de tu cuenta de App Store.

Privacidad: https://<api>/legal/privacy
Términos: https://<api>/legal/terms
```

### Novedades / "What's New" (≤4000 car.)
```
· Nuevos planes Plus y Pro: elige justo lo que necesitas.
· El reparto de gastos ahora es gratis para todos.
· Más avisos: reservas, gastos liquidados, actividad de tu tripulación y de tus grupos.
· Alarma de fondeo para vigilar el garreo.
· Consumo en €/litro en tus gastos de combustible.
· Gestiona tu suscripción desde tu perfil.
```

---

# 🇬🇧 English (en-US)

### Name (≤30 chars)
```
Navis: your boat, sorted
```

### Subtitle (≤30 chars)
```
Docs, maintenance & costs
```

### Promotional text (≤170 chars)
```
No more fines for an expired document or breakdowns from skipped maintenance. Navis warns you in time and keeps your boat up to date.
```

### Keywords (≤100 chars, comma-separated, NO spaces)
```
boat,sailing,maintenance,logbook,documents,insurance,expenses,crew,yacht,anchor,regatta,skipper
```

### Description (≤4000 chars)
```
Your boat means paperwork, maintenance and costs. Navis puts all of it under control from your phone, so you can just go sailing.

NEVER A FINE FOR AN EXPIRED DOCUMENT
Store your insurance, safety inspection, licence, flares and everything with an expiry date. Navis tracks the status of each document and warns you before it expires.

NEVER A BREAKDOWN FROM SKIPPED MAINTENANCE
Schedule tasks by month or by engine hours. Navis reminds you about the oil change, the anode or the service before it becomes a problem, and you log every job with photos.

KNOW WHAT IT REALLY COSTS
Track expenses, fuel and consumption in €/litre. See what every mile costs you and spot spending that is out of the ordinary.

SPLIT THE WEEKEND'S COSTS (FREE)
Shared boat or crew? Split expenses and settle up without spreadsheets. Free of charge.

YOUR LOGBOOK, WITH GPS
Record your trips with GPS, review the route on the map, your speed and distance, and share the outing with anyone.

EVERYTHING ELSE
· Harbour, marine weather and a ready-to-sail readiness score at a glance
· Clubs, groups and regattas with sign-ups
· Anchor watch (drift alarm) so you can sleep easy
· Your sailing year in a PDF passport

PLANS
Navis is free to start: documents, your boat and the logbook cost nothing. Navis manages one boat per account on every plan.
· Plus (€4.99/mo · €39.99/yr): unlimited reminders, scheduled maintenance, anchor watch and a boat photo gallery.
· Pro (€8.99/mo · €69.99/yr): cost per mile, shared bookings, PDF passport and clubs.

Subscriptions renew automatically unless cancelled at least 24h before the end of the period, from your App Store account settings.

Privacy: https://<api>/legal/privacy
Terms: https://<api>/legal/terms
```

### What's New (≤4000 chars)
```
· New Plus and Pro plans: pick exactly what you need.
· Expense splitting is now free for everyone.
· More alerts: bookings, settled expenses, crew and group activity.
· Anchor watch to catch a dragging anchor.
· Fuel expenses now show €/litre.
· Manage your subscription from your profile.
```

---

## App Privacy — nutrition labels (para el cuestionario de App Store Connect)

Rellena "App Privacy" con esto (nada se usa para *tracking* ni publicidad):

| Tipo de dato | Se recoge | Uso | Vinculado al usuario |
|---|---|---|---|
| Email / datos de contacto | Sí | Funcionalidad de la app (cuenta) | Sí |
| Ubicación precisa | Sí | Funcionalidad (grabación GPS de travesías) | Sí |
| Contenido del usuario (fotos, documentos) | Sí | Funcionalidad | Sí |
| Compras | Sí | Funcionalidad (gestión de suscripción) | Sí |
| Diagnósticos / fallos | Sí | Diagnóstico de errores (Sentry) | No |

- **Tracking:** No.
- Cuenta la **eliminación de cuenta** (in-app, Ajustes → Cuenta) en el flujo requerido por Apple.

---

## Notas para la revisión de Apple (App Review notes)

```
Cuenta de prueba (sandbox): <email tester> / <password>
Para probar el paywall: con un usuario Free, pulsa "añadir 2º barco" o "crear grupo".
La compra en sandbox desbloquea el plan al instante (entitlement de RevenueCat).
El reparto de gastos es gratuito en todos los planes.
Eliminación de cuenta: Perfil → Ajustes → Cuenta → Eliminar cuenta (borrado real e inmediato).
Sign in with Apple está disponible en la pantalla de acceso.
```

---

## Plan de capturas (screenshots)

Mínimo para iPhone: **6.7"** (1290×2796). Recomendado también 6.5" y 5.5". Si publicas
para iPad, añade 12.9". Orden y caption sugeridos (vende el dolor primero):

1. **Documentos con avisos** — "Nunca más una multa por un documento caducado."
2. **Mantenimiento programado** — "Sabe cuándo toca el próximo servicio."
3. **Costes / €por milla** — "Cuánto te cuesta de verdad tu barco."
4. **Reparto de gastos** — "Divide los gastos del finde. Gratis."
5. **Bitácora con mapa GPS** — "Cada travesía, grabada."
6. **Readiness / listo para zarpar** — "¿Listo para salir? De un vistazo."
7. *(opcional)* **Alarma de fondeo** — "Duerme tranquilo al ancla."

> Captúralas con datos realistas (no lorem), en claro y coherentes con la identidad
> náutica-cristal de la app. Genera el mismo set en ES y EN.
