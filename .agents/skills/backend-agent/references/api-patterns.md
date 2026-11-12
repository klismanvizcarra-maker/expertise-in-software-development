# Patrones de API, Contratos y Resiliencia Backend

Guía operativa complementaria a `backend-agent` (los nombres concretos de archivos, DI y ORM los manda la skill `stack-*` del proyecto).

## 1. Contrato de Respuesta y Errores (`api_response_template.ts`)

| Escenario | HTTP | Forma del payload | Código de ejemplo |
| :--- | :---: | :--- | :--- |
| **Éxito puntual** | `200`/`201` | `{ success: true, data, meta: { timestamp } }` | — |
| **Listado paginado** | `200` | `{ success: true, data: [...], meta: { page, limit, total, hasNext } }` o `{ nextCursor, limit }` | — |
| **Validación entrada** | `400`/`422` | `{ success: false, error: { code, message, details? } }` | `ERR_VALIDATION_FAILED` |
| **No autenticado** | `401` | `{ success: false, error: { code, message } }` | `ERR_UNAUTHORIZED` |
| **Sin permisos** | `403` | `{ success: false, error: { code, message } }` | `ERR_FORBIDDEN` |
| **No existe o IDOR ajeno** | `404` | `{ success: false, error: { code, message } }` | `ERR_RESOURCE_NOT_FOUND` |
| **Conflicto / Idempotencia** | `409`/`422` | `{ success: false, error: { code, message } }` | `ERR_CONFLICT` / `ERR_IDEMPOTENCY_MISMATCH` |
| **Rate limit** | `429` | Cabecera `Retry-After: <segundos>` + error estable | `ERR_RATE_LIMITED` |

> **Regla IDOR**: cuando un usuario autenticado consulta o modifica un recurso por ID cuyo propietario es otro tenant/usuario, responde `404` (no `403`) para no filtrar existencia de IDs ajenos (`security-hardening`). En FastAPI, adapta el mapeo usando manejadores globales de `HTTPException` / excepciones de dominio con código máquina estable (`detail={"code": "...", "message": "..."}`).

## 2. Idempotencia en Mutaciones Críticas (`Idempotency-Key`)

1. Exige cabecera `Idempotency-Key` (UUID v4 recomendado) en `POST /api/v1/orders`, pagos, reembolsos o transferencias.
2. Calcula un hash SHA-256 canónico del payload (`method + path + userId + bodyHash`) y guárdalo junto a la clave antes de ejecutar el efecto:
   - Clave nueva → ejecuta la operación dentro de transacción, guarda `{ statusCode, body }` con expiración (p. ej. 24 h) y responde.
   - Clave existente + **mismo hash** → devuelve exactamente la respuesta HTTP y cuerpo guardados sin re-ejecutar.
   - Clave existente + **distinto hash** → responde `422` (`ERR_IDEMPOTENCY_MISMATCH`) evitando reutilización errónea de clave.
   - Clave existente + **en curso** → responde `409 Conflict` (`ERR_REQUEST_IN_PROGRESS`) para peticiones concurrentes simultáneas.

## 3. Paginación, Rate Limiting y Salud

- **Paginación**: ningún listado devuelve colecciones completas sin `limit` (`default=20`, `max=100`). En tablas grandes ordenadas cronológicamente prefiere *keyset/cursor pagination* compuesto `(created_at, id) < (:cursor_ts, :cursor_id)` sobre `OFFSET` alto.
- **Rate limiting en auth**: limita `/auth/login`, `/auth/register` y `/auth/reset-password` por IP y por identificador normalizado, devolviendo `429` con `Retry-After`.
- **Sondas operativas**:
  - `GET /healthz`: responde `200` sin consultar BD (proceso vivo).
  - `GET /readyz`: comprueba conectividad real (`SELECT 1`) y dependencias críticas con timeout corto (< 2 s); responde `503` si falla. (Si la skill de stack usa `/health`, como `stack-fastapi-postgres`, manda el stack).

## 4. Checklist de Contrato antes de Implementar
- [ ] Endpoint publicado en `GLOBAL_STATE.md` §4 con método, ruta, request, response, errores y permisos.
- [ ] Controlador/router delgado; reglas puras delegadas en `domain/` y persistencia en servicio/repositorio.
- [ ] Excepciones de librerías externas (ORM, Stripe, parsers) capturadas y mapeadas a errores HTTP controlados sin fugar trazas SQL.
- [ ] Tests de integración cubren `200/201`, `400/422`, `401`, `403/404` (IDOR) y reintento idempotente.

