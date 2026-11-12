# Dinero Exacto, Fechas UTC y Máquinas de Estado Finitas (FSM)

Guía práctica para implementar funciones puras en `src/domain/` (o `packages/shared/src/domain/`, `lib/domain/`, `app/domain/` según el stack).

## 1. Aritmética Monetaria Exacta (cero pérdidas de céntimos)

- **Unidad mínima entera**: representa dinero como `{ amountCents: number; currency: CurrencyCode }` (`integer`, nunca `float` para no sufrir `0.1 + 0.2 === 0.30000000000000004`).
- **Redondeo único al final**: realiza multiplicaciones con numerador antes que división cuando operes en enteros, o usa decimal de precisión exacta, y documenta la regla (`half-even` / *banker's rounding* o `half-up`).
- **Reparto sin perder céntimos (*Largest Remainder / Hamilton*)**:
  Al dividir un importe entre cuotas o ítems (p. ej. `100` céntimos en `3` cuotas o aplicar un descuento proporcional a líneas de carrito):
  1. Calcula parte entera `Math.floor((total * weight) / totalWeight)` y su residuo.
  2. Suma `1` céntimo a las cuotas con mayor residuo hasta cuadrar **exactamente** `sum(parts) === total`. Nunca uses `Math.round` independiente por línea dejando `99` o `101` céntimos.
- **Invariantes monetarios recomendados en tests**:
  - `sum(allocations) === originalTotal` para todo importe `>= 0`.
  - Negativos rechazados explícitamente donde el negocio solo admite importes positivos (`InvalidAmountError`).
  - Prorrateos de cambio de plan con reloj inyectado (`nowUtc`) verificando días restantes exactos (`0` a `periodDays`) sin cruzar de signo ante cambios simultáneos.

## 2. Fechas y Tiempo Deterministas (sin `Date.now()` ni DST)

- Inyecta `nowUtc` o un parámetro de fecha civil ISO (`YYYY-MM-DD`) en toda regla temporal (expiración de cupones, periodos de gracia, penalizaciones).
- Nunca dependas de zona horaria local del servidor ni de aritmética local de horas (`+ 24h` falla en cambios horario DST cuando el día dura 23 h o 25 h): usa fechas civiles puras o milisegundos/segundos UTC explícitos.

## 3. Máquinas de Estado Finitas (FSM)

Modela el ciclo de vida de entidades críticas (pedidos, suscripciones, reservas, uploads) como tabla explícita de transiciones permitidas:

```ts
// Ejemplo conceptual puro sin framework ni BD
type OrderStatus = 'DRAFT' | 'PENDING_PAYMENT' | 'PAID' | 'CANCELLED' | 'REFUNDED';
type OrderEvent = 'SUBMIT' | 'PAY' | 'CANCEL' | 'REFUND';

const TRANSITIONS: Record<OrderStatus, Partial<Record<OrderEvent, OrderStatus>>> = {
  DRAFT:           { SUBMIT: 'PENDING_PAYMENT', CANCEL: 'CANCELLED' },
  PENDING_PAYMENT: { PAY: 'PAID',               CANCEL: 'CANCELLED' },
  PAID:            { REFUND: 'REFUNDED' },
  CANCELLED:       {},
  REFUNDED:        {},
};
```

- **Guardas e invariantes**: cada transición evalúa sus condiciones puras (ej. `PAID -> REFUND` exige `refundedCents <= totalCents`) antes de devolver el nuevo estado inmutable; si la transición no existe en `TRANSITIONS[current][event]`, lanza un error tipado (`InvalidTransitionError`).
- **Tests mínimos**: cubre 100 % de las combinaciones `(estado, evento)` prohibidas comprobando que lanzan `InvalidTransitionError` (matriz completa `N estados × M eventos`), además de los invariantes de borde (`0`, `1`, máximo, nulos).

