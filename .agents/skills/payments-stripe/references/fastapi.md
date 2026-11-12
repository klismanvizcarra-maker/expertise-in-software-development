# Pagos con Stripe — FastAPI + SQLAlchemy 2 (async) + PostgreSQL

Receta de referencia para Python 3.12 + FastAPI (`stack-fastapi-postgres`). El endpoint de webhook lee los bytes exactos con `await request.body()` y las llamadas síncronas al SDK `stripe` no deben bloquear el *event loop* de `asyncio`.

## 1. Modelos SQLAlchemy (`app/models/billing.py`) + migración Alembic

- `BillingCustomer`: `user_id` (`ForeignKey("users.id")`, único), `stripe_customer_id` (único).
- `Subscription`: `stripe_subscription_id` (único), `user_id`, `status`, `price_id`, `current_period_end` (`DateTime(timezone=True)`), `cancel_at_period_end` (`bool`).
- `StripeEvent`: `event_id` (PK `str`), `type` (`str`), `processed_at` (`DateTime(timezone=True)`).

## 2. Webhook seguro con body en bytes e idempotencia

```python
import asyncio
import stripe
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session
from app.core.config import settings

router = APIRouter(prefix="/api/v1/webhooks", tags=["webhooks"])

@router.post("/stripe")
async def stripe_webhook(
    request: Request,
    stripe_signature: str | None = Header(default=None),
    session: AsyncSession = Depends(get_session),
):
    if not stripe_signature:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="ERR_MISSING_SIGNATURE")

    payload = await request.body()  # bytes crudos sin parsear JSON
    try:
        event = stripe.Webhook.construct_event(
            payload=payload,
            sig_header=stripe_signature,
            secret=settings.stripe_webhook_secret,
        )
    except (ValueError, stripe.SignatureVerificationError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="ERR_INVALID_SIGNATURE")

    stmt = (
        pg_insert(StripeEvent)
        .values(event_id=event["id"], type=event["type"])
        .on_conflict_do_nothing(index_elements=["event_id"])
        .returning(StripeEvent.event_id)
    )
    inserted = (await session.execute(stmt)).scalar_one_or_none()
    if inserted is None:
        return {"received": True}  # evento ya procesado

    # Ejemplo: re-leer suscripción sin bloquear el loop
    # sub = await asyncio.to_thread(stripe.Subscription.retrieve, sub_id)
    await session.commit()
    return {"received": True}
```

## 3. Checkout, Portal y Dependencia de Plan (`deps.py`)

- No bloquees el *event loop* en llamadas de red a Stripe: envuelve las llamadas clásicas (`stripe.checkout.Session.create(..., idempotency_key=...)`) en `await asyncio.to_thread(...)`, o usa `StripeClient` con el sufijo `_async` (`await client.v1.checkout.sessions.create_async(params={...}, options={"idempotency_key": ...})` si instalas `stripe[async]`), validando siempre `plan_key` contra `settings.allowed_price_ids` en `app/core/config.py`.
- Protege rutas premium mediante dependencia FastAPI `Depends(require_plan("pro"))` consultando `subscriptions` en servidor (y reglas puras en `app/domain/entitlements.py`).
- Para tests con `pytest` + `httpx.AsyncClient`, genera firmas sintéticas HMAC-SHA256 válidas con el mismo formato `t=<ts>,v1=<hex>` usando `settings.stripe_webhook_secret` de test para probar: firma válida (`200`), inválida (`400`) y replay duplicado (idempotente).
