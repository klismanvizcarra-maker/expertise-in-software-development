---
name: stack-fastapi-postgres
description: Convenciones del stack backend Python 3.12 + FastAPI + Pydantic v2 + SQLAlchemy 2 (async) + Alembic + PostgreSQL, probado con pytest y ruff. Define estructura, comandos, inyección de dependencias, migraciones y trampas conocidas. Usar siempre que se cree, modifique, pruebe o despliegue una API en Python con FastAPI. No usar para proyectos con stack-angular-express-postgres ni stack-nextjs-tailwind-prisma.
---

# Stack: FastAPI + SQLAlchemy 2 + Alembic + PostgreSQL

Esta skill define el **cómo técnico concreto** de una API en Python; las skills de rol (`backend-agent`, `database-architect-agent`, etc.) rigen el proceso. Si una convención de este stack difiere de una regla genérica, prevalece esta especificación. Toda excepción se registra como ADR en `GLOBAL_STATE.md` §6. El stack cubre la **API y la base de datos**: el frontend es independiente y consume el contrato OpenAPI que FastAPI publica.

---

## 1. Versiones de Referencia (contrastadas con PyPI el 2026-11-10; no verificadas con un scaffold ejecutado)

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| **Python** | 3.12+ | Tipado moderno (`X \| None`, `type` aliases) |
| **FastAPI** | 0.162.x | Con `uvicorn` como servidor ASGI (0.54.x) |
| **Pydantic** | 2.14.x | Validación de entrada/salida; `model_config` en lugar de `class Config` |
| **SQLAlchemy** | 2.1.x | Estilo 2.0 (`select()`, `Mapped[]`, `AsyncSession`); prohibido el estilo `Query` heredado |
| **Alembic** | 1.20.x | Migraciones versionadas |
| **Driver PostgreSQL** | `psycopg` 3.3.x (async) | URL `postgresql+psycopg://` |
| **PostgreSQL** | 16+ | IDs `uuid`; fechas en `timestamptz` |
| **Testing** | pytest 9 + `httpx` 0.28 | `httpx.AsyncClient` con `ASGITransport`; E2E con Playwright si hay UI |
| **Calidad** | ruff 0.17 + mypy | Lint, formato y tipos |

Antes de fijar versiones en un proyecto real, contrástalas de nuevo (`pip index versions <paquete>`) y anótalas con fecha.

---

## 2. Estructura Canónica del Proyecto

```text
<proyecto>/
├── pyproject.toml                # Dependencias, ruff y mypy
├── alembic.ini
├── alembic/
│   ├── env.py                    # Lee DATABASE_URL del entorno
│   └── versions/                 # Migraciones versionadas
├── app/
│   ├── main.py                   # Crea la app, registra routers y manejadores de error
│   ├── api/                      # Routers por recurso (solo transporte HTTP)
│   │   └── deps.py               # Dependencias: sesión de BD, usuario actual
│   ├── core/                     # config.py (pydantic-settings), security.py
│   ├── db/                       # session.py (engine y sessionmaker), base.py
│   ├── models/                   # Modelos SQLAlchemy
│   ├── schemas/                  # Esquemas Pydantic (contratos de entrada y salida)
│   ├── services/                 # Casos de uso: lógica y consultas
│   └── domain/                   # Reglas de negocio puras, sin FastAPI ni BD
├── tests/                        # pytest (unitarias, integración)
├── docker-compose.yml            # PostgreSQL local
├── Dockerfile                    # Multi-etapa, usuario no root
└── .env.example                  # Variables documentadas
```

---

## 3. Reglas de Oro del Stack

1. **Routers delgados**: un endpoint valida, delega en un servicio y devuelve; no contiene consultas ni reglas de negocio.
2. **Esquemas separados de modelos**: nunca se devuelve un modelo SQLAlchemy directamente. Cada endpoint declara `response_model` con un esquema Pydantic que excluye campos internos (hashes de contraseña, etc.).
3. **Sesión por petición con dependencia**: la `AsyncSession` se inyecta con `Depends(get_session)` y se cierra al terminar la petición. Prohibido un `session` global.
4. **Todo async o todo sync, sin mezclar**: los endpoints `async def` no llaman a código bloqueante (`requests`, `time.sleep`, drivers síncronos). Si hace falta, usa `run_in_threadpool` o un endpoint `def`.
5. **Migraciones solo con Alembic**: cada cambio de esquema es una revisión (`alembic revision --autogenerate`) revisada a mano. Prohibido `Base.metadata.create_all()` fuera de los tests.
6. **Configuración desde el entorno**: `pydantic-settings` lee `.env`; ningún secreto en el código. `.env.example` documenta cada variable.
7. **Errores controlados**: `HTTPException` con códigos y mensajes genéricos; un manejador global evita exponer trazas o detalles del motor de base de datos.
8. **Autorización por objeto**: toda consulta de un recurso del usuario filtra por su propietario (previene IDOR); no basta con comprobar que está autenticado.

---

## 4. Comandos Canónicos

| Acción | Comando |
| :--- | :--- |
| **Entorno virtual** | `python3 -m venv .venv && source .venv/bin/activate` |
| **Instalar dependencias** | `pip install -e ".[dev]"` |
| **Base de datos local** | `docker compose up -d` |
| **Servidor de desarrollo** | `uvicorn app.main:app --reload` |
| **Generar migración** | `alembic revision --autogenerate -m "<descripcion>"` |
| **Aplicar migraciones** | `alembic upgrade head` |
| **Revertir una migración** | `alembic downgrade -1` |
| **Lint y formato** | `ruff check . && ruff format --check .` |
| **Tipos** | `mypy app` |
| **Tests** | `pytest` |
| **Contrato OpenAPI** | `http://localhost:8000/openapi.json` (y `/docs`) |

---

## 5. Referencias por Capa (leer la correspondiente)

- **FastAPI, esquemas, dependencias y errores**: [fastapi-api.md](references/fastapi-api.md)
- **SQLAlchemy 2, Alembic y PostgreSQL**: [sqlalchemy-alembic.md](references/sqlalchemy-alembic.md)

---

## 6. Trampas Conocidas (*Gotchas*)

- **`MissingGreenlet` en SQLAlchemy async**: acceder a una relación no cargada (lazy load) dentro de una sesión async lanza este error. Carga la relación en la consulta con `selectinload()` o `joinedload()`.
- **`expire_on_commit`**: con `AsyncSession`, tras `commit()` los atributos caducan y releerlos dispara una consulta. Crea el `async_sessionmaker` con `expire_on_commit=False`.
- **Autogenerate no ve todo**: Alembic no detecta cambios de nombre de columna (los trata como borrar y crear) ni algunos cambios de tipo o constraints. Revisa y ajusta cada migración antes de aplicarla.
- **Modelos no importados**: si un modelo no se importa en `alembic/env.py` (vía `base.py`), el autogenerate no lo ve y genera una migración vacía o borra la tabla.
- **Esquemas Pydantic y ORM**: para leer desde un objeto ORM usa `model_config = ConfigDict(from_attributes=True)`.
- **Un `def` bloquea el bucle si es `async def`**: una llamada síncrona lenta dentro de `async def` congela todas las peticiones del worker.
- **Pool de conexiones**: con varios workers cada proceso tiene su propio pool; dimensiona `pool_size` y `max_overflow` para no superar `max_connections` de PostgreSQL.

---

## 7. Checklist antes de `task.sh handoff`
- [ ] Routers sin consultas ni reglas de negocio; la lógica vive en `services/` o `domain/`.
- [ ] Cada endpoint declara `response_model` y no expone campos internos.
- [ ] Migración Alembic generada, revisada a mano y con `downgrade` funcional.
- [ ] Consultas de recursos del usuario filtradas por propietario (sin IDOR).
- [ ] Sin código bloqueante dentro de endpoints `async def`.
- [ ] `ruff check .`, `mypy app` y `pytest` pasan con 0 errores.
- [ ] `.env.example` actualizado y sin secretos en el repositorio.
- [ ] Escaneo de secretos limpio con `./.agents/scripts/scan-secrets.sh --branch`.

## 8. Prohibido
- Devolver modelos SQLAlchemy sin esquema de salida, o exponer hashes y campos internos.
- Usar `Base.metadata.create_all()` para evolucionar el esquema fuera de los tests.
- Llamar a código bloqueante dentro de un endpoint `async def`.
- Construir SQL concatenando texto con datos del usuario; usa parámetros enlazados.
- Mostrar trazas internas o mensajes del motor de base de datos en las respuestas de error.
- Guardar secretos o cadenas de conexión reales en el repositorio.
