# Pagos con Stripe — Next.js 15 + Prisma

Receta de referencia para Next.js App Router (`stack-nextjs-tailwind-prisma`). Usa **Route Handler** para webhooks (body en texto crudo intacto), **Server Actions o Route Handlers** autenticados para Checkout/Portal y **Prisma `$transaction`** para idempotencia.

## 1. Esquema Prisma (`prisma/schema.prisma`)

Modelos mínimos:
- `BillingCustomer`: `userId` (`@unique`, FK), `stripeCustomerId` (`@unique`).
- `Subscription`: `stripeSubscriptionId` (`@unique`), `userId`, `status`, `priceId`, `currentPeriodEnd` (`DateTime @db.Timestamptz`), `cancelAtPeriodEnd` (`Boolean`).
- `StripeEvent`: `eventId` (`@id`), `type`, `processedAt` (`DateTime @default(now())`).

## 2. Webhook en Route Handler (`app/api/webhooks/stripe/route.ts`)

```ts
import { NextResponse } from 'next/server';
import type Stripe from 'stripe';
import { prisma } from '@/lib/prisma';
import { stripe } from '@/lib/stripe';

export const runtime = 'nodejs'; // necesario para SDK/crypto y conexión DB estándar

export async function POST(req: Request) {
  const sig = req.headers.get('stripe-signature');
  if (!sig) return NextResponse.json({ error: 'Missing signature' }, { status: 400 });

  const rawBody = await req.text(); // NUNCA req.json(): altera formato/bytes
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }

  if (await prisma.stripeEvent.findUnique({ where: { eventId: event.id } })) {
    return NextResponse.json({ received: true }); // evento ya procesado
  }

  // Re-consultar suscripción en Stripe fuera de prisma.$transaction (evita I/O de red dentro de locks DB)
  const sub = event.type.startsWith('customer.subscription.')
    ? await stripe.subscriptions.retrieve((event.data.object as Stripe.Subscription).id)
    : null;

  await prisma.$transaction(async (tx) => {
    const existing = await tx.stripeEvent.findUnique({ where: { eventId: event.id } });
    if (existing) return;
    await tx.stripeEvent.create({ data: { eventId: event.id, type: event.type } });
    // Sincronizar suscripción usando `sub`
  });

  return NextResponse.json({ received: true });
}
```

> Captura también `P2002` (unique constraint) si llegan dos entregas simultáneas antes del `findUnique`, respondiendo `200` de forma idempotente.
> Excluye `/api/webhooks/stripe` de middlewares que requieran sesión/CSRF de usuario, nunca de la firma Stripe.

## 3. Checkout / Portal y Control de Acceso

- **Checkout**: en una Server Action (`app/actions/billing.ts`) o `POST /api/billing/checkout`, autentica la sesión (`auth()`), traduce `planKey` a `process.env.STRIPE_PRICE_*` en servidor, crea `checkout.sessions.create(..., { idempotencyKey })` y redirige con `redirect(session.url)` (o devuelve `{ url }`).
- **Entitlements**: lógica pura en `lib/domain/entitlements.ts`; verifica el plan en **Server Components y Server Actions** contra PostgreSQL antes de ejecutar cualquier mutación o cargar datos premium (no confíes solo en props de cliente).
