---
name: observability
description: Hace que la aplicación se pueda observar en producción - logs estructurados en JSON con identificador de correlación y sin datos sensibles, métricas RED (peticiones, errores, duración) y de negocio, trazas distribuidas con OpenTelemetry, reporte de errores (Sentry o similar), health y readiness checks, y alertas accionables con su runbook. Usar al preparar una app o un servicio para producción, al añadir logs o métricas a una funcionalidad, al investigar por qué no se ve qué pasa en producción, o al definir alertas y SLO. No usar para mejorar la velocidad de la app (web-performance) ni para montar despliegues o pipelines (devops-cloud-agent).
---

# Observabilidad

Si no se puede ver, no se puede operar. Cada funcionalidad que llega a producción responde a tres preguntas sin desplegar nada nuevo: **¿está funcionando?, ¿para quién falla?, ¿por qué?** La carga el especialista que implementa (backend, frontend o devops) junto con la skill de su rol y la del stack.

## Pasos

1. **Decidir qué hay que ver**: para la funcionalidad, anota en la tarea la señal de que funciona (métrica de negocio: pedidos creados, pagos confirmados), la señal de que falla (tasa de error, latencia p95) y qué datos necesitarías para diagnosticar un fallo.
2. **Logs estructurados**: una línea JSON por evento con `timestamp`, `level`, `message`, `service`, `request_id` y contexto útil (`user_id`, `order_id`). Nada de datos sensibles. Niveles con criterio: `error` solo para lo que requiere acción. Detalle: [logs-metrics-traces.md](references/logs-metrics-traces.md#logs).
3. **Correlación**: cada petición lleva un `request_id` (propio, o el `X-Request-Id` de un servicio interno de confianza, validado si viene de un cliente público) en todos sus logs y en las respuestas de error, y se pasa a los servicios que llames. Si hay trazas, registra también el `trace_id` del `traceparent` de W3C, que identifica la traza distribuida, no la petición.
4. **Métricas**: RED por endpoint (peticiones, errores, duración en histograma) y las métricas de negocio del paso 1. Etiquetas de baja cardinalidad: ruta con plantilla (`/orders/:id`), nunca el ID real ni el usuario.
5. **Trazas** (cuando hay varios servicios, colas o llamadas externas lentas): instrumenta con OpenTelemetry y exporta por OTLP; propaga el contexto entre servicios y colas.
6. **Errores**: captura las excepciones no controladas con un servicio de reporte (Sentry, Rollbar o el del proveedor) con versión de release, entorno y `request_id`, filtrando datos sensibles antes de enviar.
7. **Salud**: `GET /healthz` (vivo, sin dependencias) y `GET /readyz` (puede atender: base de datos y dependencias críticas), sin información sensible en la respuesta. Son las rutas que usan `devops-cloud-agent`, `backend-agent` y `stack-angular-express-postgres`; si la skill de stack del proyecto define otras (por ejemplo `stack-fastapi-postgres` usa `/health`), mandan las del stack.
8. **Alertas accionables**: alerta sobre síntomas que afectan al usuario (tasa de error, latencia p95, cola atascada), no sobre causas sueltas (CPU al 80 %). Cada alerta tiene umbral, duración y un runbook corto: qué significa, cómo confirmarlo y qué hacer. Ver [alerts-runbook.md](references/alerts-runbook.md).

## Checklist antes de `task.sh handoff`
- [ ] Señales de "funciona" y "falla" de la funcionalidad definidas en la tarea.
- [ ] Logs JSON con `request_id` en todos los eventos de la petición; ningún dato sensible (verificado con un test o una búsqueda en la salida).
- [ ] Métricas RED y de negocio emitidas con etiquetas de baja cardinalidad.
- [ ] Excepciones no controladas llegan al servicio de errores con release, entorno y `request_id`.
- [ ] `/healthz` y `/readyz` responden y `/readyz` falla si cae la base de datos.
- [ ] Cada alerta nueva tiene umbral, duración y runbook.

## Prohibido
- Registrar contraseñas, tokens, cabeceras `Authorization` o `Cookie`, números de tarjeta, documentos de identidad o el cuerpo completo de peticiones con datos personales.
- Usar como etiqueta de métrica valores de alta cardinalidad (IDs, correos, URLs completas con parámetros).
- `console.log` o `print` sueltos como sistema de logs en producción.
- Alertas sin runbook o que saltan a diario sin requerir acción.
- Devolver trazas internas al cliente para "facilitar la depuración".
