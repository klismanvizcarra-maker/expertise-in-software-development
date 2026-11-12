# Rendimiento — FastAPI + SQLAlchemy 2 (async) + PostgreSQL

Receta de referencia para `stack-fastapi-postgres`. En una API Python el cuello de botella suele estar en el **event loop bloqueado**, **consultas N+1 síncronas/lazy** o **payloads sin paginar ni comprimir**.

## 1. Medición base (antes de tocar código)

- Mide latencia p50/p95/p99 de endpoints y queries SQL antes y después (p. ej. tiempo de respuesta registrado por middleware estructurado + `EXPLAIN (ANALYZE, BUFFERS)` en PostgreSQL o carga sintética local con `wrk`/`hey`/`locust`).

## 2. Event Loop y Concurrencia (`asyncio`)

- **Nunca bloquees el loop**: usa drivers asíncronos (`psycopg` async / `asyncpg` + `AsyncSession`) en rutas `async def`.
- Para tareas CPU-bound (PDFs, hashing, parsing pesado) o librerías síncronas sin equivalente async, delega a `await asyncio.to_thread(...)` (o rutas `def` síncronas si toda la ruta es blocking) o a una cola de trabajos en segundo plano.

## 3. SQLAlchemy 2, Conexiones y Consultas

- **Prohibido lazy loading implícito en async**: configura `expire_on_commit=False` y usa `selectinload(...)` / `joinedload(...)` explícitos cuando necesites relaciones; selecciona en SQLAlchemy solo las columnas necesarias (`select(Model.id, Model.name)`) antes de serializar con el esquema Pydantic.
- **Pool de conexiones**: dimensiona `pool_size` y `max_overflow` según workers de Uvicorn/Gunicorn y el límite de PostgreSQL (`pool_pre_ping=True`).
- **Paginación obligatoria**: keyset/cursor pagination compuesta con desempate estable (`WHERE (created_at, id) < (:cursor_ts, :cursor_id) ORDER BY created_at DESC, id DESC LIMIT :limit`) mejor que `OFFSET` alto; exige un límite máximo en el esquema Pydantic (`limit: int = Field(default=20, le=100)`).
- **Índices reales**: comprueba con `EXPLAIN (ANALYZE, BUFFERS)` que no haya `Seq Scan` en tablas crecientes ni sort sin índice.

## 4. Red, Caché y Payloads

- **Compresión**: `GZipMiddleware(minimum_size=1000)` en FastAPI o Brotli/Gzip en proxy inverso (Nginx/Caddy).
- **Respuestas rápidas y `Cache-Control`**: devuelve `ETag` o `Cache-Control: public, max-age=...` en catálogos públicos y `no-store` en datos privados; apoya contadores o catálogos muy consultados en caché corta con invalidación explícita.
