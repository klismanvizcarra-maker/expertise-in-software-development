---
name: payments-stripe
description: Integra cobros con Stripe en aplicaciones web y APIs - suscripciones y pagos únicos con Stripe Checkout alojado, portal de cliente, webhooks con firma verificada e idempotencia, sincronización de suscripciones en PostgreSQL, control de acceso por plan y pruebas en modo test con Stripe CLI. Usar al añadir planes, paywalls, checkout, facturación o suscripciones, o al depurar webhooks de Stripe. No usar para definir precios o el modelo de negocio (product-manager-agent).
---

# Pagos con Stripe

Stripe es la única fuente de verdad del dinero; tu base de datos es un espejo sincronizado **exclusivamente mediante webhooks**.

## Recetas por stack
Carga la referencia que corresponda al stack del proyecto (`GLOBAL_STATE.md` §2):
- **Angular + Express + Drizzle**: [references/angular-express.md](references/angular-express.md)
- **Next.js + Prisma**: [references/nextjs.md](references/nextjs.md)
- **FastAPI + SQLAlchemy 2**: [references/fastapi.md](references/fastapi.md)
- **Otro stack**: aplica este protocolo agnóstico y registra los detalles concretos en un ADR (`docs-architecture-agent`).

## Protocolo

1. **Modelado y persistencia**: crea las tablas `billing_customers`, `subscriptions` y `stripe_events` con `database-architect-agent`.
2. **Precios en servidor**: mapea cada clave semántica de plan (`"pro_monthly"`) a su `price_id` en variables de entorno (`.env`); nunca aceptes importes, divisas ni `price_id` desde el cliente.
3. **Endpoints de sesión**: implementa `POST /api/v1/billing/checkout` (con `idempotencyKey` y `client_reference_id`) y `POST /api/v1/billing/portal` autenticados.
4. **Endpoint de webhook seguro**: lee el **body crudo intacto** antes de cualquier parser JSON, valida la firma `stripe-signature` y aplica los cambios de forma idempotente registrando `event.id` en `stripe_events` dentro de la misma transacción.
5. **Control de acceso en dominio**: modela las reglas de acceso (`active`, `trialing`, periodo de gracia en `past_due`) en funciones puras (`domain-logic-agent`) y protege las rutas/acciones en el servidor.
6. **Pruebas y simulación local**: cubre firma válida (`200`), firma inválida (`400`) y replay duplicado en tests unitarios, y valida eventos completos con Stripe CLI.
7. **Entrega**: completa el checklist antes de ejecutar `task.sh handoff TASK-XXX`.

## Decisiones y Reglas No Negociables
- **Stripe Checkout alojado** + **Customer Portal**: no se construyen formularios de tarjeta propios (alcance PCI mínimo).
- **Webhooks como fuente de verdad**: `success_url` solo muestra estado "procesando"; nunca activa planes ni permisos.
- **Orden no garantizado**: ante eventos de suscripción, vuelve a leer el recurso actual en Stripe (`subscriptions.retrieve`); en la API actual `current_period_end` reside en `subscription.items.data[0].current_period_end`.
- **Responder rápido (< 10 s)**: devuelve `2xx` tras persistir de forma transaccional y delega tareas pesadas (emails, PDFs) de manera asíncrona.
- **Eventos mínimos obligatorios**: `checkout.session.completed`, `customer.subscription.created|updated|deleted`, `invoice.paid`, `invoice.payment_failed`.

## Variables de Entorno y Pruebas CLI
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_PRO_MONTHLY`, `APP_URL`. Claves de test (`sk_test_…`) en desarrollo/staging y `sk_live_…` solo en producción.

```bash
stripe listen --forward-to localhost:3000/api/v1/webhooks/stripe
stripe trigger checkout.session.completed
```

Tarjetas de prueba (modo test): `4242 4242 4242 4242` (éxito), `4000 0025 0000 3155` (3DS requerido), `4000 0000 0000 0002` (declinada).

## Checklist antes de `task.sh handoff`
- [ ] El endpoint de webhook lee los bytes/texto en crudo **antes** de cualquier parser JSON.
- [ ] Firma criptográfica `stripe-signature` verificada obligatoriamente en cada entrega del webhook.
- [ ] Tabla `stripe_events` previene el reprocesamiento de eventos duplicados (idempotencia cubierta por test).
- [ ] Ningún importe, divisa ni `price_id` aceptado directamente desde el cliente.
- [ ] Ningún plan ni permiso activado desde `success_url` (solo webhooks activan privilegios).
- [ ] Simulación ejecutada en modo test (checkout, pago correcto, fallo de pago y cancelación).
- [ ] Claves secretas de Stripe (`sk_...`, `whsec_...`) fuera del cliente y sin versionar en Git.

## Prohibido
- Recibir o almacenar números de tarjeta de crédito, CVV o fechas de expiración en base de datos propia.
- Procesar webhooks sin validar la cabecera `stripe-signature`.
- Activar planes o cambiar suscripciones basándose en `success_url`.
- Omitir claves de idempotencia al crear sesiones o cargos en Stripe.
- Exponer claves secretas de Stripe (`sk_...`, `whsec_...`) en el frontend o repositorios.
