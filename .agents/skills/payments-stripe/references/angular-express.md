# Pagos con Stripe — Angular 22 + Express 5 + Drizzle

Receta de referencia para el monorepo Angular + Express (`stack-angular-express-postgres`). Verificado con `stripe` 23 (API `2026-09-30.endive`) y Express 5.

## 1. Modelo Drizzle (`apps/api/src/db/`)

| Tabla | Columnas clave |
| :--- | :--- |
| `billing_customers` | `userId` (único, FK a `users.id`), `stripeCustomerId` (único) |
| `subscriptions` | `stripeSubscriptionId` (único), `userId`, `status`, `priceId`, `currentPeriodEnd` (`timestamptz`), `cancelAtPeriodEnd` |
| `stripe_events` | `eventId` (PK), `type`, `processedAt` → idempotencia transaccional de webhooks |

## 2. Montaje crítico de Webhook en Express 5

```ts
// apps/api/src/app.ts — SIEMPRE antes de app.use(express.json())
app.post(
  '/api/v1/webhooks/stripe',
  express.raw({ type: 'application/json' }),
  stripeWebhookHandler
);

app.use(express.json({ limit: '100kb' }));
```

Si `express.json()` se ejecuta antes que `express.raw()`, `req.body` deja de ser un `Buffer` sin parsear y `stripe.webhooks.constructEvent(...)` fallará siempre.

## 3. Verificación, idempotencia y Checkout en Node

```ts
// apps/api/src/modules/billing/billing.controller.ts
import Stripe from 'stripe';
import { BadRequestException } from '../../lib/api-response.ts';

const sig = req.header('stripe-signature');
if (!sig) throw new BadRequestException('Falta cabecera stripe-signature');

let event: Stripe.Event;
try {
  // constructEvent lanza StripeSignatureVerificationError (no HttpException):
  // capturar explícitamente para responder 400 y evitar 500 en errorHandler
  event = stripe.webhooks.constructEvent(req.body, sig, env.STRIPE_WEBHOOK_SECRET);
} catch {
  throw new BadRequestException('Firma Stripe inválida');
}

// Re-consultar suscripción en Stripe FUERA de db.transaction para no retener conexiones/locks en I/O HTTP
const sub =
  event.type.startsWith('customer.subscription.')
    ? await stripe.subscriptions.retrieve((event.data.object as Stripe.Subscription).id)
    : null;

await db.transaction(async (tx) => {
  const inserted = await tx
    .insert(stripeEvents)
    .values({ eventId: event.id, type: event.type })
    .onConflictDoNothing()
    .returning({ id: stripeEvents.eventId });
  if (inserted.length === 0) return; // evento repetido: responder 200

  // Persistir estado de sub / evento dentro de la transacción
});
```

- Al crear Checkout Sessions (`stripe 23`): no envíes `payment_method_types` (se configuran en Dashboard o vía `allowed_payment_method_types` si hace falta restringir).
- `current_period_end` reside en los ítems de suscripción: `subscription.items.data[0].current_period_end`.

## 4. Autorización y Frontend Angular

- Reglas de acceso puras en `packages/shared/src/domain/entitlements.ts` (`domain-logic-agent`).
- API protegida con middleware `requirePlan('pro')`; `GET /me` devuelve el estado de plan activo.
- Angular protege rutas de UI con `planGuard` (solo UX; la autoridad es la API) y redirige al Checkout devuelto por `POST /api/v1/billing/checkout` mediante `window.location.href = url`.
