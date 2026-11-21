---
name: resilience-engineering
description: Tolerancia a fallos en red, APIs de terceros y persistencia - circuit breakers, timeouts, reintentos con backoff y jitter, fallbacks y bulkheads. Usar al consumir APIs externas o diseñar alta disponibilidad. No usar para colas (async-jobs) ni métricas y alertas (observability).
---

# resilience-engineering — Ingeniería de Resiliencia y Tolerancia a Fallos

La skill técnica `resilience-engineering` protege el sistema contra el colapso en cascada cuando servicios externos, bases de datos o APIs dependientes sufren lentitud, timeouts o caídas transitorias.

Para ejemplos de implementación en Node.js y Python consulta [resilience-patterns.md](references/resilience-patterns.md).

---

## Protocolo

1. **Timeouts Obligatorios en Toda Entrada/Salida**:
   - Toda llamada HTTP externa, consulta a base de datos o llamada a servicio remoto debe tener un timeout explícito (máximo 3s a 5s en peticiones síncronas HTTP).
   - En Node.js usa siempre `AbortSignal.timeout(ms)` o `AbortController`; en Python pasa `timeout=X` a clientes `httpx` o `aiohttp`.

2. **Circuit Breaker en Servicios Externos Críticos**:
   - Envuelve integraciones con pasarelas de pago, APIs de terceros y microservicios en un Circuit Breaker.
   - Configura umbrales: 50% de fallos en 10s abre el circuito; enfriamiento de 10s antes de probar Half-Open.
   - Si el circuito está abierto, rechaza de inmediato (*Fail-Fast*) para evitar agotar el pool de conexiones del servidor.

3. **Reintentos con Backoff Exponencial y Jitter**:
   - Reintenta únicamente ante errores transitorios (red caída, HTTP 502/503/504, 429).
   - Prohibido reintentar errores deterministas de cliente (HTTP 400, 401, 403, 404, 422).
   - Aplica **Full Jitter**: aleatoriza el tiempo entre 0 y el límite exponencial para evitar el efecto de manada (*Thundering Herd*).

4. **Degradación Graciosa (Fallbacks)**:
   - Define qué valor seguro retornar si el servicio remoto falla por completo:
     - Lectura: Datos cacheados (*stale-while-revalidate*) o valor vacío/por defecto.
     - Escritura: Encolado asíncrono o mensaje claro al usuario ("Operación encolada; te avisaremos al completar").

5. **Aislamiento de Recursos (Bulkhead)**:
   - Separa los pools de conexiones y hilos para llamadas externas respecto al pool de atención HTTP principal.

---

## Checklist

- [ ] Todas las llamadas remotas tienen timeout estricto documentado y probado.
- [ ] Circuit Breaker configurado para dependencias de red propensas a caídas.
- [ ] Reintentos configurados con backoff exponencial y full jitter; errores 4xx excluidos.
- [ ] Fallback degradado implementado para servicios secundarios sin lanzar 500 al usuario.
- [ ] Test unitario o de integración que simula timeout y verifica la activación del fallback.

---

## Prohibido

- Prohibido realizar llamadas HTTP o consultas a base de datos sin un timeout configurado.
- Prohibido reintentar peticiones en bucle sin límite de intentos (máximo 3 a 5 reintentos).
- Prohibido reintentar peticiones no idempotentes (ej. cobros con tarjeta) sin un `Idempotency-Key` en cabecera.
- Prohibido silenciar excepciones de red sin registrar log estructurado de advertencia.
