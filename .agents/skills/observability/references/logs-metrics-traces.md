# Logs, Métricas y Trazas

## Logs

### Formato
Una línea JSON por evento:

```json
{"timestamp":"2026-11-11T10:22:31.412Z","level":"info","service":"api","request_id":"7f3c9a","message":"order.created","order_id":"o_123","user_id":"u_42","duration_ms":38}
```

- `message` es un nombre de evento estable (`order.created`, `payment.failed`), no una frase que cambie: así se puede contar y buscar.
- Librerías habituales: **pino** (Node/Express), **structlog** o `logging` con formateador JSON (Python). En desarrollo se puede formatear bonito; en producción, JSON.

### Niveles
| Nivel | Cuándo |
| :--- | :--- |
| `error` | Algo falló y alguien debe actuar (excepción no controlada, dependencia caída) |
| `warn` | Situación anómala que el sistema absorbió (reintento, valor por defecto) |
| `info` | Eventos de negocio y del ciclo de vida (arranque, pedido creado) |
| `debug` | Detalle de diagnóstico; desactivado en producción por defecto |

### Datos sensibles
- Lista de redacción en el logger: `password`, `token`, `authorization`, `cookie`, `secret`, `card`, `cvv`, documentos de identidad. En pino, `redact` usa **rutas** (`req.headers.authorization`, `*.password`), no nombres de clave a cualquier profundidad: declara cada ruta donde puedan aparecer.
- Nunca el cuerpo completo de la petición; registra los campos que necesitas.
- Comprobación: un test que hace login y busca la contraseña en la salida del log, que debe dar cero coincidencias.

## Correlación
- Middleware al inicio de la cadena: genera un `request_id` propio; acepta el `X-Request-Id` entrante solo de servicios internos de confianza y, si viene de clientes públicos, valídalo (longitud y caracteres) o descártalo.
- `traceparent` (W3C Trace Context) no es un ID de petición: lleva el `trace_id` de la traza distribuida. Regístralo además del `request_id` para saltar del log a la traza.
- Guárdalo en el contexto de la petición (AsyncLocalStorage en Node, `contextvars` en Python) para que todos los logs lo lleven sin pasarlo a mano.
- Devuélvelo en la cabecera de respuesta y en el cuerpo de los errores (`{"error":{"code":"INTERNAL","message":"Error interno","request_id":"7f3c9a"}}`): el usuario lo reporta y se encuentra el log exacto.

## Métricas

### RED por endpoint
| Métrica | Tipo | Etiquetas |
| :--- | :--- | :--- |
| `http_requests_total` | contador | `method`, `route` (plantilla), `status` |
| `http_request_duration_seconds` | histograma | `method`, `route` |

La tasa de error es `status >= 500` sobre el total. Usa histogramas (no medias) para poder calcular p95 y p99.

### Negocio
Contadores de lo que importa: `orders_created_total`, `payments_failed_total{reason}`, `signups_total`. Una caída a cero suele detectar fallos antes que la tasa de error.

### Cardinalidad
Cada combinación de etiquetas es una serie. `route="/orders/:id"` está bien; `route="/orders/8812"` o `user_id` crean millones de series y tumban el sistema de métricas.

## Trazas (OpenTelemetry)
- SDK de OpenTelemetry con instrumentación automática de HTTP, base de datos y colas; exportación por OTLP al backend elegido (Jaeger, Tempo, Honeycomb, Datadog...).
- Propaga `traceparent` en las llamadas salientes y en los mensajes de cola.
- Muestreo: 100 % en desarrollo. En producción, `ParentBased` sobre `TraceIdRatioBased` (p. ej. 10 %) para respetar la decisión del servicio que inicia la traza. Conservar además todas las trazas con error exige muestreo por cola (*tail sampling*) en el OpenTelemetry Collector.
- Incluye el `trace_id` en los logs para saltar del log a la traza.

## Health y readiness
| Endpoint | Comprueba | Uso |
| :--- | :--- | :--- |
| `GET /healthz` | El proceso responde (sin dependencias) | Reinicio del contenedor (liveness) |
| `GET /readyz` | Base de datos y dependencias críticas con timeout corto | Enviar tráfico (readiness) y balanceador |

Responden `200` o `503` con un cuerpo mínimo (`{"status":"ok"}`), sin versiones de dependencias ni cadenas de conexión. Cuidado: si `/readyz` depende de un recurso compartido (la base de datos), su caída saca **todas** las réplicas a la vez; incluye solo dependencias sin las que la réplica no puede atender nada.
