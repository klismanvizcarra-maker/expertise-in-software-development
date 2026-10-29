---
name: payments-stripe
description: Integra cobros con Stripe en apps web (Express + Angular) - suscripciones y pagos únicos con Stripe Checkout alojado, portal de cliente, webhooks con firma verificada e idempotencia, sincronización de suscripciones en PostgreSQL, control de acceso por plan y pruebas en modo test con Stripe CLI. Usar al añadir planes, paywalls, checkout, facturación o suscripciones, o al depurar webhooks de Stripe. No usar para definir precios o el modelo de negocio (product-manager-agent).
---

# Pagos con Stripe

Stripe es la fuente de verdad del dinero; tu base de datos es un espejo que se actualiza **solo por webhooks**. Verificado con `stripe` 23 (API `2026-09-30.endive`) y Express 5.

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
1. **Body crudo antes que `express.json()`**: monta el router del webhook con `express.raw({ type: 'application/json' })` **antes** de `app.use(express.json())`. Si el JSON se parsea primero, la firma siempre falla (comprobado).
2. **Verificar la firma**: `stripe.webhooks.constructEvent(req.body, req.header('stripe-signature'), env.STRIPE_WEBHOOK_SECRET)`; si lanza → 400.
3. **Idempotencia**: inserta `event.id` en `stripe_events` dentro de la misma transacción que aplica el cambio; si ya existía, responde 200 sin reprocesar.
4. **Orden no garantizado**: para suscripciones, vuelve a leer el objeto actual (`stripe.subscriptions.retrieve(id)`) en lugar de confiar en el orden de llegada.
5. **Responder rápido** (2xx en < 10 s); el trabajo pesado (emails, etc.) va después o en cola.

Eventos mínimos: `checkout.session.completed` (vincular customer/suscripción al `client_reference_id`), `customer.subscription.created|updated|deleted` (sincronizar estado), `invoice.paid` e `invoice.payment_failed` (avisar al usuario).

> En la API actual, `current_period_end` está en los **items** de la suscripción: `subscription.items.data[0].current_period_end`.

## Acceso por Plan
- Las reglas de qué incluye cada plan son lógica de dominio (`packages/shared/src/domain/entitlements.ts`, `domain-logic-agent`) a partir de `subscriptions.status` (`active` o `trialing` = con acceso; `past_due` = periodo de gracia definido en el PRD).
- API: middleware `requirePlan('pro')`. Angular: `GET /me` incluye el plan; `planGuard` y la UI muestran el paywall. La seguridad está en la API.
- Angular redirige a Stripe con `window.location.href = url` tras llamar a `/billing/checkout`.

## Variables de Entorno
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_PRO_MONTHLY` (uno por plan), `APP_URL`. Claves de test (`sk_test_…`) en desarrollo y staging; las `sk_live_…` solo en la plataforma de producción. El escáner de secretos bloquea ambas en commits.

## Pruebas
- **Unitarias del webhook** sin red: firma con `stripe.webhooks.generateTestHeaderString({ payload, secret })` y envía con supertest (firma válida → 200, inválida → 400, evento repetido → idempotente).
- **Local con Stripe CLI**:
  ```bash
  stripe listen --forward-to localhost:3000/api/v1/webhooks/stripe   # imprime el whsec_ para .env
  stripe trigger checkout.session.completed
  ```
- **Tarjetas de prueba** (solo modo test): `4242 4242 4242 4242` (éxito), `4000 0025 0000 3155` (requiere 3D Secure), `4000 0000 0000 0002` (rechazada).
- **E2E** (`e2e-testing`): el flujo hasta la redirección a Stripe y el estado "procesando"; la activación del plan se prueba disparando el webhook.

## Checklist antes de `task.sh handoff`
- [ ] Webhook montado antes de `express.json()` y con firma verificada.
- [ ] `stripe_events` evita el doble procesamiento.
- [ ] Ningún importe ni `price_id` viene del cliente.
- [ ] Ningún plan se activa desde `success_url`.
- [ ] Probado con Stripe CLI: alta, renovación, fallo de pago y cancelación.
