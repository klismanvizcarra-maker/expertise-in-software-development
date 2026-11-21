---
name: stack-fastapi-mongodb
description: Stack de API Python con FastAPI sobre MongoDB usando Motor y Beanie - lifespan, documentos, índices y pytest-asyncio. Usar cuando el proyecto sea una API Python con MongoDB. No usar con SQL (stack-fastapi-postgres).
---

# Stack: FastAPI + MongoDB (Motor / Beanie) + Pydantic v2

Esta skill define el **cómo técnico concreto** de una API en Python basada en documentos NoSQL con MongoDB; las skills de rol (`backend-agent`, `database-architect-agent`, etc.) rigen el proceso. Si una convención de este stack difiere de una regla genérica, prevalece esta especificación. Toda excepción se registra como ADR en `GLOBAL_STATE.md` §6.

---

## 1. Versiones de Referencia

| Pieza | Versión | Notas |
| :--- | :--- | :--- |
| **Python** | 3.12+ | Tipado estricto con `X | None`, generic aliases y `typing.Annotated` |
| **FastAPI** | 0.162.x | Con `uvicorn` como servidor ASGI (0.54.x) |
| **Pydantic** | 2.14.x | Serialización y validación con `model_config = ConfigDict(...)` |
| **MongoDB** | 7.0+ | Almacén de documentos NoSQL (WiredTiger engine) |
| **Driver MongoDB** | `motor` 3.6.x | Driver asíncrono oficial sobre `PyMongo` |
| **ODM / Document Mapping** | `beanie` 1.29.x | Modelos asíncronos derivados de `Pydantic Document` |
| **Testing** | pytest 9 + `pytest-asyncio` 0.25 + `httpx` 0.28 | Pruebas de integración con base de datos de test efímera o testcontainers |
| **Calidad** | ruff 0.17 + mypy | Linter, formateador y comprobación de tipos |

---

## 2. Estructura Canónica del Proyecto

```text
<proyecto>/
├── pyproject.toml                # Dependencias, configuración de ruff, mypy y pytest
├── app/
│   ├── main.py                   # App FastAPI con lifespan context para conexión a MongoDB
│   ├── api/                      # Routers HTTP (v1/endpoints/...)
│   │   └── deps.py               # Inyección de dependencias (auth, contexto de sesión)
│   ├── core/                     # config.py (pydantic-settings), security.py (JWT/passwords)
│   ├── db/                       # client.py (MotorClient), init_db.py (init_beanie con lista de modelos)
│   ├── models/                   # Documentos Beanie (subclases de beanie.Document con Settings de índices)
│   ├── schemas/                  # DTOs Pydantic de entrada y salida (evita exponer _id crudo)
│   ├── services/                 # Casos de uso y operaciones de negocio sobre los documentos
│   └── domain/                   # Funciones puras de cálculo y máquinas de estado
├── tests/                        # Suites de pytest (unitarias, integración de endpoints)
├── docker-compose.yml            # MongoDB local con usuario y base de datos preconfigurados
└── .env.example                  # MONGODB_URL=mongodb://user:pass@localhost:27017/dbname
```

---

## 3. Comandos Habituales

```bash
# Desarrollo local
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Calidad y Formato
ruff check app tests
ruff format app tests --check
mypy app

# Ejecución de Pruebas
pytest -v
pytest --cov=app tests/
```

---

## 4. Reglas y Convenciones Clave

1. **Gestión de Conexión con `lifespan`**:
   - Inicializa el cliente `AsyncIOMotorClient` y `init_beanie(database, document_models=[...])` en el contexto `lifespan` de FastAPI en `app/main.py`.
   - Cierra formalmente la conexión al recibir la señal de terminación (`client.close()`).

2. **Modelado y Claves de Documentos**:
   - Hereda modelos principales de `beanie.Document`.
   - Para exponer el identificador en schemas Pydantic, transforma `_id` (de tipo `ObjectId` o `PydanticObjectId`) a string `id` usando serializadores de campo (`@field_validator` o alias).
   - Registra índices únicos y compuestos dentro de la clase interna `class Settings`:
     ```python
     class Settings:
         name = "users"
         indexes = [
             "email",
             [("tenant_id", 1), ("created_at", -1)],
         ]
     ```

3. **Inmutabilidad y Actualizaciones Parciales**:
   - Usa operadores atómicos de MongoDB (`$set`, `$inc`, `$push`) mediante métodos de Beanie (`doc.set(...)`, `doc.inc(...)`) en lugar de sobrescribir el documento completo para prevenir condiciones de carrera concurrentes.

---

## 5. Trampas Conocidas (Quirks)

| Quirk / Trampa | Comportamiento Inesperado | Solución Obligatoria |
| :--- | :--- | :--- |
| **Serialización de ObjectId** | FastAPI/JSON lanza `TypeError: ObjectId is not JSON serializable` | En DTOs de salida usa `PydanticObjectId` o convierte a `str(doc.id)` antes de responder |
| **Zona Horaria en BSON datetime** | MongoDB persiste fechas en UTC truncadas a milisegundos (pierde microsegundos) | Usar siempre `datetime.now(timezone.utc)` y comparar con tolerancia de milisegundos en tests |
| **Transacciones multi-documento** | `client.start_session()` falla si MongoDB corre como nodo standalone sin replica set | Para desarrollo local, configurar Docker Compose con replica set (`--replSet rs0`) si se requieren transacciones ACID |
| **Falta de creación de índices** | Consultas lentas si Beanie no crea índices al inicio | Asegurar que `init_beanie` se ejecute en el startup del lifespan antes de admitir tráfico HTTP |
