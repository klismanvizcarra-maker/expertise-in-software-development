---
name: async-jobs
description: Trabajo asíncrono fiable fuera de la petición HTTP - colas y workers, outbox, consumidores idempotentes, reintentos con DLQ, subidas pre-firmadas y emails transaccionales. Usar para tareas en segundo plano. No usar para webhooks de cobro (payments-stripe).
---

# Trabajos Asíncronos, Subidas y Emails (Async Jobs)

Ninguna petición HTTP del usuario debe esperar a llamadas SMTP lentas, renderizado de PDFs, procesamiento multimedia o reintentos de APIs de terceros. Si una operación requiere confirmación durable tras una escritura en base de datos, **no la dispares directo en memoria**: persiste la intención en la misma transacción (**Outbox**) y procésala de forma idempotente en segundo plano.

## Recetas de referencia
- **Colas, Outbox, reintentos, DLQ y graceful shutdown**: [queues-outbox.md](references/queues-outbox.md)
- **Subidas directas con URLs pre-firmadas y emails transaccionales**: [uploads-email.md](references/uploads-email.md)

## Pasos

1. **Decidir si debe ser asíncrono**: envía fuera de línea HTTP todo lo que supere ~500 ms, dependa de terceros no críticos para la respuesta inmediata (emails, webhooks salientes, PDFs, indexación) o implique archivos pesados.
2. **Garantizar atomicidad con Transactional Outbox**: inserta la entidad de negocio y la fila de `outbox_events` dentro de la **misma transacción** SQL; un *poller* o *relay* publica a la cola (`BullMQ`/Redis, `pg-boss`, `Celery`/`ARQ`/Taskiq) con `FOR UPDATE SKIP LOCKED`.
3. **Hacer cada consumidor idempotente**: asigna una clave única (`idempotency_key` / `job_id`) antes de encolar y verifica en servidor que repetir el job 2 veces no duplique cobros, emails ni registros.
4. **Configurar reintentos acotados y DLQ**: distingue errores transitorios (429, timeouts, 5xx → backoff exponencial + *jitter*, máx. 5–8 intentos) de errores permanentes (400/validación → fallo inmediato sin reintentos a DLQ).
5. **Subidas y emails seguros**: usa URLs pre-firmadas con tipo MIME y tamaño límite en origen, valida *magic bytes* y clave aleatoria al confirmar (`security-hardening`), y renderiza emails con `autoescape=True`, locales del usuario (`i18n`) y sin PII en logs (`observability`).
6. **Cierre elegante y observabilidad**: propaga `request_id`/`traceparent` al job, expón profundidad de cola y edad del job pendiente más antiguo, y drena workers en `SIGTERM` antes del timeout (`devops-cloud-agent`).
7. **Entrega**: cubre idempotencia, fallo transitorio → reintento y envío a DLQ en tests (`testing-strategy`), y ejecuta `task.sh handoff TASK-XXX`.

## Checklist antes de `task.sh handoff`
- [ ] Operaciones lentas o envíos externos ejecutados fuera del ciclo petición/respuesta HTTP crítico.
- [ ] Publicación de eventos/tareas críticas atómica respecto a la escritura en BD (Transactional Outbox o mecanismo equivalente verificado).
- [ ] Todo *handler* de cola tolera re-entregas duplicadas (idempotente por `job_id`/`idempotency_key`).
- [ ] Reintentos con backoff exponencial + *jitter* y política de Dead-Letter Queue (DLQ) con máximo de intentos.
- [ ] Workers manejan `SIGTERM` deteniendo el consumo nuevo y esperando a terminar trabajos activos dentro de un timeout.
- [ ] Logs de worker incluyen `job_id` y `request_id` sin credenciales, contenido completo de emails ni PII (`observability`).

## Prohibido
- Usar tareas en memoria (`BackgroundTasks` de FastAPI o `setTimeout`/promesas sin `await` en Express/Next) para trabajo crítico que no pueda perderse si el proceso cae o se reinicia.
- Encolar trabajos antes o fuera de la transacción SQL esperando "que ambos tengan éxito" (doble escritura sin Outbox).
- Reintentar indefinidamente sin límite máximo ni backoff + *jitter* (provoca tormentas de reintentos).
- Almacenar archivos subidos por usuarios en el sistema de archivos local del contenedor efímero o usando el nombre original sin sanitizar.
- Loguear cuerpos de emails, tokens de reseteo de contraseña o enlaces pre-firmados con firma en stdout.
