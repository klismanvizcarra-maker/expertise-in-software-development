# Patrones Canónicos de Resiliencia (Node.js y Python)

Guía de implementación para tolerancia a fallos en llamadas de red, APIs externas y bases de datos.

---

## 1. Timeout Estricto con AbortSignal (Node.js)

```typescript
export async function fetchWithTimeout(url: string, options: RequestInit = {}, timeoutMs = 5000): Promise<Response> {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    return response;
  } catch (error: any) {
    if (error.name === 'AbortError') {
      throw new Error(`Timeout de red tras ${timeoutMs}ms llamando a ${url}`);
    }
    throw error;
  } finally {
    clearTimeout(id);
  }
}
```

---

## 2. Circuit Breaker con Opossum (Node.js)

```typescript
import CircuitBreaker from 'opossum';

const options = {
  timeout: 3000,              // Si la acción toma más de 3s, dispara fallo
  errorThresholdPercentage: 50, // Abre el circuito si el 50% de llamadas fallan
  resetTimeout: 10000          // Espera 10s antes de intentar Half-Open
};

export function createProtectedService<T>(action: (...args: any[]) => Promise<T>, fallbackData: T) {
  const breaker = new CircuitBreaker(action, options);
  breaker.fallback(() => fallbackData);
  return breaker;
}
```

---

## 3. Reintentos con Backoff Exponencial y Full Jitter (Python)

```python
import asyncio
import random

async def retry_with_jitter(coro_fn, max_retries=3, base_delay=0.5, max_delay=5.0):
    for attempt in range(max_retries):
        try:
            return await coro_fn()
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            # Full Jitter: Sleep = random(0, min(max_delay, base_delay * 2 ** attempt))
            high = min(max_delay, base_delay * (2 ** attempt))
            sleep_time = random.uniform(0, high)
            await asyncio.sleep(sleep_time)
```

---

## 4. Fallback Degradado Gracioso (Graceful Degradation)

Cuando un servicio secundario (recomendaciones, notificaciones, conversor de moneda) no responde:
1. Retorna datos de caché reciente (*stale-while-revalidate*).
2. Si no hay caché, retorna un valor por defecto seguro (ej. lista vacía o moneda base).
3. Nunca propagues un 500 al usuario por un fallo en un servicio no esencial.
