# Estrategia de Pruebas: Unitarias, Integración y Contratos

Guía práctica de implementación compatible con Vitest/Supertest (`stack-angular-express-postgres`, `stack-nextjs-tailwind-prisma`) y `pytest`/`httpx` (`stack-fastapi-postgres`).

## 1. Matriz de selección de dobles de prueba

| Dependencia | Estrategia recomendada | Evitar |
| :--- | :--- | :--- |
| **Lógica pura de dominio (`domain/`)** | Código real sin dobles | Mockear helpers internos o modelos |
| **Base de datos (PostgreSQL/Drizzle/Prisma/SQLAlchemy)** | BD de pruebas efímera + migraciones + rollback o `TRUNCATE` por test | Mockear el cliente ORM (`prisma.$queryRaw.mockResolvedValue`) para lógica SQL |
| **HTTP de terceros (Stripe, OAuth, APIs)** | Mock de capa HTTP (`nock`, `msw/node`, `respx`) o adapter/fake tipado en frontera | Llamar a internet desde tests locales o CI |
| **Reloj / UUID / RNG** | Inyectar dependencia `clock: () => Date` / `freezegun` / `vi.useFakeTimers()` | Depender de `Date.now()` o `datetime.now()` reales en expiraciones/prorrateos |
| **Colas / Emails (`async-jobs`)** | In-memory outbox / transport fake que captura jobs/mensajes para aserción | Enviar correos SMTP reales o dormir esperando workers en background |

## 2. Aislamiento de base de datos por stack

### Node / TypeScript (`Vitest`)
- Ejecuta migraciones una vez al iniciar la suite de integración (`globalSetup`).
- Entre tests: limpia tablas modificadas en `beforeEach` (`TRUNCATE ... RESTART IDENTITY CASCADE`) o corre cada archivo contra un esquema dedicado por worker.
- Para lógica temporal usa `vi.useFakeTimers()` + `vi.setSystemTime(new Date('2026-01-15T12:00:00Z'))` y restaura en `afterEach(() => vi.useRealTimers())`.

### Python / FastAPI (`pytest` + `httpx.AsyncClient` + SQLAlchemy 2 async)
- Crea una sesión por test envuelta en transacción externa (`connection.begin()`) y revierte al finalizar (`await trans.rollback()`), o usa `TRUNCATE` entre casos cuando los endpoints hacen `commit()` reales con varios hilos/tareas.
- Sobrescribe únicamente la dependencia de sesión (`app.dependency_overrides[get_session] = override_get_session`) y la limpias tras cada test (`app.dependency_overrides.clear()`).

## 3. Contratos y *factories* sin acoplamiento

- **Factories deterministas**: define constructores mínimos (`make_user(email="a@example.com", **overrides)`) que solo reciben lo relevante para el test en curso; evita *fixtures* gigantes compartidas de 50 líneas donde nadie sabe qué campo rompe otro test.
- **Validación de contrato API**:
  - En Express/Next.js + Zod: valida las respuestas de integración reales con el mismo schema Zod de salida de `packages/shared` / `lib/schemas` que consume el frontend.
  - En FastAPI: verifica que los tests de integración aserten estado + payload serializado contra el `response_model` real y revisa `/openapi.json` en CI sin cambios retro-incompatibles accidentales.
- **Anti-flakiness en CI**: corre periódicamente con orden aleatorio (`pytest-randomly` o `--sequence.shuffle` en Vitest) y desactiva reintentos en unitarias e integración (`retries: 0`); si falla al barajar, hay estado global filtrado.
