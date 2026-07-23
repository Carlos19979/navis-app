# Navis — Plan de monetización, tiers y crecimiento

> **Estado:** propuesta estratégica (2026-07-23). Contrastada contra el código real
> (`apps/api/internal/domain/profile.go`, `docs/payments-setup.md`, `docs/features.md`,
> `CLAUDE.md`). Objetivo del dueño: poder **vivir del proyecto** (~4.000 €/mes netos).
>
> **Tesis en una frase:** Navis NO es una app de suscripción para particulares con un
> anexo B2B. Es **un SaaS náutico B2B (charter/clubs/flotas) con una app de consumo
> gratuita de captación encima**. Mismo código, mismas features — pero el dinero de
> "vivir de esto" entra por el carril Fleet, y el particular llena el embudo y genera
> los datos que alimentan la tercera pata (partnerships).

---

## 0. Punto de partida (lo que YA está construido)

La app ya implementa **3 tiers server-enforced** (HTTP 402), con webhook de RevenueCat
que escribe `profiles.plan ∈ free|plus|pro`. Gating centralizado en
`domain/profile.go` (`Plan.atLeast`) → `Entitlements` DTO → `Account` (Flutter) →
`PlanTier` en `billing.dart` → `showPaywall`.

Mapa actual (fuente: `profile.go`):

| Capacidad | Método | Free | Plus | Pro |
|---|---|---|---|---|
| Barcos | `MaxBoats` | 1 | 2 | 5 |
| Recordatorios caducidad docs | `ReminderDocLimit` | 1 | ∞ | ∞ |
| Adjuntos por documento | `AttachmentLimit` | 1 | ∞ | ∞ |
| Galería de fotos del barco | `GalleryLimit` | 1 | 10 | 10 |
| Mantenimiento programado + cron | `CanUseMaintenanceSchedules` | ❌ | ✅ | ✅ |
| Readiness completo | `CanUseFullReadiness` | solo docs | ✅ | ✅ |
| Alarma de fondeo | `CanUseAnchorAlarm` | ❌ | ✅ | ✅ |
| Inteligencia de costes + €/L | `CanUseCostAnalytics` | ❌ | ❌ | ✅ |
| Alertas de anomalías | `CanUseAnomalyAlerts` | ❌ | ❌ | ✅ |
| Coordinación compartida (reservas + splits) | `CanUseSharedCoordination` | ❌ | ❌ | ✅ |
| Pasaporte PDF | `CanExportPassport` | ❌ | ❌ | ✅ |
| Crear clubs/grupos + eventos | `CanCreateGroups` | ❌ | ❌ | ✅ |
| Ver barco compartido + permisos de tripulación | (RLS/HasAccess) | ✅ | ✅ | ✅ |

Precios actuales: **Plus** 4,99 €/mes · 39,99 €/año · **Pro** 8,99 €/mes · 69,99 €/año.
"Fleet" (B2B) está marcado como *future work* en el código y no existe todavía.

**Veredicto:** el diseño ya es bueno. Ya gatea por *valor* y no por número de barcos
(mi principal recomendación estratégica ya está hecha). Los cambios de abajo son
**quirúrgicos**, no una reescritura.

### 0.1 ⚠️ Bugs/riesgos ya detectados en el código (arreglar antes de tocar precios)

1. **CRÍTICO — el tier Plus puede estar roto en base de datos.** La migración
   `00027_plan_free_pro.sql` puso un CHECK que **solo permite `('free','pro')`**, pero el
   código añadió `plus` después (`profile.go`) y **no hay migración que reabra el CHECK**.
   Un intento de escribir `plan='plus'` violaría la constraint. **Acción:** migración
   `00038` (o antes) que amplíe el CHECK a `('free','plus','pro','fleet')`. Verificar en
   `navis-prod` si algún `plus` ha fallado ya.
2. **El webhook "falla hacia Pro".** Si un evento de RevenueCat llega **sin** campos de
   entitlement, `highestTier` concede **Pro** (`webhook_handler.go:133-136`). Es
   deliberado (no perder upgrades), pero es un riesgo de ingresos si cambia el formato del
   payload. Revisar al subir precios.
3. **Dos features se gatean SOLO en cliente** (sin 402 en servidor): **alarma de fondeo**
   y **pasaporte PDF**. Si se mueven de tier, solo la app lo respeta — un cliente
   modificado podría saltárselo. Si alguna vez importan como diferenciador de pago,
   añadir enforcement en servidor.

---

## 1. Las personas y a qué tier pertenece cada una

Esto responde directamente a "desde barcos compartidos hasta flotas hasta un usuario
con solo documentos". Cada persona real de Navis mapea a un carril:

| Persona | Qué quiere | Tier objetivo | Rol en el negocio |
|---|---|---|---|
| **Solo-documentos** | Guardar seguro/ITB/licencias y que le avisen antes de caducar | **Free → Plus** | Entrada más ancha del embudo + **combustible de la pata de partnerships** (seguros) |
| **Dueño casual** | 1 barco, uso ocasional, tranquilidad | **Free → Plus** | Volumen, viralidad |
| **Dueño entusiasta / prosumer** | Analítica, costes, pasaporte PDF, 2-3 barcos | **Pro** | Máximo ingreso por usuario B2C |
| **Copropietarios / barco compartido** | Repartir gastos y reservar turnos entre tripulación | Dueño paga **Pro**; tripulación **Free** | Viralidad (cada tripulante = lead) |
| **Club náutico / comunidad** | Crear club, gestionar socios, eventos/regatas | **Pro** → puente a **Fleet** | Trae a sus socios (B2C) + candidato B2B |
| **Charter / escuela / gestor de flota** | Gestionar N barcos, personal con roles, reservas de clientes, facturar | **Fleet (B2B)** 🆕 | **El motor de "vivir de esto"** |

---

## 2. Cambios en los tiers B2C (feature por feature)

Leyenda: **MANTENER** · **CAMBIAR** · **MOVER** · **NUEVO**.

### 2.1 Número de barcos — CAMBIAR (Pro 5 → 3)
`MaxBoats` Pro pasa de **5 a 3**. Motivo: casi ningún particular real tiene 4-5 barcos;
quien los tiene **es de facto una flota**. Dejar Pro en 5 invita a que un charter pequeño
compre Pro (69,99 €/año) en vez de Fleet → canibalización. Con tope 3 y "ilimitado" solo
en Fleet, cerramos esa fuga con pérdida B2C despreciable.
- Free 1 · Plus 2 · Pro 3 · Fleet ∞.

### 2.2 Recordatorios de caducidad de documentos — MANTENER
Free 1 / Plus+ ∞. Es el **gancho anti-multa** y está perfectamente colocado: es la razón
nº 1 por la que el "solo-documentos" pasa de Free a Plus. No tocar.

### 2.3 Mantenimiento programado, readiness completo, alarma de fondeo — MANTENER
Todos en Plus+. Correcto: son valor de "dueño responsable" y seguridad (apela a todos),
buenos motores de conversión a Plus.

### 2.4 Split de gastos básico — MOVER (Pro → Free/Plus) ⚠️ el cambio más importante de B2C
**Problema detectado:** `features.md` dice que el split debe "traer a la tripulación
gratis", pero `CanUseSharedCoordination` lo tiene **entero detrás de Pro**. Resultado: la
feature más viral de la app está apagada para el 99% de usuarios.

**Propuesta:** partir la coordinación compartida en dos capacidades:
- `CanUseBasicSplit()` → **Free y Plus**: dividir un gasto entre tripulantes y ver quién
  debe qué. Es el mecanismo viral (cada tripulante invitado = usuario nuevo → futuro dueño).
- `CanUseSharedCoordination()` → **Pro** (se mantiene): calendario de **reservas**,
  seguimiento de **liquidación** (`settled_at`), resúmenes por barco. La coordinación
  "seria" sigue siendo de pago.

Coste: erosiona un poco el valor de Pro. Beneficio: enciende el canal de crecimiento
orgánico más barato que tienes. **El trade-off vale la pena** — la viralidad pesa más que
los pocos € de Pro que se mueven.

> **Es de bajo esfuerzo:** el registro *crudo* de gastos (`expenses`) ya está **sin
> gatear** (vive en `maintenance_service`, sin 402). Lo único detrás de Pro es la acción
> de **dividir** (`shared_service.go:35-44`, `assertPro` → `CanUseSharedCoordination`).
> Basta con separar `SetSplits`/`ListSplits` (básico, Free+) de bookings + `SettleSplit` +
> summaries (Pro). No hay que tocar el modelo de datos.

### 2.5 Inteligencia de costes, anomalías, pasaporte PDF — MANTENER (Pro)
Valor claro de prosumer. No tocar.

### 2.6 Crear clubs/grupos + eventos — MANTENER (Pro), marcar como puente a Fleet
El dueño de un club es un power user que paga Pro y **trae a sus socios**. Pero un club/
marina que quiere gestionar socios de forma "operativa" es un **Fleet-lite**: usar la
creación de clubs como señal de venta para subir a Fleet.

### 2.7 Compartir barco / tripulación (ver) — MANTENER (todos los tiers)
Es la base viral. La tripulación entra gratis; el dueño paga. No tocar.

### Tabla B2C propuesta (resultado)

| Capacidad | Free | Plus | Pro |
|---|---|---|---|
| Barcos | 1 | 2 | **3** |
| Recordatorios de caducidad | 1 | ∞ | ∞ |
| Mantenimiento programado + cron | ❌ | ✅ | ✅ |
| Readiness completo | solo docs | ✅ | ✅ |
| Alarma de fondeo | ❌ | ✅ | ✅ |
| **Split de gastos básico** | **✅** | **✅** | ✅ |
| Reservas + liquidación + resúmenes | ❌ | ❌ | ✅ |
| Inteligencia de costes + €/L + anomalías | ❌ | ❌ | ✅ |
| Pasaporte PDF | ❌ | ❌ | ✅ |
| Crear clubs/grupos + eventos | ❌ | ❌ | ✅ |

---

## 3. Precios B2C — ajuste

| Tier | Actual | **Propuesto** | Razón |
|---|---|---|---|
| Free | 0 € | 0 € | — |
| Plus | 4,99 /mes · 39,99 /año | **igual** | Punto de entrada correcto |
| Pro | 8,99 /mes · 69,99 /año | **9,99 /mes · 89,99 /año** | Pro empaqueta MUCHO (costes + reservas + pasaporte + clubs). Está infravalorado. El comprador Pro es entusiasta con baja sensibilidad al precio; subir el anual de 70→90 mueve el LTV y apenas toca la conversión |
| **Fleet** 🆕 | — | **~300-500 €/barco/año** (Stripe, fuera de tiendas, contrato anual, tramos por volumen) | Validado por Floatist (~€480/barco/año) |

**Bug a corregir:** `docs/payments-setup.md` (Paso 2, Google Play) menciona precios
`3,99 € / 29,99 €` que **no coinciden** con el resto (8,99/69,99). Unificar todos los
importes al actualizar.

**Mecánica de cobro (cambios):**
1. **Anual por defecto** en el paywall (con descuento visible). El churn del mensual es
   brutal (~30% cancela el primer mes); el anual lo amortigua y adelanta la caja.
2. **Prueba de Pro de 7-14 días** (probar lo bueno convierte más que mirarlo bloqueado).
3. **Fleet se factura FUERA de las tiendas** (Stripe): sin comisión 15-30% de Apple/Google,
   con factura + IVA B2B + contrato anual. El mismo €480/barco te llega casi íntegro.

> Referencia de neto (España, IVA 21%, Small Business 15%): Pro anual 89,99 € → ≈ 63 €/año
> neto; blended B2C ≈ 4,5 €/mes por pagador. Para 4.000 €/mes en bolsillo (tras autónomo +
> IRPF) ⇒ ~1.350 pagadores B2C **o** ~100-120 barcos en Fleet. El Fleet es el camino corto.

---

## 4. El tier Fleet (B2B) — especificación

Es el único desarrollo **nuevo** de peso. Se apoya en lo que ya existe (`boat_members`
con permisos granulares, grupos con roles, reservas, splits).

### 4.1 Concepto de datos: Organización
Hoy todo cuelga de un `user_id`. Fleet introduce una **organización** que posee barcos y
tiene **personal con roles** (más que la tripulación de un barco suelto).

**Nueva migración `00038_create_organizations.sql`:**
```sql
create table organizations (
  id                     uuid primary key default gen_random_uuid(),
  name                   text not null,
  owner_id               uuid not null references auth.users(id),
  vat_number             text,
  billing_email          text,
  stripe_customer_id     text,
  stripe_subscription_id text,
  plan                   text not null default 'fleet',
  boat_quota             int  not null default 0,   -- barcos contratados (= quantity Stripe)
  status                 text not null default 'active', -- active|past_due|canceled
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create table organization_members (
  org_id   uuid not null references organizations(id) on delete cascade,
  user_id  uuid not null references auth.users(id),
  role     text not null,          -- admin | manager | skipper | mechanic
  status   text not null default 'active',
  primary key (org_id, user_id)
);

alter table boats add column organization_id uuid references organizations(id);
```
- Roles de org reutilizan el patrón `BoatPermissions` ya existente, pero **a nivel de
  flota** (un `manager` gestiona todos los barcos de la org; un `mechanic` solo mantenimiento).

### 4.2 Gating: `PlanFleet` en `domain/profile.go`
```go
const PlanFleet Plan = "fleet"

func (p Plan) rank() int {
    switch p {
    case PlanFleet: return 3   // NUEVO, por encima de Pro
    case PlanPro:   return 2
    case PlanPlus:  return 1
    default:        return 0
    }
}
```
**Cambio crítico y transversal:** hoy muchas capacidades usan `== PlanPro`, lo que
**excluiría a Fleet**. Hay que cambiarlas a `atLeast(PlanPro)` para que Fleet herede
todo lo de Pro:
- `CanCreateGroups`, `CanUseCostAnalytics`, `CanExportPassport`,
  `CanUseSharedCoordination`, `CanUseAnomalyAlerts` → `return p.atLeast(PlanPro)`.
- `MaxBoats`: `PlanFleet → Unlimited` (o `= org.boat_quota`).
- `Valid()` incluye `PlanFleet`.
- Capacidades nuevas Fleet-only: `CanManageStaff()`, `CanUseFleetDashboard()`,
  `CanInvoice()`, `CanManageCustomerBookings()` → `return p == PlanFleet`.

**Plan efectivo del usuario** = `max(plan personal, plan de la org a la que pertenece)`.
Un empleado de un charter obtiene capacidades Fleet **sobre los barcos de su org**.

### 4.3 Facturación: Stripe (fuera de las tiendas)
- Nuevo adapter `internal/adapter/stripe/` + ruta `POST /api/v1/webhooks/stripe`
  (fuera del JWT, mismo patrón de secreto que el webhook de RevenueCat).
- Suscripción Stripe **por asiento = por barco** (`quantity` = `boat_quota`), anual.
- El webhook mapea eventos Stripe → `organizations.plan/status` (reutiliza el patrón
  `SetPlan` existente, pero a nivel de org). `customer.subscription.updated/deleted`,
  `invoice.paid`, `invoice.payment_failed`.
- Portal de cliente de Stripe para que el charter gestione su propia suscripción/factura.

### 4.4 Features Fleet (todo lo de Pro +)
- **Panel de flota**: todos los barcos, estado de documentos/mantenimiento/readiness en una vista.
- **Personal con roles** (admin/manager/skipper/mechanic) sobre toda la flota.
- **Cumplimiento centralizado**: alertas de documentos caducados de TODA la flota (multas evitadas a escala).
- **Reservas de cliente** (capa comercial sobre `bookings`, no solo copropietarios).
- **Facturación con IVA** y export contable.
- Barcos ilimitados (según `boat_quota` contratada).

### 4.5 Flutter
- Añadir `fleet` a `PlanTier` / `effectiveTierProvider` en `billing.dart`.
- Fleet **no** se compra in-app (no paywall RevenueCat): estado "gestionado", CTA
  "Contactar con ventas" / link al portal web. Evita la comisión de tienda y cumple
  las reglas de Apple (B2B fuera de IAP es correcto para software de empresa).

---

## 5. Partnerships (fase futura) — construir para ello HOY, activar con densidad

La tercera pata: cobrar a **proveedores** (seguros, varaderos, tiendas, revisiones) por
poner su oferta delante del usuario correcto en el momento correcto. Tu activo único: ya
sabes **cuándo caduca cada documento** (`documents.expiry` + status computado + tipos:
`insurance_rc`, `insurance_full`, `itb`, `life_raft`, `extinguisher`, `flares`, ...).

| Partner | Disparador (dato que ya tienes) | Modelo | Ingreso aprox. |
|---|---|---|---|
| **Seguros náuticos** ⭐ | Seguro caduca en X días | Comisión de renovación 10-20% de la prima | €30-400 / conversión, **recurrente anual** |
| Varaderos / astilleros | Fin de temporada, invernaje, antifouling | Comisión por reserva / lead | Medio, estacional |
| Tiendas / chandlery | Bengalas/balsa/extintor caducados | Afiliación sobre compra | Bajo-medio, volumen |
| Revisiones de seguridad | Balsa/extintor/ITB próximos | Fee por cita agendada | Medio, recurrente |
| Talleres / mecánicos | Aviso de mantenimiento por horas de motor | Lead cualificado | Medio |

**Las dos reglas innegociables:**
1. **GDPR:** el dato se queda contigo; tú muestras la oferta al usuario; el partner solo
   recibe datos si el usuario **acepta explícitamente**. Nunca vender/compartir la lista.
2. **Confianza:** debe sentirse como un **servicio**, no un anuncio.
   ✅ "Tu seguro caduca en 30 días. ¿Te buscamos 3 ofertas de renovación?"
   ❌ Un banner de aseguradora.

**Qué hacer AHORA (barato, para no bloquearse):**
- Añadir consentimiento de marketing/partners en `profiles` (p. ej. columna
  `partner_consent boolean default false`) capturado en el onboarding.
- Mantener bien estructurado el dato de caducidad (ya lo está: tipo + fecha + status).
- **No** prometer en los Términos "nunca mostraremos ofertas de terceros".

**Cuándo activar:** con **densidad regional** (p. ej. ~2.000 barcos activos con documentos
en una zona). Ningún varadero ni aseguradora firma con 200 usuarios. Es palanca de año 2-3.

---

## 6. Marketing

### 6.1 Posicionamiento
Dejar de vender "gestiona tu barco" (nice-to-have, aburrido). Vender el **miedo concreto**:
> **"Nunca más una multa por un documento caducado. Nunca más una avería por un
> mantenimiento olvidado."**
La gestión bonita es la consecuencia, no el gancho.

### 6.2 Beachhead (una zona, no el mundo)
1. Elegir **una región** con densidad náutica (Baleares o Levante).
2. Vender a mano a **5-10 charters/clubs** (Fleet). ~15-30 clientes B2B = tus 4.000 €.
3. Cada club/charter **mete a sus socios/clientes** en la app → base B2C orgánica gratis.
4. El B2C particular queda como **escaparate y semillero**, no fuente principal.

### 6.3 Canales
- **B2B (prioridad):** outbound directo a charters, escuelas de vela, clubs; asociaciones
  del sector (p. ej. ANEN); ferias náuticas; puerto a puerto.
- **B2C orgánico:** carteles/QR en marinas y clubs partner, grupos/foros náuticos, ASO en
  stores para "cuaderno de bitácora", "mantenimiento barco", "gestión embarcación".
- **NO** publicidad de pago B2C: el CAC no se recupera a 40-90 €/año en un nicho estacional.

### 6.4 Estacionalidad como arma
- **Primavera:** empujar anual (temporada arranca) + Pro trial.
- **Invierno (off-season):** es cuando la gente ordena papeles y hace mantenimiento →
  campaña de renovación de documentos y revisiones (encaja con anti-multa y con partnerships).

### 6.5 Embudo
`Free (gancho docs)` → `Plus (recordatorios/mantenimiento)` → `Pro (entusiasta)`
· carril B2B independiente: `outbound` → `demo` → `Fleet`.

---

## 7. Roadmap / secuencia de ejecución

| Fase | Qué | Esfuerzo | Bloquea a |
|---|---|---|---|
| **0. Lanzar lo que ya hay** | Terminar setup RevenueCat + App Store/Play (config, no código), sandbox test, salir con Free/Plus/Pro | Bajo (config) | Ingresos B2C |
| **0.5 Arreglar bug del CHECK** | Migración que reabra `profiles.plan` a `free/plus/pro/fleet` (§0.1) — **bloquea Plus/Fleet** | Trivial | Todo lo de pago |
| **1. Ajustes quirúrgicos B2C** | Pro 5→3 barcos; `==PlanPro`→`atLeast(PlanPro)`; split básico a Free/Plus (`shared_service`); subir Pro anual a 89,99; corregir bug de precios en `payments-setup.md` | Bajo (código pequeño en `profile.go`, `shared_service.go`, DTO, `billing.dart`) | Viralidad + LTV |
| **2. Construir Fleet** | Migración orgs + `organization_members` + `boats.organization_id`; `PlanFleet` + gating; adapter Stripe + webhook; panel de flota; roles de personal; plan efectivo = max(personal, org) | **Alto** (el proyecto real) | "Vivir de esto" |
| **3. Venta B2B beachhead** | Cerrar 5-10 charters/clubs a mano en 1 región (en paralelo a fase 2) | Comercial | Ingresos estables |
| **4. Preparar partnerships** | Columna `partner_consent`; no bloquear en Términos; estructura de datos de caducidad (ya lista) | Muy bajo | Pata 3 futura |
| **5. Activar partnerships** | Seguros/varaderos con densidad regional | Medio | Año 2-3 |

---

## 8. Resumen de cambios de código concretos

- `apps/api/internal/domain/profile.go`
  - `MaxBoats`: Pro `5 → 3`; añadir `PlanFleet → Unlimited`.
  - Añadir `PlanFleet`, ampliar `rank()`, `Valid()`.
  - `== PlanPro` → `atLeast(PlanPro)` en: `CanCreateGroups`, `CanUseCostAnalytics`,
    `CanExportPassport`, `CanUseSharedCoordination`, `CanUseAnomalyAlerts`.
  - Nuevas: `CanUseBasicSplit()` (Free+), `CanManageStaff()`, `CanUseFleetDashboard()`,
    `CanInvoice()`, `CanManageCustomerBookings()` (Fleet-only).
- `apps/api/internal/service/shared_service.go` (**no** `cost_service`) — el gate del split
  está en `assertPro` (`:35-44`). Separar `SetSplits`/`ListSplits` (básico, Free+) de
  bookings + `SettleSplit` + summaries (Pro). Enforcement actual de las features Pro:
  `cost_service.go:47`, `anomaly_service.go:43`, `shared_service.go:43`, `group_service.go:51`.
- `packages/supabase/migrations/` — **primero** una migración que reabra el CHECK de
  `profiles.plan` a `('free','plus','pro','fleet')` (bug §0.1). **Sin esto, `plus` y
  `fleet` no se pueden ni escribir.**
- `apps/api/internal/handler/webhook_handler.go` — sin cambios funcionales (RevenueCat
  sigue para Plus/Pro); revisar el "fail-open a Pro" (`:133-136`). **Nuevo**
  `stripe_webhook_handler.go` para Fleet.
- `apps/api/internal/adapter/stripe/` — nuevo adapter + ruta `POST /api/v1/webhooks/stripe`
  (montar fuera del JWT + rate-limit, igual que el de RevenueCat en `router.go:99-100`).
- `internal/domain/organization.go` + repos + servicio + handler (nuevo dominio).
- `packages/supabase/migrations/00039_create_organizations.sql` (+ RLS + índices).
- DTO `Entitlements` (`GET /me`) — exponer capacidades Fleet + plan efectivo de org.
- `apps/mobile/.../billing.dart` — `fleet` en `PlanTier`/`effectiveTierProvider`; sin
  paywall in-app para Fleet (estado gestionado + CTA ventas).
- `docs/payments-setup.md` — corregir precios inconsistentes; documentar Fleet/Stripe.

---

## 9. Gap analysis del Fleet vs. la categoría charter (investigación 2026)

Investigación competitiva del software de gestión de charter/flota (Med/España). La
categoría se organiza en **dos anclas + dos clusters**:

- **Anclas (distribución B2B / "GDS"):** **Booking Manager (MMK)** y **NauSYS** —
  sincronizan la flota en tiempo real a miles de agencias y cientos de webs/marketplaces
  (Click&Boat, SamBoat, Zizoo/Borrow A Boat…). NauSYS: ~9.000 barcos, ~900 flotas, 250+
  webs, **0% comisión** (cobra por paquetes de distribución). Es un **moat de efecto red**.
- **Cluster ops/mantenimiento** (Floatist, Seahub): flota, mantenimiento, inventario,
  documentos con caducidades, check-in/out, app de huésped. **← Navis ya es fuerte aquí.**
- **Cluster comercial/reservas** (AndroNautic, SolNow, Maradigma; españoles): CRM,
  calendario de flota, contratos con firma digital, pagos/depósitos, facturación con IVA.

### Checklist de la categoría × Navis

| Feature (table-stake salvo nota) | Navis |
|---|---|
| Calendario de flota + anti-overbooking | ✅ (validación de solape) |
| **Channel management / distribución OTAs (iCal/API)** | ❌ **gap nº 1** |
| **Contratos + firma digital** (prellenados, incl. menores) | ❌ |
| **Pagos online + depósitos / APA** | ❌ |
| **Facturación con IVA** (+ facturas de comisión de agencia) | ❌ |
| **CRM de clientes** | ❌ |
| Check-in/out + partes de daños/inventario | 🟡 parcial (bitácora, sin flujo check-in) |
| Gestión de mantenimiento de flota | ✅ |
| Documentos con caducidades/compliance | ✅ |
| App para el cliente/huésped | ❌ |
| Tripulación/skippers + renovación de titulaciones | 🟡 parcial |
| Reporting/analytics de negocio | 🟡 parcial (readiness + cost analytics) |
| Multi-empresa + roles + panel de flota | ❌ (= tier Fleet) |
| **Diferenciadores de Navis** (nadie los tiene) | GPS trips, €/L + split, readiness, regatas |

### Lectura estratégica
1. **No ser un GDS.** El moat de distribución de NauSYS/Booking Manager es inatacable a
   corto. **Integrarse** con ellos (iCal/API) más adelante, no reemplazarlos.
2. **El hueco es la fragmentación española:** el **90% de la flota española son empresas
   de <20 barcos**, infra-atendidas por los grandes. Navis = **SaaS asequible, self-serve,
   ops + compliance + comercial ligero** para esa cola larga.
3. **La mitad difícil ya está hecha** (mantenimiento, documentos/compliance, gastos) — lo
   que Floatist/Seahub cobran. Falta la **capa comercial mínima**.

### Fleet MVP por fases
- **Fleet v1** (creíble con pequeños operadores): org + roles + panel de flota +
  **contratos con firma digital** (prellenados, <15 s por QR estilo SolNow) + **pagos +
  depósitos** (Stripe, reutiliza la integración de suscripción) + **facturación con IVA** básica.
- **Fleet v2:** CRM ligero + app de huésped + check-in/out con partes de daños/fianzas.
- **Fleet v3 (moat largo plazo):** channel management vía integración con NauSYS/Booking
  Manager o iCal a Click&Boat/SamBoat/Nautal.

> Requisitos fiscales España a validar para la capa de facturación: **TicketBAI/Verifactu/
> Facturae**, integraciones **Holded/A3/Sage**, IVA náutico, contratos con menores, despacho/
> listas de tripulación con capitanía. (Investigación de dolores de operador en curso.)

### Estado de los ajustes de fase 1 (aplicados en rama `feat/tier-fixes-mobile-launch`)
- ✅ Migración `00038` (CHECK `free/plus/pro`).
- ✅ Split de gastos básico liberado a todos los tiers (bookings siguen Pro).
- ✅ Pro 5 → **3 barcos** (`profile.go` + `billing.dart` + tests + docs).
- ✅ Corrección de precio inconsistente en `payments-setup.md`.
- ⏸️ Refactor `atLeast(PlanPro)` → diferido a la fase Fleet (junto con `PlanFleet`).

---

### Apéndice — inventario de features por dominio (referencia)
Barcos (+galería, share_code) · Documentos (11 tipos + status computado + recordatorios)
· Bitácora/Trips (GPS PostGIS, checklist, participantes, share público) · Mantenimiento
(logs + tasks recurrentes por meses/horas + fotos + cron due) · Costes (gastos, €/L,
splits, liquidación, analytics, anomalías) · Reservas (overlap validado por API) ·
Grupos/Clubs (roles owner/member, público/privado, invite code) · Eventos/Regatas (+RSVP,
stream urls) · Readiness (docs+seguridad+motor) · Weather (Open-Meteo) · Ports · Anchor
watch (client-only) · Passport PDF (client-side) · Notificaciones (5 workflows Novu:
regatta-updates, group-updates, boat-activity, reminders, event-live → FCM + Resend).
