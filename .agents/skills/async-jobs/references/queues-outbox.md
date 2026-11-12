# Colas, Transactional Outbox y Workers Resilientes

Patrones de entrega *at-least-once* e idempotencia válidos para Node 24 (`BullMQ`, `pg-boss`) y Python 3.12 (`ARQ`, `Taskiq`, `Celery` o tabla Outbox en PostgreSQL).

## 1. Transactional Outbox (cero pérdida ni eventos fantasma)

Nunca hagas `await db.commit(); await queue.enqueue(...)` si perder el evento rompe el estado del negocio (ej. usuario creado sin email de verificación o pedido sin factura). En su lugar:

1. **En la misma transacción HTTP**: guarda la entidad de negocio e inserta un registro en `outbox_events` (`id`, `topic`, `payload_json`, `idempotency_key`, `status DEFAULT 'pending'`, `attempts DEFAULT 0`, `next_run_at TIMESTAMPTZ DEFAULT now()`, `created_at`).
2. **En el *relay* o worker**: toma lotes pequeños con bloqueo sin contención:
   ```sql
   SELECT id, topic, payload_json, idempotency_key
   FROM outbox_events
   WHERE status = 'pending' AND next_run_at <= now()
   ORDER BY created_at
   LIMIT 25
   FOR UPDATE SKIP LOCKED;
   ```
3. **Al procesar**: si falla de forma transitoria incrementa `attempts` y programa `next_run_at = now() + (2^attempts * base + random_jitter)`; al alcanzar `MAX_ATTEMPTS` mueve a `status = 'dead_letter'` y dispara alerta con runbook (`observability`).

> Si usas herramientas ligeras cuando ya tienes PostgreSQL (sin Redis aún), una tabla Outbox + worker dedicado con `FOR UPDATE SKIP LOCKED` ahorra infraestructura manteniendo entrega transaccional.

## 2. Idempotencia del consumidor (*at-least-once* → efecto *exactly-once*)

Toda cola real entrega al menos una vez ante caídas de red o *visibility timeout* expirado:
- **Tabla / clave de deduplicación**: registra `(consumer_name, idempotency_key)` con restricción `UNIQUE` antes de aplicar el efecto secundario, o comprueba que la transición de estado esperada sigue siendo válida (máquina de estados en `domain-logic-agent`).
- **Terceros externos**: pasa siempre `idempotency_key` en cabeceras/opciones (Stripe, proveedor de email) para que incluso un timeout tras el envío no duplique el efecto.
- **Heartbeat / Visibility Timeout**: dimensiona el timeout del job por encima del p99 real de ejecución (o renueva heartbeat en tareas largas) para evitar dos workers ejecutando el mismo job simultáneamente.

## 3. Backoff exponencial, Jitter y DLQ

- **Backoff con full jitter**: `delay = random(0, min(MAX_DELAY, BASE_DELAY * 2 ** attempt))` (ej. base `5 s`, tope `15 min`, máximo `6` intentos). Evita que mil workers caídos reintenten exactamente en el mismo segundo (*thundering herd*).
- **Errores no recuperables**: esquemas inválidos, entidad eliminada (`404`), permiso revocado o bounces permanentes (`hard bounce`) deben ir directo a DLQ o cerrarse como fallo permanente sin quemar reintentos.
- **Reprocesamiento seguro de DLQ**: tras corregir el bug, las herramientas de soporte re-encolan filtrando por `topic`/rango de tiempo conservando la `idempotency_key` original.

## 4. Apagado elegante (`SIGTERM`) en workers

- En `SIGTERM` / `SIGINT`:
  1. Deja de aceptar jobs nuevos (`worker.pause()` / dejar de hacer `dequeue`).
  2. Espera a que terminen los jobs en curso hasta un límite (`grace_period`, p. ej. 20–25 s, menor que el `terminationGracePeriodSeconds` del orquestador).
  3. Cierra pools de Redis/PostgreSQL y sale limpiamente (o devuelve jobs inconclusos a la cola si el tiempo expira).
- Reporta logs JSON estructurados por job con `job_id`, `topic`, `attempt`, `duration_ms` y el `request_id`/`traceparent` heredado del productor.
