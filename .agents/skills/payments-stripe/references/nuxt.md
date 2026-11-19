# Pagos con Stripe — Vue 3 + Nuxt 3 + Drizzle

Receta de referencia para `stack-vue-nuxt-postgres`. Utiliza **Nitro Server Routes** para endpoints de facturación y webhooks (leyendo el body en crudo con `readRawBody`), cliente Stripe inicializado en `server/utils/stripe.ts` y **Drizzle ORM con transacciones** para persistencia e idempotencia.

## 1. Esquema Drizzle (`server/db/schema.ts`)

Tablas mínimas requeridas:

```ts
import { pgTable, text, timestamp, boolean, uuid } from 'drizzle-orm/pg-core';

export const billingCustomers = pgTable('billing_customers', {
  userId: uuid('user_id').primaryKey(),
  stripeCustomerId: text('stripe_customer_id').notNull().unique(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
});

export const subscriptions = pgTable('subscriptions', {
  stripeSubscriptionId: text('stripe_subscription_id').primaryKey(),
  userId: uuid('user_id').notNull(),
  status: text('status').notNull(), // 'active', 'trialing', 'past_due', 'canceled'
  priceId: text('price_id').notNull(),
  currentPeriodEnd: timestamp('current_period_end', { withTimezone: true }).notNull(),
  cancelAtPeriodEnd: boolean('cancel_at_period_end').default(false).notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
});

export const stripeEvents = pgTable('stripe_events', {
  eventId: text('event_id').primaryKey(),
  type: text('type').notNull(),
  processedAt: timestamp('processed_at', { withTimezone: true }).defaultNow().notNull(),
});
```

## 2. Webhook en Nitro (`server/api/webhooks/stripe.post.ts`)

```ts
import type Stripe from 'stripe';
import { stripe } from '~~/server/utils/stripe';
import { db } from '~~/server/utils/db';
import { stripeEvents, subscriptions } from '~~/server/db/schema';
import { eq } from 'drizzle-orm';

export default defineEventHandler(async (event) => {
  const sig = getHeader(event, 'stripe-signature');
  if (!sig) {
    throw createError({ statusCode: 400, statusMessage: 'Missing stripe-signature header' });
  }

  // Leer payload binario/crudo antes de que Nitro o cualquier plugin lo parsee
  const rawBody = await readRawBody(event, 'utf8');
  if (!rawBody) {
    throw createError({ statusCode: 400, statusMessage: 'Empty request body' });
  }

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!webhookSecret) {
    throw createError({ statusCode: 500, statusMessage: 'Webhook secret not configured' });
  }

  let stripeEvent: Stripe.Event;
  try {
    stripeEvent = stripe.webhooks.constructEvent(rawBody, sig, webhookSecret);
  } catch (err: any) {
    throw createError({ statusCode: 400, statusMessage: `Webhook signature verification failed: ${err.message}` });
  }

  // Comprobar idempotencia antes de procesar
  const existing = await db
    .select({ eventId: stripeEvents.eventId })
    .from(stripeEvents)
    .where(eq(stripeEvents.eventId, stripeEvent.id))
    .limit(1);

  if (existing.length > 0) {
    return { received: true, duplicate: true };
  }

  // Re-consultar suscripción en Stripe fuera de la transacción DB (evita bloqueos de red)
  const subData = stripeEvent.type.startsWith('customer.subscription.')
    ? await stripe.subscriptions.retrieve((stripeEvent.data.object as Stripe.Subscription).id)
    : null;

  await db.transaction(async (tx) => {
    // Registrar evento para bloquear reintentos concurrentes
    await tx
      .insert(stripeEvents)
      .values({ eventId: stripeEvent.id, type: stripeEvent.type })
      .onConflictDoNothing();

    if (subData) {
      await tx
        .insert(subscriptions)
        .values({
          stripeSubscriptionId: subData.id,
          userId: subData.metadata.userId as any,
          status: subData.status,
          priceId: subData.items.data[0].price.id,
          currentPeriodEnd: new Date(subData.current_period_end * 1000),
          cancelAtPeriodEnd: subData.cancel_at_period_end,
          updatedAt: new Date(),
        })
        .onConflictDoUpdate({
          target: subscriptions.stripeSubscriptionId,
          set: {
            status: subData.status,
            priceId: subData.items.data[0].price.id,
            currentPeriodEnd: new Date(subData.current_period_end * 1000),
            cancelAtPeriodEnd: subData.cancel_at_period_end,
            updatedAt: new Date(),
          },
        });
    }
  });

  return { received: true };
});
```

## 3. Sesión de Checkout (`server/api/billing/checkout.post.ts`)

```ts
import { stripe } from '~~/server/utils/stripe';
import { z } from 'zod';

const schema = z.object({
  planKey: z.enum(['pro_monthly', 'pro_annual']),
});

export default defineEventHandler(async (event) => {
  // Autenticar usuario desde contexto de sesión de Nitro/auth middleware
  const user = event.context.user;
  if (!user) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' });
  }

  const body = await readValidatedBody(event, (b) => schema.parse(b));
  const priceId = body.planKey === 'pro_annual'
    ? process.env.STRIPE_PRICE_PRO_ANNUAL
    : process.env.STRIPE_PRICE_PRO_MONTHLY;

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NUXT_PUBLIC_SITE_URL}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NUXT_PUBLIC_SITE_URL}/billing`,
    customer_email: user.email,
    metadata: { userId: user.id },
    subscription_data: { metadata: { userId: user.id } },
  }, {
    idempotencyKey: `checkout_${user.id}_${Date.now()}`,
  });

  return { url: session.url };
});
```
