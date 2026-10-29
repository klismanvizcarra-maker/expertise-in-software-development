---
name: payments-stripe
description: Integra cobros con Stripe en apps web (Express + Angular) - suscripciones y pagos únicos con Stripe Checkout alojado, portal de cliente, webhooks con firma verificada e idempotencia, sincronización de suscripciones en PostgreSQL, control de acceso por plan y pruebas en modo test con Stripe CLI. Usar al añadir planes, paywalls, checkout, facturación o suscripciones, o al depurar webhooks de Stripe. No usar para definir precios o el modelo de negocio (product-manager-agent).
---

# Pagos con Stripe

Stripe es la única fuente de verdad del dinero; tu base de datos es un espejo sincronizado **exclusivamente mediante webhooks**. Verificado con `stripe` 23 (API `2026-09-30.endive`) y Express 5.

## Protocolo

1. **Modelado y Persistencia**: verifica o crea las tablas `billing_customers`, `subscriptions` y `stripe_events` con `database-architect-agent`.
2. **Definición de Precios en Servidor**: registra los IDs de precio (`price_...`) en variables de entorno seguras (`.env`). Asocia cada ID a una clave semántica interna (`"pro_monthly"`).
3. **Endpoints de Sesión**: implementa `POST /api/v1/billing/checkout` (con clave de idempotencia) y `POST /api/v1/billing/portal` para autogestión de clientes.
4. **Endpoint de Webhook Seguro**: monta `POST /api/v1/webhooks/stripe` con parser crudo (`express.raw`), validación estricta de firma criptográfica y registro idempotente en `stripe_events`.
5. **Control de Acceso en Dominio**: define las reglas de acceso en `packages/shared/src/domain/entitlements.ts` y protege rutas en la API mediante middleware (`requirePlan`).
6. **Pruebas y Simulación Local**: prueba los eventos con Stripe CLI (`stripe listen --forward-to`), valida tarjetas de prueba de error/3DS y ejecuta la suite de tests unitarios del webhook.
7. **Checklist y Entrega**: completa el checklist antes de ejecutar `task.sh handoff TASK-XXX`.

---

## Decisiones del Sistema
- **Stripe Checkout alojado** para cobrar y **Customer Portal** para que el cliente gestione tarjeta, plan y cancelación. No se construyen formularios de tarjeta propios (alcance PCI mínimo).
- **Webhooks como única fuente de estado**: la redirección a `success_url` solo muestra un "procesando"; nunca activa un plan.
- **Precios en el servidor**: el cliente envía una clave de plan (`"pro_monthly"`); la API la traduce a un `price_id` de una lista permitida en variables de entorno. Nunca aceptar importes ni `price_id` del cliente.

## Modelo de Datos (Drizzle, `database-architect-agent`)

| Tabla | Columnas clave |
| :--- | :--- |
| `billing_customers` | `userId` (único, FK), `stripeCustomerId` (único) |
| `subscriptions` | `stripeSubscriptionId` (único), `userId`, `status`, `priceId`, `currentPeriodEnd` (`timestamptz`), `cancelAtPeriodEnd` |
| `stripe_events` | `eventId` (PK), `type`, `processedAt` → idempotencia de webhooks |

## Endpoints (`backend-agent`)

| Endpoint | Qué hace |
| :--- | :--- |
| `POST /api/v1/billing/checkout` | Requiere auth. Obtiene o crea el `customer` del usuario, crea la sesión con `mode: 'subscription'` (o `'payment'`), `client_reference_id: userId` e `idempotencyKey`, y devuelve `{ url }`. |
| `POST /api/v1/billing/portal` | Requiere auth. Crea una sesión de `billingPortal` y devuelve `{ url }`. |
| `POST /api/v1/webhooks/stripe` | Sin auth de usuario; autenticado por la firma de Stripe. |

```ts
// Stripe 23: payment_method_types ya NO existe en checkout.sessions.create.
// Los métodos de pago se activan en el Dashboard (o allowed_payment_method_types si hay que restringir).
const session = await stripe.checkout.sessions.create({
  mode: 'subscription',
  customer: customerId,
  line_items: [{ price: PRICES[planKey], quantity: 1 }],
  client_reference_id: userId,
  success_url: `${env.APP_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: `${env.APP_URL}/billing`,
}, { idempotencyKey: `checkout-${userId}-${planKey}-${attemptId}` });
```

## Webhook: Reglas que No se Negocian
1. **Body crudo antes que `express.json()`**: monta el router del webhook con `express.raw({ type: 'application/json' })` **antes** de `app.use(express.json())`. Si el JSON se parsea primero, la firma siempre falla.
2. **Verificar la firma**: `stripe.webhooks.constructEvent(req.body, req.header('stripe-signature'), env.STRIPE_WEBHOOK_SECRET)`; si lanza → 400.
3. **Idempotencia**: inserta `event.id` en `stripe_events` dentro de la misma transacción que aplica el cambio; si ya existía, responde 200 sin reprocesar.
4. **Orden no garantizado**: para suscripciones, vuelve a leer el objeto actual (`stripe.subscriptions.retrieve(id)`) en lugar de confiar en el orden de llegada.
5. **Responder rápido** (2xx en < 10 s); el trabajo pesado (emails, notificaciones) se despacha de forma asíncrona.

Eventos mínimos obligatorios: `checkout.session.completed`, `customer.subscription.created|updated|deleted`, `invoice.paid`, `invoice.payment_failed`.

> En la API actual de Stripe, `current_period_end` se encuentra en los items de la suscripción: `subscription.items.data[0].current_period_end`.

## Control de Acceso por Plan
- Lógica de dominio en `packages/shared/src/domain/entitlements.ts` (`domain-logic-agent`) a partir de `subscriptions.status` (`active` o `trialing` = con acceso; `past_due` = periodo de gracia definido en el PRD).
- API: middleware `requirePlan('pro')`. Angular: `GET /me` incluye el estado de suscripción; `planGuard` y componentes UI controlan la navegación. La autorización estricta reside en la API.
- Angular redirige al checkout con `window.location.href = url` tras recibir la respuesta de `/billing/checkout`.

## Variables de Entorno
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_PRO_MONTHLY` (uno por plan), `APP_URL`. Claves de test (`sk_test_…`) en desarrollo y staging; claves de producción (`sk_live_…`) solo en la plataforma de producción.

## Pruebas y Simulación
- **Unitarias del webhook** sin red: genera firmas simuladas con `stripe.webhooks.generateTestHeaderString({ payload, secret })` y prueba firma válida (200), firma inválida (400) y evento repetido (idempotente).
- **Simulación local con Stripe CLI**:
  ```bash
  stripe listen --forward-to localhost:3000/api/v1/webhooks/stripe   # imprime el whsec_ para .env
  stripe trigger checkout.session.completed
  ```
- **Tarjetas de prueba** (modo test): `4242 4242 4242 4242` (éxito), `4000 0025 0000 3155` (3DS requerido), `4000 0000 0000 0002` (declinada).

## Checklist antes de `task.sh handoff`
- [ ] Endpoint de webhook montado antes de `express.json()` con lectura de payload en crudo (`express.raw`).
- [ ] Firma criptográfica de Stripe verificada obligatoriamente en cada llamada al webhook.
- [ ] Tabla `stripe_events` previene el procesamiento duplicado (idempotencia verificada con test).
- [ ] Ningún importe, divisa ni `price_id` recibido directamente desde el cliente web o móvil.
- [ ] Ningún plan o permiso otorgado desde `success_url` (solo webhooks activan privilegios).
- [ ] Simulación completa ejecutada con Stripe CLI: checkout, cobro exitoso, fallo de pago y cancelación.
- [ ] Secretos de Stripe (`sk_...`, `whsec_...`) excluidos del frontend y no versionados en Git.

## Prohibido
- Recibir o almacenar números de tarjeta de crédito, CVV o fechas de expiración en base de datos propia.
- Procesar payloads de webhook sin validar la cabecera `stripe-signature`.
- Activar planes o cambiar estados de cuenta basándose en la redirección de frontend (`success_url`).
- Omitir claves de idempotencia en peticiones de mutación a Stripe.
- Exponer credenciales secretas de Stripe en el cliente web, móvil o repositorios de código.
