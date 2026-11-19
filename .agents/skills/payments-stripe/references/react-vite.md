# Pagos con Stripe — React 19 + Vite + Node (Express)

Receta de referencia para `stack-react-vite-node`. Configura el backend Express en `server/` para webhooks crudos (`express.raw`), controladores tipados y cliente React en `client/` con `@stripe/stripe-js`.

## 1. Middleware de Webhook Crudo en Express (`server/src/app.ts`)

> **Regla Crítica**: La ruta `/api/webhooks/stripe` debe recibir el body binario sin parsear. Monta `express.raw` **antes** de `express.json()` general.

```ts
import express from 'express';
import { stripeWebhookHandler } from './controllers/stripe.controller';

const app = express();

// Ruta de webhook cruda ANTES de express.json()
app.post(
  '/api/webhooks/stripe',
  express.raw({ type: 'application/json' }),
  stripeWebhookHandler
);

// Body parser JSON para el resto de rutas
app.use(express.json());
```

## 2. Controlador de Webhook (`server/src/controllers/stripe.controller.ts`)

```ts
import { Request, Response } from 'express';
import Stripe from 'stripe';
import { pool } from '../db';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-02-24.acacia' as any,
});

export async function stripeWebhookHandler(req: Request, res: Response): Promise<void> {
  const sig = req.headers['stripe-signature'];
  if (!sig || typeof sig !== 'string') {
    res.status(400).json({ error: 'Missing stripe-signature header' });
    return;
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch (err: any) {
    res.status(400).json({ error: `Signature verification failed: ${err.message}` });
    return;
  }

  // Idempotencia: comprobar si ya se procesó
  const checkResult = await pool.query(
    'SELECT event_id FROM stripe_events WHERE event_id = $1',
    [event.id]
  );
  if (checkResult.rowCount && checkResult.rowCount > 0) {
    res.json({ received: true, duplicate: true });
    return;
  }

  // Consultar suscripción fuera de transacciones SQL
  const subData = event.type.startsWith('customer.subscription.')
    ? await stripe.subscriptions.retrieve((event.data.object as Stripe.Subscription).id)
    : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'INSERT INTO stripe_events (event_id, type) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [event.id, event.type]
    );

    if (subData) {
      await client.query(
        `INSERT INTO subscriptions (stripe_subscription_id, user_id, status, price_id, current_period_end, cancel_at_period_end)
         VALUES ($1, $2, $3, $4, to_timestamp($5), $6)
         ON CONFLICT (stripe_subscription_id) DO UPDATE SET
           status = EXCLUDED.status,
           price_id = EXCLUDED.price_id,
           current_period_end = EXCLUDED.current_period_end,
           cancel_at_period_end = EXCLUDED.cancel_at_period_end,
           updated_at = NOW()`,
        [
          subData.id,
          subData.metadata.userId,
          subData.status,
          subData.items.data[0].price.id,
          subData.current_period_end,
          subData.cancel_at_period_end,
        ]
      );
    }
    await client.query('COMMIT');
    res.json({ received: true });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: 'Database transaction failed' });
  } finally {
    client.release();
  }
}
```

## 3. Checkout en Cliente React (`client/src/features/billing/UpgradeButton.tsx`)

```tsx
import { useState } from 'react';

export function UpgradeButton({ planKey }: { planKey: 'monthly' | 'annual' }) {
  const [loading, setLoading] = useState(false);

  const handleCheckout = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/billing/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include', // Cookie JWT HttpOnly
        body: JSON.stringify({ planKey }),
      });
      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <button onClick={handleCheckout} disabled={loading} className="btn-primary">
      {loading ? 'Redirigiendo...' : 'Actualizar a Pro'}
    </button>
  );
}
```
